local Theme      = require(script.Parent.DesignerTheme)
local Serializer = require(script.Parent.Serializer)

local Toolbar = {}
Toolbar.__index = Toolbar

function Toolbar.new(parent, appState)
	local self = setmetatable({}, Toolbar)
	self._state  = appState
	self._frame  = nil
	self._modal  = nil
	self._widget = parent
	self:_build(parent)
	return self
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function btn(parent, text, xOff, width, color)
	local T = Theme
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width or 60, T.Sizes.BtnHeight)
	b.Position = UDim2.fromOffset(xOff, (T.Sizes.ToolbarHeight - T.Sizes.BtnHeight) / 2)
	b.BackgroundColor3 = color or T.Colors.BtnNormal
	b.TextColor3 = T.Colors.Text
	b.Text = text
	b.TextSize = T.Sizes.SmallText
	b.Font = T.Fonts.Bold
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

	b.MouseEnter:Connect(function() b.BackgroundColor3 = T.Colors.BtnHover end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = color or T.Colors.BtnNormal end)

	return b
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
function Toolbar:_build(parent)
	local T = Theme

	local bar = Instance.new("Frame")
	bar.Name = "Toolbar"
	bar.Size = UDim2.new(1, 0, 0, T.Sizes.ToolbarHeight)
	bar.BackgroundColor3 = T.Colors.Toolbar
	bar.BorderSizePixel = 0
	bar.ZIndex = 10
	bar.Parent = parent
	self._frame = bar

	local x = 6

	-- New
	local newBtn = btn(bar, "New", x, 48); x = x + 54
	newBtn.MouseButton1Click:Connect(function()
		self._state:Clear()
	end)

	-- Import
	local impBtn = btn(bar, "Import", x, 60); x = x + 66
	impBtn.MouseButton1Click:Connect(function()
		self:_showImportModal()
	end)

	-- Export
	local expBtn = btn(bar, "Export", x, 60); x = x + 66
	expBtn.MouseButton1Click:Connect(function()
		self:_showExportModal()
	end)

	-- Save to ModuleScript
	local saveBtn = btn(bar, "Save", x, 50, T.Colors.Accent); x = x + 56
	saveBtn.MouseButton1Click:Connect(function()
		self:_saveToModuleScript()
	end)

	-- NPCs
	local npcBtn = btn(bar, "NPCs", x, 48); x = x + 54
	npcBtn.MouseButton1Click:Connect(function()
		self:_showNPCModal()
	end)

	-- Separator
	x = x + 10

	-- Undo
	local undoBtn = btn(bar, "Undo", x, 48); x = x + 54
	undoBtn.MouseButton1Click:Connect(function()
		self._state:Undo()
	end)

	-- Redo
	local redoBtn = btn(bar, "Redo", x, 48); x = x + 54
	redoBtn.MouseButton1Click:Connect(function()
		self._state:Redo()
	end)

	x = x + 10

	-- Auto-Layout
	local layoutBtn = btn(bar, "Auto-Layout", x, 80); x = x + 86
	layoutBtn.MouseButton1Click:Connect(function()
		self._state:_pushUndo()
		Serializer.AutoLayout(self._state.nodes, self._state.startNodeId)
		self._state.stateLoaded:Fire()
	end)

	-- Tree ID field (right-aligned)
	local idLabel = Instance.new("TextLabel", bar)
	idLabel.Size = UDim2.fromOffset(40, T.Sizes.BtnHeight)
	idLabel.Position = UDim2.new(1, -220, 0, (T.Sizes.ToolbarHeight - T.Sizes.BtnHeight) / 2)
	idLabel.BackgroundTransparency = 1
	idLabel.Text = "Tree:"
	idLabel.TextColor3 = T.Colors.TextDim
	idLabel.TextSize = T.Sizes.SmallText
	idLabel.Font = T.Fonts.Bold
	idLabel.TextXAlignment = Enum.TextXAlignment.Right
	idLabel.ZIndex = 11

	local idBox = Instance.new("TextBox", bar)
	idBox.Size = UDim2.fromOffset(120, T.Sizes.BtnHeight)
	idBox.Position = UDim2.new(1, -175, 0, (T.Sizes.ToolbarHeight - T.Sizes.BtnHeight) / 2)
	idBox.BackgroundColor3 = T.Colors.Field
	idBox.TextColor3 = T.Colors.Text
	idBox.Text = self._state.treeId
	idBox.TextSize = T.Sizes.SmallText
	idBox.Font = T.Fonts.Mono
	idBox.BorderSizePixel = 0
	idBox.ClearTextOnFocus = false
	idBox.ZIndex = 11
	Instance.new("UICorner", idBox).CornerRadius = UDim.new(0, 4)

	idBox.FocusLost:Connect(function()
		if idBox.Text ~= "" then
			self._state:SetTreeId(idBox.Text)
		else
			idBox.Text = self._state.treeId
		end
	end)

	self._state.treeChanged:Connect(function()
		idBox.Text = self._state.treeId
	end)
	self._state.stateLoaded:Connect(function()
		idBox.Text = self._state.treeId
	end)
