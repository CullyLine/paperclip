--!strict
--[[
	Screen-space dynamic grid for displaying hatched pets (PS99-style).
	Pets enter from a world-to-screen position, settle into a responsive grid,
	then fly toward the player character and disappear after a hold duration.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local PetAnimator = require(DAC:WaitForChild("PetAnimator"))
local Constants = require(DAC:WaitForChild("Constants"))

local RARITY_COLORS: { [string]: Color3 } = Constants.RARITY_COLORS
local RARITY_DISPLAY: { [string]: string } = {
	common = "Common",
	uncommon = "Uncommon",
	rare = "Rare",
	epic = "Epic",
	legendary = "Legendary",
	mythic = "Mythic",
	secret = "Secret",
}

local HatchGridOverlay = {}

local player = Players.LocalPlayer
local gridGui: ScreenGui? = nil
local gridContainer: Frame? = nil

local GRID_HOLD_SEC = 5.0
local ENTER_TWEEN_SEC = 0.4
local EXIT_TWEEN_SEC = 0.6
local REFLOW_TWEEN_SEC = 0.3
local CELL_PADDING_SCALE = 0.02
local GRID_AREA = { x = 0.15, y = 0.10, w = 0.70, h = 0.75 }
local MAX_CELLS = Constants.MAX_HATCH_COUNT

export type GridCell = {
	frame: Frame,
	viewport: ViewportFrame,
	vpCamera: Camera,
	petModel: Model?,
	petId: string,
	petName: string,
	rarity: string,
	power: number,
	index: number,
	enterTime: number,
	exiting: boolean,
	spinConn: RBXScriptConnection?,
}

local activeCells: { GridCell } = {}
local cellIdCounter = 0

local function getPlayerGui(): PlayerGui?
	return player:FindFirstChild("PlayerGui") :: PlayerGui?
end

local function ensureGui(): (ScreenGui, Frame)
	if gridGui and gridGui.Parent and gridContainer then
		return gridGui, gridContainer
	end

	local pg = getPlayerGui()
	if not pg then error("[HatchGrid] No PlayerGui") end

	local existing = pg:FindFirstChild("DACHatchGrid")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DACHatchGrid"
	gui.DisplayOrder = 85
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local container = Instance.new("Frame")
	container.Name = "GridContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(GRID_AREA.w, GRID_AREA.h)
	container.Position = UDim2.fromScale(GRID_AREA.x, GRID_AREA.y)
	container.Parent = gui

	gridGui = gui
	gridContainer = container
	return gui, container
end

local function computeGridLayout(count: number): (number, number)
	if count <= 0 then return 1, 1 end
	if count <= 3 then return count, 1 end
	if count <= 6 then return 3, 2 end
	if count <= 12 then return 4, 3 end
	if count <= 20 then return 5, 4 end
	return 7, math.ceil(count / 7)
end

local function getCellTargetPosition(index: number, totalCount: number, containerSize: Vector2): (UDim2, UDim2)
	local cols, rows = computeGridLayout(totalCount)

	local cellW = (1.0 - CELL_PADDING_SCALE * (cols + 1)) / cols
	local cellH = (1.0 - CELL_PADDING_SCALE * (rows + 1)) / rows
	local cellSize = math.min(cellW, cellH)

	local totalGridW = cols * cellSize + (cols + 1) * CELL_PADDING_SCALE
	local totalGridH = rows * cellSize + (rows + 1) * CELL_PADDING_SCALE
	local offsetX = (1.0 - totalGridW) / 2
	local offsetY = (1.0 - totalGridH) / 2

	local row = math.floor((index - 1) / cols)
	local col = (index - 1) % cols

	local petsInLastRow = totalCount - (rows - 1) * cols
	local lastRowOffset = 0.0
	if row == rows - 1 and petsInLastRow < cols then
		lastRowOffset = (cols - petsInLastRow) * (cellSize + CELL_PADDING_SCALE) / 2
	end

	local posX = offsetX + CELL_PADDING_SCALE + col * (cellSize + CELL_PADDING_SCALE) + lastRowOffset
	local posY = offsetY + CELL_PADDING_SCALE + row * (cellSize + CELL_PADDING_SCALE)

	return UDim2.fromScale(posX, posY), UDim2.fromScale(cellSize, cellSize)
end

local function createCellFrame(petId: string, petName: string, rarity: string, power: number): GridCell
	cellIdCounter += 1

	local frame = Instance.new("Frame")
	frame.Name = "HatchCell_" .. cellIdCounter
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0, 0)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "PetView"
	viewport.Size = UDim2.fromScale(1, 0.75)
	viewport.Position = UDim2.fromScale(0, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(180, 160, 220)
	viewport.LightColor = Color3.fromRGB(255, 245, 255)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.3)
	viewport.Parent = frame

	local vpCam = Instance.new("Camera")
	vpCam.FieldOfView = 40
	vpCam.Parent = viewport
	viewport.CurrentCamera = vpCam

	local petModel: Model? = nil
	local petFolder = ReplicatedStorage:FindFirstChild("PetModels")
	if petFolder then
		local petTplName = PetConfig.getPetTemplateName(petId)
		if petTplName then
			local tpl = petFolder:FindFirstChild(petTplName)
			if tpl and tpl:IsA("Model") then
				petModel = tpl:Clone()
				local pm = petModel :: Model
				if not pm.PrimaryPart then
					local p = pm:FindFirstChildWhichIsA("BasePart", true)
					if p and p:IsA("BasePart") then pm.PrimaryPart = p end
				end
				for _, d in pm:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanQuery = false
					end
				end
				pm:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0))
				pm.Parent = viewport

				local bb = pm:GetExtentsSize()
				local maxDim = math.max(bb.X, bb.Y, bb.Z, 0.1)
				local camDist = maxDim * 2.0
				vpCam.CFrame = CFrame.new(Vector3.new(0, camDist * 0.15, camDist), Vector3.new(0, 0, 0))

				PetAnimator.start(pm, "idle", true)
			end
		end
	end

	local rarityColor = RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PetName"
	nameLabel.Size = UDim2.fromScale(1, 0.14)
	nameLabel.Position = UDim2.fromScale(0, 0.74)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Text = petName
	nameLabel.Parent = frame

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.fromScale(1, 0.12)
	rarityLabel.Position = UDim2.fromScale(0, 0.87)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextStrokeTransparency = 0.4
	rarityLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	rarityLabel.Text = RARITY_DISPLAY[rarity] or rarity
	rarityLabel.Parent = frame

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = frame

	local cell: GridCell = {
		frame = frame,
		viewport = viewport,
		vpCamera = vpCam,
		petModel = petModel,
		petId = petId,
		petName = petName,
		rarity = rarity,
		power = power,
		index = 0,
		enterTime = os.clock(),
		exiting = false,
		spinConn = nil,
	}

	return cell
