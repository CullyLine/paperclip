--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = {}

function UIHelpers.panel(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(24, 24, 48)
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	f.Size = UDim2.new(0.9, 0, 0.85, 0)
	f.Position = UDim2.new(0.5, 0, 0.5, 0)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Visible = false
	f.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = f

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(120, 160, 255)
	s.Thickness = 2
	s.Transparency = 0.4
	s.Parent = f

	return f
end

function UIHelpers.titleBar(parent: Frame, title: string, onClose: () -> ())
	local bar = Instance.new("Frame")
	bar.Name = "TitleBar"
	bar.Size = UDim2.new(1, 0, 0, 44)
	bar.BackgroundTransparency = 1
	bar.Parent = parent

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -56, 1, 0)
	t.Position = UDim2.new(0, 16, 0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 22
	t.TextColor3 = Color3.fromRGB(245, 245, 245)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = title
	t.Parent = bar

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.new(0, 40, 0, 40)
	close.Position = UDim2.new(1, -48, 0, 4)
	close.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.Parent = bar
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = close
	close.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		onClose()
	end)

	return bar
end

function UIHelpers.textButton(
	parent: Instance,
	text: string,
	color: Color3,
	layoutOrder: number,
	callback: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = layoutOrder
	b.Size = UDim2.new(1, -16, 0, 40)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.AutoButtonColor = true
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	b.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		callback()
	end)
	return b
end

function UIHelpers.scrolling(parent: Frame): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = "Scroll"
	s.Size = UDim2.new(1, -24, 1, -60)
	s.Position = UDim2.new(0, 12, 0, 52)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.Parent = parent

	local lay = Instance.new("UIListLayout")
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Padding = UDim.new(0, 8)
	lay.Parent = s

	return s
end

function UIHelpers.scrollingGrid(parent: Frame): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = "ScrollGrid"
	s.Size = UDim2.new(1, -24, 1, -60)
	s.Position = UDim2.new(0, 12, 0, 52)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.Parent = parent

	local lay = Instance.new("UIGridLayout")
	lay.CellSize = UDim2.new(0, 140, 0, 160)
	lay.CellPadding = UDim2.new(0, 8, 0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = s

	return s
end

function UIHelpers.rarityStroke(rarity: string): Color3
	return Constants.RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)
end

function UIHelpers.currencyColor(currencyType: string): Color3
	local row = Constants.CURRENCY_DISPLAY[currencyType]
	return if row then row.color else Color3.fromRGB(255, 255, 255)
end

return UIHelpers