end

------------------------------------------------------------------------
-- Modals
------------------------------------------------------------------------
function Toolbar:_closeModal()
	if self._modal then self._modal:Destroy(); self._modal = nil end
end

function Toolbar:_makeModal(title, height)
	self:_closeModal()
	local T = Theme

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.4
	bg.ZIndex = 50
	bg.Parent = self._widget
	self._modal = bg

	local card = Instance.new("Frame", bg)
	card.Size = UDim2.fromOffset(500, height or 360)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = T.Colors.Panel
	card.BorderSizePixel = 0
	card.ZIndex = 51
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	Instance.new("UIStroke", card).Color = T.Colors.FieldBorder

	local titleLbl = Instance.new("TextLabel", card)
	titleLbl.Size = UDim2.new(1, 0, 0, 30)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = T.Colors.Text
	titleLbl.TextSize = 16
	titleLbl.Font = T.Fonts.Bold
	titleLbl.ZIndex = 52

	local closeBtn = Instance.new("TextButton", card)
	closeBtn.Size = UDim2.fromOffset(28, 28)
	closeBtn.Position = UDim2.new(1, -32, 0, 2)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = T.Colors.TextDim
	closeBtn.TextSize = 18
	closeBtn.Font = T.Fonts.Bold
	closeBtn.ZIndex = 52
	closeBtn.MouseButton1Click:Connect(function() self:_closeModal() end)

	return card
end

function Toolbar:_showImportModal()
	local T = Theme
	local card = self:_makeModal("Import Dialogue Tree", 380)

	local box = Instance.new("TextBox", card)
	box.Size = UDim2.new(1, -24, 1, -80)
	box.Position = UDim2.fromOffset(12, 36)
	box.BackgroundColor3 = T.Colors.Field
	box.TextColor3 = T.Colors.Text
	box.PlaceholderText = "Paste your dialogue text here..."
	box.PlaceholderColor3 = T.Colors.TextPlaceholder
	box.TextSize = T.Sizes.SmallText
	box.Font = T.Fonts.Mono
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.MultiLine = true
	box.TextWrapped = true
	box.ClearTextOnFocus = false
	box.BorderSizePixel = 0
	box.ZIndex = 52
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
	Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 6)

	local importBtn = Instance.new("TextButton", card)
	importBtn.Size = UDim2.fromOffset(120, 30)
	importBtn.Position = UDim2.new(0.5, -60, 1, -42)
	importBtn.BackgroundColor3 = T.Colors.Accent
	importBtn.TextColor3 = T.Colors.TextHeader
	importBtn.Text = "Import"
	importBtn.TextSize = T.Sizes.Text
	importBtn.Font = T.Fonts.Bold
	importBtn.BorderSizePixel = 0
	importBtn.ZIndex = 52
	Instance.new("UICorner", importBtn).CornerRadius = UDim.new(0, 4)

	importBtn.MouseButton1Click:Connect(function()
		local source = box.Text
		if source == "" then return end
		local data = Serializer.Import(source)
		self._state:LoadData(data)
		self:_closeModal()
	end)
end

