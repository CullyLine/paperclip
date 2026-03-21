--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local SettingsPanel = {}

local function sliderRow(parent: Frame, label: string, order: number, initial: number, changed: (number) -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 52)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 18)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = label
	t.Parent = row

	local bar = Instance.new("TextButton")
	bar.Size = UDim2.new(1, 0, 0, 22)
	bar.Position = UDim2.new(0, 0, 0, 26)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(initial, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 6)
	fc.Parent = fill

	local function setFromX(x: number)
		local rel = math.clamp(x / bar.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		changed(rel)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X - bar.AbsolutePosition.X)
		end
	end)
	bar.InputChanged:Connect(function(input)
		if input.UserInputState == Enum.UserInputState.Change and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X - bar.AbsolutePosition.X)
		end
	end)
end

local function defaultBool(raw: any, key: string, default: boolean): boolean
	local v = raw[key]
	if type(v) == "boolean" then
		return v
	end
	return default
end

local function toggleRow(parent: Frame, label: string, order: number, initial: boolean, changed: (boolean) -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 44)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -100, 1, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = label
	t.Parent = row

	local on = initial
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 88, 0, 32)
	btn.Position = UDim2.new(1, -88, 0.5, -16)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = false
	btn.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = btn

	local function paint()
		if on then
			btn.BackgroundColor3 = Color3.fromRGB(60, 140, 90)
			btn.Text = "On"
		else
			btn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
			btn.Text = "Off"
		end
	end
	paint()

	btn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		on = not on
		paint()
		changed(on)
	end)
end

function SettingsPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = UIHelpers.panel(sg, "SettingsRoot")
	MenuHub.registerPanel("settings", root)
	UIHelpers.titleBar(root, "Settings", function()
		root.Visible = false
	end)

	local scroll = UIHelpers.scrolling(root)
	local lay = scroll:FindFirstChildOfClass("UIListLayout")
	if lay then
		lay:Destroy()
	end
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.Parent = scroll

	local data = Remotes.getFunction("GetPlayerData"):InvokeServer()
	local raw: any = if data and data.settings then data.settings else {}
	local s = {
		sound = defaultBool(raw, "sound", true),
		musicVolume = raw.musicVolume or 0.7,
		sfxVolume = raw.sfxVolume or 0.8,
		graphicsQuality = raw.graphicsQuality or 1,
		steeringSensitivity = raw.steeringSensitivity or 1,
		particles = defaultBool(raw, "particles", true),
		autoCenter = defaultBool(raw, "autoCenter", true),
		otherPets = defaultBool(raw, "otherPets", true),
		tradeRequests = defaultBool(raw, "tradeRequests", true),
	}

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	toggleRow(scroll, "Game sound", nextOrder(), s.sound, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ sound = v })
	end)
	sliderRow(scroll, "Music volume", nextOrder(), s.musicVolume, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ musicVolume = v })
	end)
	sliderRow(scroll, "SFX volume", nextOrder(), s.sfxVolume, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ sfxVolume = v })
	end)
	sliderRow(scroll, "Graphics (0 low — 2 high)", nextOrder(), s.graphicsQuality / 2, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ graphicsQuality = math.floor(v * 2 + 0.5) })
	end)
	toggleRow(scroll, "Particles & VFX", nextOrder(), s.particles, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ particles = v })
	end)
	sliderRow(scroll, "Steering sensitivity", nextOrder(), (s.steeringSensitivity - 0.5) / 1.5, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ steeringSensitivity = 0.5 + v * 1.5 })
	end)
	toggleRow(scroll, "Auto-center camera", nextOrder(), s.autoCenter, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ autoCenter = v })
	end)
	toggleRow(scroll, "Show other players' pets", nextOrder(), s.otherPets, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ otherPets = v })
	end)
	toggleRow(scroll, "Trade requests", nextOrder(), s.tradeRequests, function(v)
		Remotes.getEvent("UpdateSettings"):FireServer({ tradeRequests = v })
	end)
end

return SettingsPanel
