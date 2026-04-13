--!strict
--[[
	Builds the Inventory → Cars list row template (CarTemplate) at runtime if missing.
	Text + stats + equip only (no thumbnail).
]]

local CarInventoryTemplate = {}

local function corner(r: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	return c
end

local function stroke(thick: number, col: Color3): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thick
	s.Color = col
	return s
end

function CarInventoryTemplate.ensureInScroll(scroll: Instance)
	local existing = scroll:FindFirstChild("CarTemplate", true)
	if existing then
		if existing:FindFirstChild("CarViewport", true) then
			existing:Destroy()
		else
			return
		end
	end

	local root = Instance.new("Frame")
	root.Name = "CarTemplate"
	root.Visible = false
	root.BackgroundColor3 = Color3.fromRGB(255, 244, 252)
	root.BorderSizePixel = 0
	root.Size = UDim2.new(1, -12, 0, 96)
	root.ClipsDescendants = true

	corner(12).Parent = root
	stroke(2, Color3.fromRGB(42, 42, 64)).Parent = root

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = root

	local mid = Instance.new("Frame")
	mid.Name = "Details"
	mid.BackgroundTransparency = 1
	mid.Position = UDim2.new(0, 0, 0, 0)
	mid.Size = UDim2.new(1, -102, 1, 0)
	mid.Parent = root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Color3.fromRGB(28, 28, 42)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.Text = "Car"
	nameLabel.Parent = mid

	local statsRow = Instance.new("Frame")
	statsRow.Name = "StatsRow"
	statsRow.BackgroundTransparency = 1
	statsRow.Position = UDim2.new(0, 0, 0, 26)
	statsRow.Size = UDim2.new(1, 0, 0, 52)
	statsRow.Parent = mid

	local gasLabel = Instance.new("TextLabel")
	gasLabel.Name = "Gas"
	gasLabel.BackgroundTransparency = 1
	gasLabel.Font = Enum.Font.GothamBold
	gasLabel.TextSize = 12
	gasLabel.TextColor3 = Color3.fromRGB(70, 70, 90)
	gasLabel.TextXAlignment = Enum.TextXAlignment.Left
	gasLabel.TextYAlignment = Enum.TextYAlignment.Top
	gasLabel.Size = UDim2.new(1, 0, 0, 16)
	gasLabel.Position = UDim2.new(0, 0, 0, 0)
	gasLabel.Text = "Gas"
	gasLabel.Parent = statsRow

	local powerLabel = Instance.new("TextLabel")
	powerLabel.Name = "Power"
	powerLabel.BackgroundTransparency = 1
	powerLabel.Font = Enum.Font.GothamBold
	powerLabel.TextSize = 12
	powerLabel.TextColor3 = Color3.fromRGB(70, 70, 90)
	powerLabel.TextXAlignment = Enum.TextXAlignment.Left
	powerLabel.TextYAlignment = Enum.TextYAlignment.Top
	powerLabel.Size = UDim2.new(1, 0, 0, 16)
	powerLabel.Position = UDim2.new(0, 0, 0, 18)
	powerLabel.Text = "Power"
	powerLabel.Parent = statsRow

	local accelLabel = Instance.new("TextLabel")
	accelLabel.Name = "Acceleration"
	accelLabel.BackgroundTransparency = 1
	accelLabel.Font = Enum.Font.GothamBold
	accelLabel.TextSize = 12
	accelLabel.TextColor3 = Color3.fromRGB(70, 70, 90)
	accelLabel.TextXAlignment = Enum.TextXAlignment.Left
	accelLabel.TextYAlignment = Enum.TextYAlignment.Top
	accelLabel.Size = UDim2.new(1, 0, 0, 16)
	accelLabel.Position = UDim2.new(0, 0, 0, 36)
	accelLabel.Text = "Accel"
	accelLabel.Parent = statsRow

	local equip = Instance.new("TextButton")
	equip.Name = "Equip"
	equip.AnchorPoint = Vector2.new(1, 0.5)
	equip.Position = UDim2.new(1, -4, 0.5, 0)
	equip.Size = UDim2.new(0, 92, 0, 36)
	equip.Font = Enum.Font.GothamBold
	equip.TextSize = 14
	equip.TextColor3 = Color3.new(1, 1, 1)
	equip.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	equip.BorderSizePixel = 0
	equip.AutoButtonColor = true
	equip.Text = "Equip"
	corner(8).Parent = equip
	equip.Parent = root

	root.Parent = scroll
end

return CarInventoryTemplate