function Toolbar:_showExportModal()
	local T = Theme
	local card = self:_makeModal("Export Dialogue Tree", 380)

	local exported = Serializer.Export(self._state)

	local box = Instance.new("TextBox", card)
	box.Size = UDim2.new(1, -24, 1, -80)
	box.Position = UDim2.fromOffset(12, 36)
	box.BackgroundColor3 = T.Colors.Field
	box.TextColor3 = T.Colors.Text
	box.Text = exported
	box.TextSize = T.Sizes.SmallText
	box.Font = T.Fonts.Mono
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.MultiLine = true
	box.TextWrapped = true
	box.TextEditable = false
	box.ClearTextOnFocus = false
	box.BorderSizePixel = 0
	box.ZIndex = 52
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
	Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 6)

	local hint = Instance.new("TextLabel", card)
	hint.Size = UDim2.new(1, 0, 0, 24)
	hint.Position = UDim2.new(0, 0, 1, -36)
	hint.BackgroundTransparency = 1
	hint.Text = "Select all text above and copy (Ctrl+A, Ctrl+C)"
	hint.TextColor3 = T.Colors.TextDim
	hint.TextSize = T.Sizes.SmallText
	hint.Font = T.Fonts.Default
	hint.ZIndex = 52
end

------------------------------------------------------------------------
-- NPC Config persistence
------------------------------------------------------------------------
function Toolbar:LoadNPCConfigFromStorage()
	local rs = game:GetService("ReplicatedStorage")
	local engine = rs:FindFirstChild("DialogueEngine")
	if not engine then return end
	local cfg = engine:FindFirstChild("NPCConfig")
	if not cfg or not cfg:IsA("ModuleScript") then return end
	local ok, data = pcall(function() return require(cfg) end)
	if ok and type(data) == "table" then
		self._state:LoadNPCConfigs(data)
	end
end

function Toolbar:SaveNPCConfigToStorage()
	local rs = game:GetService("ReplicatedStorage")
	local engine = rs:FindFirstChild("DialogueEngine")
	if not engine then
		engine = Instance.new("Folder")
		engine.Name = "DialogueEngine"
		engine.Parent = rs
	end

	local lines = { "return {" }
	for _, npc in ipairs(self._state.npcConfigs) do
		table.insert(lines, string.format('\t{ id = %q, displayName = %q },', npc.id, npc.displayName))
	end
	table.insert(lines, "}")
	local src = table.concat(lines, "\n")

	local existing = engine:FindFirstChild("NPCConfig")
	if existing then
		existing.Source = src
	else
		local ms = Instance.new("ModuleScript")
		ms.Name = "NPCConfig"
		ms.Source = src
		ms.Parent = engine
	end
end

function Toolbar:_showNPCModal()
	local T = Theme
	local card = self:_makeModal("NPC Configuration", 400)
	local state = self._state

	local listFrame = Instance.new("ScrollingFrame", card)
	listFrame.Size = UDim2.new(1, -24, 1, -100)
	listFrame.Position = UDim2.fromOffset(12, 36)
	listFrame.BackgroundTransparency = 1
	listFrame.ScrollBarThickness = 6
	listFrame.BorderSizePixel = 0
	listFrame.ZIndex = 52

	local function rebuildList()
		for _, child in ipairs(listFrame:GetChildren()) do child:Destroy() end
		local y = 0
		for i, npc in ipairs(state.npcConfigs) do
			local row = Instance.new("Frame", listFrame)
			row.Size = UDim2.new(1, 0, 0, 28)
			row.Position = UDim2.fromOffset(0, y)
			row.BackgroundTransparency = 1
			row.ZIndex = 52

			local lbl = Instance.new("TextLabel", row)
			lbl.Size = UDim2.new(1, -30, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = npc.displayName
			lbl.TextColor3 = T.Colors.Text
			lbl.TextSize = T.Sizes.Text
			lbl.Font = T.Fonts.Default
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.ZIndex = 52

			local rm = Instance.new("TextButton", row)
			rm.Size = UDim2.fromOffset(22, 22)
			rm.Position = UDim2.new(1, -22, 0, 3)
			rm.BackgroundColor3 = T.Colors.BtnDanger
			rm.TextColor3 = T.Colors.Text
			rm.Text = "X"
			rm.TextSize = 11
			rm.Font = T.Fonts.Bold
			rm.BorderSizePixel = 0
			rm.ZIndex = 52
			Instance.new("UICorner", rm).CornerRadius = UDim.new(0, 3)
			rm.MouseButton1Click:Connect(function()
				state:RemoveNPC(i)
				self:SaveNPCConfigToStorage()
				rebuildList()
			end)

			y = y + 32
		end
		listFrame.CanvasSize = UDim2.fromOffset(0, y)
	end
	rebuildList()

	local addBox = Instance.new("TextBox", card)
	addBox.Size = UDim2.new(1, -100, 0, 30)
	addBox.Position = UDim2.new(0, 12, 1, -56)
	addBox.BackgroundColor3 = T.Colors.Field
	addBox.TextColor3 = T.Colors.Text
	addBox.PlaceholderText = "NPC name..."
	addBox.PlaceholderColor3 = T.Colors.TextPlaceholder
	addBox.TextSize = T.Sizes.Text
	addBox.Font = T.Fonts.Default
	addBox.BorderSizePixel = 0
	addBox.ClearTextOnFocus = false
	addBox.ZIndex = 52
	Instance.new("UICorner", addBox).CornerRadius = UDim.new(0, 4)

	local addBtn = Instance.new("TextButton", card)
	addBtn.Size = UDim2.fromOffset(60, 30)
	addBtn.Position = UDim2.new(1, -76, 1, -56)
	addBtn.BackgroundColor3 = T.Colors.Accent
	addBtn.TextColor3 = T.Colors.TextHeader
	addBtn.Text = "Add"
	addBtn.TextSize = T.Sizes.Text
	addBtn.Font = T.Fonts.Bold
	addBtn.BorderSizePixel = 0
	addBtn.ZIndex = 52
	Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 4)

	addBtn.MouseButton1Click:Connect(function()
		local name = addBox.Text
		if name == "" then return end
		state:AddNPC(name)
		self:SaveNPCConfigToStorage()
		addBox.Text = ""
		rebuildList()
	end)
