--!strict
--[[
	Admin-only floating panel for spawning pets and testing procedural animations.
	Built in code; toggled from AdminPanel Pets tab ("Pet Lab").
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local PetAnimator = require(DAC:WaitForChild("PetAnimator"))

local PetDebugWidget = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local BG = Color3.fromRGB(30, 30, 48)
local BG_ACCENT = Color3.fromRGB(65, 50, 140)
local BTN = Color3.fromRGB(55, 45, 110)
local TEXT = Color3.fromRGB(230, 230, 240)

local DISPLAY_ORDER = 1900

local gui: ScreenGui? = nil
local listFrame: ScrollingFrame? = nil

local selectedPetId: string? = nil
local activeModel: Model? = nil
local debugModels: { Model } = {}

local initDone = false
local visible = false

local function getPetTemplatesFolder(): Folder?
	local inRS = ReplicatedStorage:FindFirstChild("PetModels")
	if inRS and inRS:IsA("Folder") then
		return inRS
	end
	local inWS = workspace:FindFirstChild("PetModels")
	if inWS and inWS:IsA("Folder") then
		return inWS
	end
	return nil
end

local function getActivePetsParent(): Instance
	local folder = workspace:FindFirstChild("ActivePets")
	if folder then
		return folder
	end
	return workspace
end

local function clonePet(templateName: string): Model?
	local folder = getPetTemplatesFolder()
	if not folder then
		return nil
	end
	local template = folder:FindFirstChild(templateName)
	if not template or not template:IsA("Model") then
		return nil
	end
	local inst = template:Clone()
	inst.Name = "DebugPet_" .. templateName .. "_" .. tostring(os.clock())
	if not inst.PrimaryPart then
		local p = inst:FindFirstChildWhichIsA("BasePart", true)
		if p and p:IsA("BasePart") then
			inst.PrimaryPart = p
		end
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	inst.Parent = getActivePetsParent()
	return inst
end

local function placeInFrontOfPlayer(model: Model)
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = hrp.CFrame.LookVector
	else
		flat = flat.Unit
	end
	local pos = hrp.Position + flat * 6 + Vector3.new(0, 1, 0)
	local face = pos + flat
	model:PivotTo(CFrame.lookAt(pos, face))
end

local function clearDebugPets()
	for _, m in debugModels do
		if m.Parent then
			PetAnimator.stop(m)
			m:Destroy()
		end
	end
	table.clear(debugModels)
	activeModel = nil
end

local function refreshSelectionHighlight()
	if not listFrame then
		return
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("TextButton") then
			local pid = child:GetAttribute("PetId") :: string?
			if pid and selectedPetId == pid then
				child.BackgroundColor3 = BG_ACCENT
			else
				child.BackgroundColor3 = BTN
			end
		end
	end
end

local function spawnSelected()
	if not selectedPetId then
		return
	end
	local templateName = PetConfig.getPetTemplateName(selectedPetId)
	local model = clonePet(templateName)
	if not model then
		warn("[PetDebugWidget] No model for template:", templateName)
		return
	end
	table.insert(debugModels, model)
	placeInFrontOfPlayer(model)
	local def = PetConfig.Pets[selectedPetId]
	local rarity = if def and def.rarity then def.rarity else "common"
	model:SetAttribute("PetPersonalitySeed", math.floor(os.clock() * 10000) % 100000)
	PetAnimator.start(model, "idle", true, rarity)
	task.defer(function()
		if model.Parent then
			PetAnimator.playEmote(model, "landing")
		end
	end)
	activeModel = model
end

local function playAnim(name: string)
	if not activeModel or not activeModel.Parent then
		warn("[PetDebugWidget] Spawn a pet first.")
		return
	end
	PetAnimator.setAnim(activeModel, name)
end

local function playEmote(emoteId: string)
	if not activeModel or not activeModel.Parent then
		warn("[PetDebugWidget] Spawn a pet first.")
		return
	end
	PetAnimator.playEmote(activeModel, emoteId)
end

local function addCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function wireDrag(titleBar: TextButton, frame: Frame)
	local dragging = false
	local dragStart: Vector3? = nil
	local posStart: UDim2? = nil

	titleBar.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			posStart = frame.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging or not dragStart or not posStart then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				posStart.X.Scale,
				posStart.X.Offset + delta.X,
				posStart.Y.Scale,
				posStart.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			dragStart = nil
			posStart = nil
		end
	end)
end

function PetDebugWidget.init()
	if initDone then
		return
	end
	initDone = true

	local screen = Instance.new("ScreenGui")
	screen.Name = "PetDebugWidget"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.Enabled = false
	screen.DisplayOrder = DISPLAY_ORDER
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Main"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -16, 0, 72)
	root.Size = UDim2.new(0, 260, 0, 512)
	root.BackgroundColor3 = BG
	root.BackgroundTransparency = 0.25
	root.BorderSizePixel = 0
	root.Parent = screen
	addCorner(root, 8)

	local title = Instance.new("TextButton")
	title.Name = "TitleBar"
	title.Size = UDim2.new(1, 0, 0, 34)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = BG_ACCENT
	title.BackgroundTransparency = 0.1
	title.AutoButtonColor = false
	title.Text = "Pet Lab  (drag)"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = TEXT
	title.Parent = root
	addCorner(title, 8)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -30, 0, 3)
	closeBtn.BackgroundColor3 = BTN
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.TextColor3 = TEXT
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = title
	addCorner(closeBtn, 5)

	closeBtn.MouseButton1Click:Connect(function()
		PetDebugWidget.setVisible(false)
	end)

	wireDrag(title, root)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "PetList"
	scroll.Size = UDim2.new(1, -16, 0, 200)
	scroll.Position = UDim2.new(0, 8, 0, 42)
	scroll.BackgroundColor3 = BG
	scroll.BackgroundTransparency = 0.5
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = root
	addCorner(scroll, 6)

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = scroll

	local rows: { { id: string, name: string } } = {}
	for id, def in PetConfig.Pets do
		table.insert(rows, { id = id, name = def.name or id })
	end
	table.sort(rows, function(a, b)
		return a.name < b.name
	end)

	for i, row in ipairs(rows) do
		local btn = Instance.new("TextButton")
		btn.Name = "Pet_" .. row.id
		btn.Size = UDim2.new(1, 0, 0, 26)
		btn.BackgroundColor3 = BTN
		btn.Text = row.name .. "  (" .. row.id .. ")"
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 11
		btn.TextColor3 = TEXT
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = false
		btn.LayoutOrder = i
		btn:SetAttribute("PetId", row.id)
		btn.Parent = scroll

		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, 8)
		p.Parent = btn
		addCorner(btn, 4)

		btn.MouseButton1Click:Connect(function()
			selectedPetId = row.id
			refreshSelectionHighlight()
		end)
	end

	if #rows > 0 then
		selectedPetId = rows[1].id
	end

	listFrame = scroll
	gui = screen

	refreshSelectionHighlight()

	local bpmY = 208
	local bpmLbl = Instance.new("TextLabel")
	bpmLbl.Name = "BpmLabel"
	bpmLbl.Size = UDim2.new(0, 34, 0, 22)
	bpmLbl.Position = UDim2.new(0, 8, 0, bpmY)
	bpmLbl.BackgroundTransparency = 1
	bpmLbl.Font = Enum.Font.GothamBold
	bpmLbl.TextSize = 12
	bpmLbl.TextColor3 = TEXT
	bpmLbl.Text = "BPM"
	bpmLbl.TextXAlignment = Enum.TextXAlignment.Left
	bpmLbl.Parent = root

	local bpmBox = Instance.new("TextBox")
	bpmBox.Name = "BpmInput"
	bpmBox.Size = UDim2.new(0, 48, 0, 26)
	bpmBox.Position = UDim2.new(0, 44, 0, bpmY - 1)
	bpmBox.BackgroundColor3 = BG
	bpmBox.Text = tostring(PetAnimator.getBpm())
	bpmBox.Font = Enum.Font.Gotham
	bpmBox.TextSize = 13
	bpmBox.TextColor3 = TEXT
	bpmBox.ClearTextOnFocus = false
	bpmBox.Parent = root
	addCorner(bpmBox, 4)

	local bpmBtn = Instance.new("TextButton")
	bpmBtn.Name = "BpmApply"
	bpmBtn.Size = UDim2.new(0, 150, 0, 28)
	bpmBtn.Position = UDim2.new(0, 98, 0, bpmY - 2)
	bpmBtn.BackgroundColor3 = BTN
	bpmBtn.Text = "Apply beat grid"
	bpmBtn.Font = Enum.Font.GothamBold
	bpmBtn.TextSize = 11
	bpmBtn.TextColor3 = TEXT
	bpmBtn.AutoButtonColor = false
	bpmBtn.Parent = root
	addCorner(bpmBtn, 5)
	bpmBtn.MouseButton1Click:Connect(function()
		local n = tonumber(bpmBox.Text)
		if n then
			PetAnimator.setBpm(n)
			bpmBox.Text = tostring(PetAnimator.getBpm())
		end
	end)

	local y0 = 278
	local spawnBtn = Instance.new("TextButton")
	spawnBtn.Name = "Spawn"
	spawnBtn.Size = UDim2.new(1, -16, 0, 32)
	spawnBtn.Position = UDim2.new(0, 8, 0, y0)
	spawnBtn.BackgroundColor3 = BG_ACCENT
	spawnBtn.Text = "Spawn in world"
	spawnBtn.Font = Enum.Font.GothamBold
	spawnBtn.TextSize = 13
	spawnBtn.TextColor3 = TEXT
	spawnBtn.AutoButtonColor = false
	spawnBtn.Parent = root
	addCorner(spawnBtn, 6)
	spawnBtn.MouseButton1Click:Connect(spawnSelected)

	local animNames = { "idle", "walk", "hop", "float", "sit", "griddy" }
	local colW = (260 - 16 - 8) / 3
	for idx, an in ipairs(animNames) do
		local col = (idx - 1) % 3
		local rowN = math.floor((idx - 1) / 3)
		local ab = Instance.new("TextButton")
		ab.Name = "Anim_" .. an
		ab.Size = UDim2.new(0, colW, 0, 28)
		ab.Position = UDim2.new(0, 8 + col * (colW + 4), 0, y0 + 40 + rowN * 32)
		ab.BackgroundColor3 = BTN
		ab.Text = an
		ab.Font = Enum.Font.GothamBold
		ab.TextSize = 11
		ab.TextColor3 = TEXT
		ab.AutoButtonColor = false
		ab.Parent = root
		addCorner(ab, 4)
		ab.MouseButton1Click:Connect(function()
			playAnim(an)
		end)
	end

	local emoteY = y0 + 40 + 64 + 6
	local emoteW = (260 - 16 - 8) / 3
	local emoteIds = { "stretch", "playbow", "shake" }
	local emoteLabels = { "Stretch", "Bow", "Shake" }
	for ei, emId in ipairs(emoteIds) do
		local col = (ei - 1) % 3
		local eb = Instance.new("TextButton")
		eb.Name = "Emote_" .. emId
		eb.Size = UDim2.new(0, emoteW, 0, 26)
		eb.Position = UDim2.new(0, 8 + col * (emoteW + 4), 0, emoteY)
		eb.BackgroundColor3 = Color3.fromRGB(70, 55, 120)
		eb.Text = emoteLabels[ei]
		eb.Font = Enum.Font.GothamBold
		eb.TextSize = 10
		eb.TextColor3 = TEXT
		eb.AutoButtonColor = false
		eb.Parent = root
		addCorner(eb, 4)
		local captured = emId
		eb.MouseButton1Click:Connect(function()
			playEmote(captured)
		end)
	end

	local clearBtn = Instance.new("TextButton")
	clearBtn.Name = "Clear"
	clearBtn.Size = UDim2.new(1, -16, 0, 30)
	clearBtn.Position = UDim2.new(0, 8, 0, emoteY + 32)
	clearBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 50)
	clearBtn.Text = "Clear debug pets"
	clearBtn.Font = Enum.Font.GothamBold
	clearBtn.TextSize = 12
	clearBtn.TextColor3 = TEXT
	clearBtn.AutoButtonColor = false
	clearBtn.Parent = root
	addCorner(clearBtn, 6)
	clearBtn.MouseButton1Click:Connect(clearDebugPets)
end

function PetDebugWidget.setVisible(on: boolean)
	if not gui then
		return
	end
	visible = on
	gui.Enabled = on
end

function PetDebugWidget.toggle()
	if not gui then
		return
	end
	PetDebugWidget.setVisible(not visible)
end

function PetDebugWidget.isVisible(): boolean
	return visible
end

return PetDebugWidget
