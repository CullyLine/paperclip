--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local QuestConfig = require(DAC:WaitForChild("Config"):WaitForChild("QuestConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local QuestPanel = {}

local function describeSlot(slot: any): (string, string)
	local def = QuestConfig.getById(slot.defId)
	if not def then
		return "?", "?"
	end
	local prog = slot.progress or 0
	local tgt = def.target
	local line = `{def.title}  ({prog}/{tgt})`
	local sub = `+{def.xpReward} Season XP`
	return line, sub
end

local function milestoneLine(id: string, slot: any): (string, string)
	local def = QuestConfig.getById(id)
	if not def then
		return "?", "?"
	end
	local prog = slot.progress or 0
	local tgt = def.target
	if slot.completed then
		return `{def.title}  ✓`, "Complete"
	end
	return `{def.title}  ({prog}/{tgt})`, `+{def.xpReward} Season XP`
end

function QuestPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "QuestPanelRoot")
	MenuHub.registerPanel("quests", root)
	UIHelpers.titleBar(root, "Season Quests", function()
		root.Visible = false
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "QuestScroll"
	scroll.Size = UDim2.new(1, -24, 1, -60)
	scroll.Position = UDim2.new(0, 12, 0, 52)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = root

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local dailyHeader = Instance.new("TextLabel")
	dailyHeader.Size = UDim2.new(1, -8, 0, 22)
	dailyHeader.BackgroundTransparency = 1
	dailyHeader.Font = Enum.Font.GothamBold
	dailyHeader.TextSize = 16
	dailyHeader.TextColor3 = Color3.fromRGB(120, 200, 255)
	dailyHeader.TextXAlignment = Enum.TextXAlignment.Left
	dailyHeader.Text = "Daily (resets UTC midnight)"
	dailyHeader.LayoutOrder = 1
	dailyHeader.Parent = scroll

	local dailyRows: { TextLabel } = {}
	for i = 1, 3 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -8, 0, 44)
		row.BackgroundColor3 = Color3.fromRGB(32, 36, 64)
		row.TextWrapped = true
		row.Font = Enum.Font.Gotham
		row.TextSize = 13
		row.TextColor3 = Color3.new(1, 1, 1)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = "—"
		row.LayoutOrder = 1 + i
		row.Parent = scroll
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row
		dailyRows[i] = row
	end

	local weeklyHeader = Instance.new("TextLabel")
	weeklyHeader.Size = UDim2.new(1, -8, 0, 22)
	weeklyHeader.BackgroundTransparency = 1
	weeklyHeader.Font = Enum.Font.GothamBold
	weeklyHeader.TextSize = 16
	weeklyHeader.TextColor3 = Color3.fromRGB(255, 200, 120)
	weeklyHeader.TextXAlignment = Enum.TextXAlignment.Left
	weeklyHeader.Text = "Weekly (resets Monday UTC)"
	weeklyHeader.LayoutOrder = 10
	weeklyHeader.Parent = scroll

	local weeklyRows: { TextLabel } = {}
	for i = 1, 3 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -8, 0, 44)
		row.BackgroundColor3 = Color3.fromRGB(40, 36, 50)
		row.TextWrapped = true
		row.Font = Enum.Font.Gotham
		row.TextSize = 13
		row.TextColor3 = Color3.new(1, 1, 1)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = "—"
		row.LayoutOrder = 10 + i
		row.Parent = scroll
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row
		weeklyRows[i] = row
	end

	local mileHeader = Instance.new("TextLabel")
	mileHeader.Size = UDim2.new(1, -8, 0, 22)
	mileHeader.BackgroundTransparency = 1
	mileHeader.Font = Enum.Font.GothamBold
	mileHeader.TextSize = 16
	mileHeader.TextColor3 = Color3.fromRGB(200, 160, 255)
	mileHeader.TextXAlignment = Enum.TextXAlignment.Left
	mileHeader.Text = "Milestones (one-time this season)"
	mileHeader.LayoutOrder = 20
	mileHeader.Parent = scroll

	local mileScroll = Instance.new("Frame")
	mileScroll.Name = "Milestones"
	mileScroll.Size = UDim2.new(1, -8, 0, 0)
	mileScroll.AutomaticSize = Enum.AutomaticSize.Y
	mileScroll.BackgroundTransparency = 1
	mileScroll.LayoutOrder = 21
	mileScroll.Parent = scroll

	local mileList = Instance.new("UIListLayout")
	mileList.Padding = UDim.new(0, 6)
	mileList.Parent = mileScroll

	local function refresh(data: any)
		if not data or not data.quests then
			return
		end
		local q = data.quests
		for i = 1, 3 do
			local slot = q.daily[i]
			if slot then
				local line, sub = describeSlot(slot)
				dailyRows[i].Text = `{line}\n{sub}`
			else
				dailyRows[i].Text = "—"
			end
		end
		for i = 1, 3 do
			local slot = q.weekly[i]
			if slot then
				local line, sub = describeSlot(slot)
				weeklyRows[i].Text = `{line}\n{sub}`
			else
				weeklyRows[i].Text = "—"
			end
		end
		for _, child in mileScroll:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		if q.milestone then
			for _, def in QuestConfig.Milestones do
				local slot = q.milestone[def.id]
				if slot then
					local line, sub = milestoneLine(def.id, slot)
					local row = Instance.new("TextLabel")
					row.Size = UDim2.new(1, 0, 0, 40)
					row.BackgroundColor3 = Color3.fromRGB(28, 28, 50)
					row.TextWrapped = true
					row.Font = Enum.Font.Gotham
					row.TextSize = 12
					row.TextColor3 = Color3.new(1, 1, 1)
					row.TextXAlignment = Enum.TextXAlignment.Left
					row.Text = `{line}\n{sub}`
					row.Parent = mileScroll
					local rc = Instance.new("UICorner")
					rc.CornerRadius = UDim.new(0, 6)
					rc.Parent = row
				end
			end
		end
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(refresh)
	task.defer(function()
		local ok, initial = pcall(function()
			return Remotes.getFunction("GetQuests"):InvokeServer()
		end)
		if ok and initial then
			refresh(initial)
		end
	end)
end

return QuestPanel