end

function Toolbar:_saveToModuleScript()
	local state = self._state
	local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	if not sps then
		warn("[DialogueDesigner] StarterPlayerScripts not found")
		return
	end

	local treesFolder = sps:FindFirstChild("DialogueTrees")
	if not treesFolder then
		treesFolder = Instance.new("Folder")
		treesFolder.Name = "DialogueTrees"
		treesFolder.Parent = sps
	end

	local modName = state.treeId or "untitled"
	local existing = treesFolder:FindFirstChild(modName)
	if existing then
		existing.Source = Serializer.ToModuleScript(state)
	else
		local ms = Instance.new("ModuleScript")
		ms.Name = modName
		ms.Source = Serializer.ToModuleScript(state)
		ms.Parent = treesFolder
	end

	self:_ensureLoader(treesFolder)

	local T = Theme
	local toast = Instance.new("TextLabel", self._widget)
	toast.Size = UDim2.fromOffset(260, 30)
	toast.Position = UDim2.new(0.5, -130, 1, -60)
	toast.BackgroundColor3 = T.Colors.Success
	toast.TextColor3 = T.Colors.TextHeader
	toast.Text = "Saved to StarterPlayerScripts/DialogueTrees/" .. modName
	toast.TextSize = T.Sizes.Text
	toast.Font = T.Fonts.Bold
	toast.ZIndex = 60
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 6)
	task.delay(2, function()
		if toast.Parent then toast:Destroy() end
	end)
end

function Toolbar:_ensureLoader(treesFolder)
	local loaderName = "DialogueTreeLoader"
	if treesFolder.Parent:FindFirstChild(loaderName) then return end

	local loader = Instance.new("LocalScript")
	loader.Name = loaderName
	loader.Source = [[
local DialogueEngine = require(game:GetService("ReplicatedStorage"):WaitForChild("DialogueEngine"):WaitForChild("DialogueEngine"))

local treesFolder = script.Parent:WaitForChild("DialogueTrees")
for _, child in ipairs(treesFolder:GetChildren()) do
	if child:IsA("ModuleScript") then
		local ok, treeData = pcall(require, child)
		if ok and treeData then
			DialogueEngine:RegisterTree(child.Name, treeData)
			print("[DialogueTreeLoader] Registered tree: " .. child.Name)
		else
			warn("[DialogueTreeLoader] Failed to load tree: " .. child.Name)
		end
	end
end
]]
	loader.Parent = treesFolder.Parent
end

function Toolbar:Destroy()
	self:_closeModal()
	if self._frame then self._frame:Destroy() end
end

return Toolbar