end

local function reflowGrid()
	local _, container = ensureGui()
	local totalCount = #activeCells

	for i, cell in activeCells do
		if cell.exiting then continue end
		cell.index = i

		local targetPos, targetSize = getCellTargetPosition(i, totalCount, container.AbsoluteSize)

		TweenService:Create(cell.frame, TweenInfo.new(REFLOW_TWEEN_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = targetPos,
			Size = targetSize,
		}):Play()
	end
end

local function getCharacterScreenPosition(): UDim2
	local char = player.Character
	if not char then return UDim2.fromScale(0.5, 1.2) end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return UDim2.fromScale(0.5, 1.2) end
	local camera = workspace.CurrentCamera
	if not camera then return UDim2.fromScale(0.5, 1.2) end
	local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
	if not onScreen then return UDim2.fromScale(0.5, 1.2) end
	local viewportSize = camera.ViewportSize
	return UDim2.fromScale(screenPos.X / viewportSize.X, screenPos.Y / viewportSize.Y)
end

local function exitCell(cell: GridCell)
	if cell.exiting then return end
	cell.exiting = true

	local charPos = getCharacterScreenPosition()
	local uiScale = cell.frame:FindFirstChildOfClass("UIScale")

	TweenService:Create(cell.frame, TweenInfo.new(EXIT_TWEEN_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = charPos,
	}):Play()

	if uiScale then
		TweenService:Create(uiScale, TweenInfo.new(EXIT_TWEEN_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.15,
		}):Play()
	end

	task.delay(EXIT_TWEEN_SEC + 0.05, function()
		if cell.petModel then PetAnimator.stop(cell.petModel :: Model) end
		if cell.spinConn then cell.spinConn:Disconnect(); cell.spinConn = nil end
		if cell.frame.Parent then cell.frame:Destroy() end

		local idx = table.find(activeCells, cell)
		if idx then table.remove(activeCells, idx) end

		if #activeCells > 0 then
			reflowGrid()
		else
			if gridGui and gridGui.Parent then
				gridGui:Destroy()
				gridGui = nil
				gridContainer = nil
			end
		end
	end)
end

local function scheduleExit(cell: GridCell)
	task.delay(GRID_HOLD_SEC, function()
		exitCell(cell)
	end)
end

function HatchGridOverlay.addPet(petId: string, petName: string, rarity: string, power: number, screenEntryX: number, screenEntryY: number)
	local gui, container = ensureGui()

	local cell = createCellFrame(petId, petName, rarity, power)
	table.insert(activeCells, cell)
	cell.index = #activeCells

	local totalCount = #activeCells
	local targetPos, targetSize = getCellTargetPosition(cell.index, totalCount, container.AbsoluteSize)

	cell.frame.Position = UDim2.fromScale(screenEntryX - GRID_AREA.x, screenEntryY - GRID_AREA.y)
	cell.frame.Size = UDim2.fromScale(0.05, 0.05)

	local uiScale = cell.frame:FindFirstChildOfClass("UIScale")
	if uiScale then uiScale.Scale = 0.3 end

	cell.frame.Parent = container

	TweenService:Create(cell.frame, TweenInfo.new(ENTER_TWEEN_SEC, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetPos,
		Size = targetSize,
	}):Play()

	if uiScale then
		TweenService:Create(uiScale, TweenInfo.new(ENTER_TWEEN_SEC, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end

	reflowGrid()
	scheduleExit(cell)
end

function HatchGridOverlay.clear()
	for _, cell in activeCells do
		if cell.petModel then PetAnimator.stop(cell.petModel :: Model) end
		if cell.spinConn then cell.spinConn:Disconnect(); cell.spinConn = nil end
		if cell.frame.Parent then cell.frame:Destroy() end
	end
	table.clear(activeCells)
	if gridGui and gridGui.Parent then
		gridGui:Destroy()
		gridGui = nil
		gridContainer = nil
	end
end

function HatchGridOverlay.init()
	-- Nothing to wire; the module is called directly by EggViewController.
end

return HatchGridOverlay
