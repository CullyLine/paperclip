--!strict
--[[
	Settings panel.
	Shell UI is pre-built in DACMain.Panels.Settings; this script wires behavior
	and dynamically creates slider/toggle rows based on player data.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local SettingsPanel = {}

local pendingSettingsPatch: { [string]: any } = {}
local settingsFlushScheduled = false
local SETTINGS_BATCH_SEC = 0.28

local function queueSettingsPatch(patch: { [string]: any })
	for k, v in patch do pendingSettingsPatch[k] = v end
	if settingsFlushScheduled then return end
	settingsFlushScheduled = true
	task.delay(SETTINGS_BATCH_SEC, function()
		settingsFlushScheduled = false
		if next(pendingSettingsPatch) == nil then return end
		local merged = pendingSettingsPatch
		pendingSettingsPatch = {}
		Remotes.getEvent("UpdateSettings"):FireServer(merged)
	end)
end

local function sliderRow(parent: Frame, label: string, order: number, initial: number, changed: (number) -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 52); row.BackgroundTransparency = 1
	row.LayoutOrder = order; row.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 18); t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold; t.TextSize = 14; t.TextColor3 = Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left; t.Text = label; t.Parent = row
	local bar = Instance.new("TextButton")
	bar.Size = UDim2.new(1, 0, 0, 22); bar.Position = UDim2.new(0, 0, 0, 26)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 90); bar.Text = ""; bar.AutoButtonColor = false; bar.Parent = row
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(initial, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	fill.BorderSizePixel = 0; fill.Parent = bar
	local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 6); fc.Parent = fill
	local barScale = Instance.new("UIScale"); barScale.Scale = 1; barScale.Parent = bar
	local function pulseGrab(on: boolean)
		TweenService:Create(barScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = if on then 1.06 else 1 }):Play()
	end
	local function setFromX(x: number)
		local rel = math.clamp(x / bar.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(rel, 0, 1, 0); changed(rel)
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pulseGrab(true); setFromX(input.Position.X - bar.AbsolutePosition.X)
		end
	end)
	bar.InputChanged:Connect(function(input)
		if input.UserInputState == Enum.UserInputState.Change and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X - bar.AbsolutePosition.X)
		end
	end)
	local endConn: RBXScriptConnection? = nil
	endConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pulseGrab(false) end
	end)
	bar.Destroying:Connect(function() if endConn then endConn:Disconnect() end end)
end

local function defaultBool(raw: any, key: string, default: boolean): boolean
	local v = raw[key]; if type(v) == "boolean" then return v end; return default
end

local function toggleRow(parent: Frame, label: string, order: number, initial: boolean, changed: (boolean) -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 44); row.BackgroundTransparency = 1
	row.LayoutOrder = order; row.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -100, 1, 0); t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold; t.TextSize = 14; t.TextColor3 = Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left; t.Text = label; t.Parent = row
	local on = initial
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 88, 0, 32); btn.Position = UDim2.new(1, -88, 0.5, -16)
	btn.Font = Enum.Font.GothamBold; btn.TextSize = 14; btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = false; btn.Parent = row
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = btn
	local onColor = Color3.fromRGB(60, 140, 90)
	local offColor = Color3.fromRGB(70, 70, 90)
	btn.BackgroundColor3 = if on then onColor else offColor
	btn.Text = if on then "On" else "Off"
	local function paint()
		TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = if on then onColor else offColor }):Play()
		btn.Text = if on then "On" else "Off"
	end
	btn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click"); on = not on; paint(); changed(on)
	end)
end

function SettingsPanel.init()
	local sg = MenuHub.getScreenGui()
	local root = sg:WaitForChild("Settings") :: Frame
	local openPos = UDim2.new(0.5, 0, 0.5, 0)
	local offRightPos = UDim2.new(1.12, 0, 0.5, 0)

	local function animateOpen()
		root.Position = offRightPos
		TweenService:Create(root, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = openPos }):Play()
	end
	local function animateClose(done: () -> ())
		TweenService:Create(root, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = offRightPos }):Play()
		task.delay(0.29, function() if root.Parent then root.Position = openPos; done() end end)
	end
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then task.defer(animateOpen) end
	end)

	local scroll = root:WaitForChild("Scroll") :: ScrollingFrame
	local lay = scroll:FindFirstChildOfClass("UIListLayout")
	if lay then lay.Padding = UDim.new(0, 6) end

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
	local function nextOrder(): number order += 1; return order end
	toggleRow(scroll, "Game sound", nextOrder(), s.sound, function(v) queueSettingsPatch({ sound = v }) end)
	sliderRow(scroll, "Music volume", nextOrder(), s.musicVolume, function(v) queueSettingsPatch({ musicVolume = v }) end)
	sliderRow(scroll, "SFX volume", nextOrder(), s.sfxVolume, function(v) queueSettingsPatch({ sfxVolume = v }) end)
	sliderRow(scroll, "Graphics (0 low \u{2014} 2 high)", nextOrder(), s.graphicsQuality / 2, function(v) queueSettingsPatch({ graphicsQuality = math.floor(v * 2 + 0.5) }) end)
	toggleRow(scroll, "Particles & VFX", nextOrder(), s.particles, function(v) queueSettingsPatch({ particles = v }) end)
	sliderRow(scroll, "Steering sensitivity", nextOrder(), (s.steeringSensitivity - 0.5) / 1.5, function(v) queueSettingsPatch({ steeringSensitivity = 0.5 + v * 1.5 }) end)
	toggleRow(scroll, "Auto-center camera", nextOrder(), s.autoCenter, function(v) queueSettingsPatch({ autoCenter = v }) end)
	toggleRow(scroll, "Show other players' pets", nextOrder(), s.otherPets, function(v) queueSettingsPatch({ otherPets = v }) end)
	toggleRow(scroll, "Trade requests", nextOrder(), s.tradeRequests, function(v) queueSettingsPatch({ tradeRequests = v }) end)
end

return SettingsPanel
