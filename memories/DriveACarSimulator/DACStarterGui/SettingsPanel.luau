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
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local CreditsAboutConfig = require(DAC:WaitForChild("Config"):WaitForChild("CreditsAboutConfig"))
local MenuInputAccessibility = require(DAC:WaitForChild("MenuInputAccessibility"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local MenuHub = require(script.Parent:WaitForChild("MenuHub"))

local SettingsPanel = {}

-- MenuHub / AGENTS.md parity: body on light panel, chunky controls, emerald positive / red off.
local COLOR_TEXT_BODY = Color3.fromRGB(30, 30, 30)
local COLOR_TEXT_MUTED = Color3.fromRGB(90, 90, 110)
local COLOR_SECTION_BAR = Color3.fromRGB(204, 204, 204)
local COLOR_PANEL_BORDER = Color3.fromRGB(42, 42, 64)
local COLOR_SLIDER_TRACK = Color3.fromRGB(245, 242, 252)
local COLOR_SLIDER_FILL = Color3.fromRGB(120, 200, 255)
local COLOR_TOGGLE_ON = Color3.fromRGB(46, 204, 113)
local COLOR_TOGGLE_OFF = Color3.fromRGB(255, 68, 68)

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

-- Bypass merge batch so reset cannot race with a pending slider tick (POLA-651).
local function fireResetToDefaultsImmediate()
	pendingSettingsPatch = {}
	settingsFlushScheduled = false
	Remotes.getEvent("UpdateSettings"):FireServer({ resetToDefaults = true })
end

local function sectionHeaderRow(parent: Frame, title: string, order: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 32)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = COLOR_SECTION_BAR
	bar.BorderSizePixel = 0
	bar.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = bar
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_PANEL_BORDER
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = bar
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -16, 1, 0)
	t.Position = UDim2.new(0, 8, 0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 13
	t.TextColor3 = COLOR_TEXT_BODY
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = string.upper(title)
	t.Parent = bar
end

local function longFormTextRow(parent: Frame, order: number, body: string, textSize: number, color: Color3)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 0)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = row
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Gotham
	t.TextSize = textSize
	t.TextColor3 = color
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.TextWrapped = true
	t.Text = body
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Parent = row
end

local function accessibilityFooter(parent: Frame, order: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 0)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = row
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Gotham
	t.TextSize = 12
	t.TextColor3 = COLOR_TEXT_MUTED
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.TextWrapped = true
	local minPx = tostring(HudLayoutConfig.minTouchPx)
	t.Text = `Controls use at least {minPx}px touch targets. Keyboard: Tab to focus. Gamepad: bumpers to move.`
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Parent = row
end

local function sliderRow(
	parent: Frame,
	label: string,
	order: number,
	initial: number,
	changed: (number) -> (),
	hint: string?
)
	local row = Instance.new("Frame")
	local labelH = if hint then 38 else 22
	row.Size = UDim2.new(1, -20, 0, labelH + 44 + 6)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -8, 0, if hint then 18 else 22)
	t.Position = UDim2.new(0, 0, 0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 15
	t.TextColor3 = COLOR_TEXT_BODY
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.Text = label
	t.TextWrapped = false
	t.Parent = row
	if hint then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -8, 0, 16)
		sub.Position = UDim2.new(0, 0, 0, 20)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 12
		sub.TextColor3 = COLOR_TEXT_MUTED
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Text = hint
		sub.Parent = row
	end
	local bar = Instance.new("TextButton")
	bar.Size = UDim2.new(1, 0, 0, 44)
	bar.Position = UDim2.new(0, 0, 0, labelH)
	bar.AnchorPoint = Vector2.new(0, 0)
	bar.BackgroundColor3 = COLOR_SLIDER_TRACK
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.ClipsDescendants = true
	bar.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = bar
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_PANEL_BORDER
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(initial, 0, 1, 0)
	fill.BackgroundColor3 = COLOR_SLIDER_FILL
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 8)
	fc.Parent = fill
	local barScale = Instance.new("UIScale"); barScale.Scale = 1; barScale.Parent = bar
	local function pulseGrab(on: boolean)
		TweenService:Create(barScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = if on then 1.06 else 1 }):Play()
	end
	local function setFromX(x: number)
		local w = bar.AbsoluteSize.X
		if w <= 0 then
			w = 1
		end
		local rel = math.clamp(x / w, 0, 1)
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
	MenuInputAccessibility.applyPrimaryNavDefaults(bar)
	return {
		setFraction = function(frac: number)
			local f = math.clamp(frac, 0, 1)
			fill.Size = UDim2.new(f, 0, 1, 0)
		end,
	}
end

local function defaultBool(raw: any, key: string, default: boolean): boolean
	local v = raw[key]; if type(v) == "boolean" then return v end; return default
end

local function clamp01(n: number): number
	return math.clamp(n, 0, 1)
end

--[[
	Coerce saved / server settings into safe values (nil or DataStore corruption).
]]
local function normalizeSettings(raw: any)
	local r = raw
	if type(r) ~= "table" then
		r = {}
	end
	local mv: number = 0.7
	if type(r.musicVolume) == "number" and r.musicVolume == r.musicVolume then
		mv = r.musicVolume
	end
	local sv: number = 0.8
	if type(r.sfxVolume) == "number" and r.sfxVolume == r.sfxVolume then
		sv = r.sfxVolume
	end
	local gq = 1
	if type(r.graphicsQuality) == "number" and r.graphicsQuality == r.graphicsQuality then
		gq = r.graphicsQuality
	end
	local pd = 2
	if type(r.particleDensity) == "number" and r.particleDensity == r.particleDensity then
		pd = r.particleDensity
	end
	local st = 1
	if type(r.steeringSensitivity) == "number" and r.steeringSensitivity == r.steeringSensitivity then
		st = r.steeringSensitivity
	end
	return {
		sound = defaultBool(r, "sound", true),
		musicVolume = clamp01(mv),
		sfxVolume = clamp01(sv),
		graphicsQuality = math.clamp(math.floor(gq), 0, 2),
		steeringSensitivity = math.clamp(st, 0.5, 2),
		particles = defaultBool(r, "particles", true),
		reducedMotion = defaultBool(r, "reducedMotion", false),
		particleDensity = math.clamp(math.floor(pd), 0, 2),
		showFps = defaultBool(r, "showFps", false),
		autoCenter = defaultBool(r, "autoCenter", true),
		otherPets = defaultBool(r, "otherPets", true),
		otherPetAnimations = defaultBool(r, "otherPetAnimations", true),
		tradeRequests = defaultBool(r, "tradeRequests", true),
	}
end

-- Master audio: speaker glyph + diagonal strike tween (POLA-429); optimistic audio via SoundFacade.
local function gameSoundMuteRow(
	parent: Frame,
	label: string,
	order: number,
	initialSoundOn: boolean,
	reducedMotion: boolean,
	changed: (boolean) -> ()
)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 54)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -168, 0, 18)
	title.Position = UDim2.new(0, 0, 0, 2)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = COLOR_TEXT_BODY
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = label
	title.Parent = row

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -168, 0, 14)
	sub.Position = UDim2.new(0, 0, 0, 22)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.TextColor3 = COLOR_TEXT_MUTED
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = "Mute all music & SFX"
	sub.Parent = row

	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "MuteIcon"
	iconHolder.Size = UDim2.new(0, 44, 0, 44)
	iconHolder.Position = UDim2.new(1, -152, 0.5, -22)
	iconHolder.AnchorPoint = Vector2.new(0, 0.5)
	iconHolder.BackgroundTransparency = 1
	iconHolder.Parent = row

	local iconScale = Instance.new("UIScale")
	iconScale.Scale = 1
	iconScale.Parent = iconHolder

	local speaker = Instance.new("TextLabel")
	speaker.Size = UDim2.new(1, 0, 1, 0)
	speaker.BackgroundTransparency = 1
	speaker.Text = "🔊"
	speaker.TextSize = 26
	speaker.Parent = iconHolder

	local slash = Instance.new("Frame")
	slash.Name = "Strike"
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.new(0.5, 0, 0.5, 0)
	slash.Size = UDim2.new(0, 3, 0, 30)
	slash.Rotation = -52
	slash.BackgroundColor3 = COLOR_PANEL_BORDER
	slash.BorderSizePixel = 0
	slash.ZIndex = 2
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 2)
	sc.Parent = slash
	slash.Parent = iconHolder

	slash.BackgroundTransparency = if initialSoundOn then 1 else 0

	local on = initialSoundOn
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 100, 0, 44)
	btn.Position = UDim2.new(1, -100, 0.5, -22)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = false
	btn.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = btn
	local onColor = COLOR_TOGGLE_ON
	local offColor = COLOR_TOGGLE_OFF
	btn.BackgroundColor3 = if on then onColor else offColor
	btn.Text = if on then "On" else "Off"

	local function paintBtn()
		TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = if on then onColor else offColor,
		}):Play()
		btn.Text = if on then "On" else "Off"
	end

	local function tweenStrike(showStrike: boolean)
		local t = if reducedMotion then 0 else 0.18
		local goal = if showStrike then 0 else 1
		if t < 0.01 then
			slash.BackgroundTransparency = goal
			return
		end
		TweenService:Create(slash, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = goal,
		}):Play()
	end

	local function punchIcon()
		if reducedMotion then
			return
		end
		TweenService:Create(iconScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
		task.delay(0.08, function()
			if not iconScale.Parent then
				return
			end
			TweenService:Create(iconScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end

	btn.MouseButton1Click:Connect(function()
		on = not on
		paintBtn()
		tweenStrike(not on)
		punchIcon()
		SoundFacade.applyGameSoundMasterToggle(on)
		changed(on)
	end)
	MenuInputAccessibility.applyPrimaryNavDefaults(btn)
	return {
		setSound = function(b: boolean)
			on = b
			paintBtn()
			slash.BackgroundTransparency = if on then 1 else 0
		end,
	}
end

local function toggleRow(parent: Frame, label: string, order: number, initial: boolean, changed: (boolean) -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 52)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -112, 1, -4)
	t.Position = UDim2.new(0, 0, 0, 2)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 15
	t.TextColor3 = COLOR_TEXT_BODY
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.Text = label
	t.TextWrapped = true
	t.Parent = row
	local on = initial
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 100, 0, 44)
	btn.Position = UDim2.new(1, -100, 0.5, -22)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = false
	btn.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = btn
	local onColor = COLOR_TOGGLE_ON
	local offColor = COLOR_TOGGLE_OFF
	btn.BackgroundColor3 = if on then onColor else offColor
	btn.Text = if on then "On" else "Off"
	local function paint()
		TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = if on then onColor else offColor }):Play()
		btn.Text = if on then "On" else "Off"
	end
	btn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click"); on = not on; paint(); changed(on)
	end)
	MenuInputAccessibility.applyPrimaryNavDefaults(btn)
	return {
		setBool = function(b: boolean)
			on = b
			btn.BackgroundColor3 = if on then onColor else offColor
			btn.Text = if on then "On" else "Off"
		end,
	}
end

local function resetToDefaultsRow(parent: Frame, order: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 52)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -112, 1, -4)
	t.Position = UDim2.new(0, 0, 0, 2)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 15
	t.TextColor3 = COLOR_TEXT_BODY
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.TextWrapped = true
	t.Text = "Reset all settings to defaults"
	t.Parent = row
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 100, 0, 44)
	btn.Position = UDim2.new(1, -100, 0.5, -22)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Color3.fromRGB(255, 68, 68)
	btn.Text = "Reset"
	btn.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = btn
	btn.MouseButton1Click:Connect(function()
		SoundFacade.playOneShot("click")
		fireResetToDefaultsImmediate()
	end)
	MenuInputAccessibility.applyPrimaryNavDefaults(btn)
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
	if lay then
		lay.Padding = UDim.new(0, 8)
	end

	local okFetch, fetched = pcall(function()
		return Remotes.getFunction("GetPlayerData"):InvokeServer()
	end)
	local raw: any = if okFetch and type(fetched) == "table" and type(fetched.settings) == "table" then fetched.settings else {}
	local s = normalizeSettings(raw)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	sectionHeaderRow(scroll, "Audio", nextOrder())
	local hSound = gameSoundMuteRow(scroll, "Game sound", nextOrder(), s.sound, s.reducedMotion, function(v)
		queueSettingsPatch({ sound = v })
	end)
	local hMusic = sliderRow(scroll, "Music volume", nextOrder(), s.musicVolume, function(v)
		queueSettingsPatch({ musicVolume = v })
	end, nil)
	local hSfx = sliderRow(scroll, "SFX volume", nextOrder(), s.sfxVolume, function(v)
		queueSettingsPatch({ sfxVolume = v })
	end, nil)

	sectionHeaderRow(scroll, "Visuals", nextOrder())
	local hGfx = sliderRow(scroll, "Graphics quality", nextOrder(), s.graphicsQuality / 2, function(v)
		queueSettingsPatch({ graphicsQuality = math.floor(v * 2 + 0.5) })
	end, "0 = low · 2 = high")
	local hParticleD = sliderRow(scroll, "Particle density", nextOrder(), s.particleDensity / 2, function(v)
		queueSettingsPatch({ particleDensity = math.floor(v * 2 + 0.5) })
	end, "0 = min · 2 = max")
	local hReduced = toggleRow(scroll, "Reduced motion", nextOrder(), s.reducedMotion, function(v)
		queueSettingsPatch({ reducedMotion = v })
	end)
	local hShowFps = toggleRow(scroll, "Show FPS counter", nextOrder(), s.showFps, function(v)
		queueSettingsPatch({ showFps = v })
	end)
	local hParticles = toggleRow(scroll, "Particles & VFX", nextOrder(), s.particles, function(v)
		queueSettingsPatch({ particles = v })
	end)

	sectionHeaderRow(scroll, "Controls", nextOrder())
	local hSteer = sliderRow(scroll, "Steering sensitivity", nextOrder(), (s.steeringSensitivity - 0.5) / 1.5, function(v)
		queueSettingsPatch({ steeringSensitivity = 0.5 + v * 1.5 })
	end, nil)
	local hAutoCenter = toggleRow(scroll, "Auto-center camera", nextOrder(), s.autoCenter, function(v)
		queueSettingsPatch({ autoCenter = v })
	end)

	sectionHeaderRow(scroll, "Social", nextOrder())
	local hOtherPets = toggleRow(scroll, "Show other players' pets", nextOrder(), s.otherPets, function(v)
		queueSettingsPatch({ otherPets = v })
	end)
	local hOtherPetAnims = toggleRow(scroll, "Other players' pet animations", nextOrder(), s.otherPetAnimations, function(v)
		queueSettingsPatch({ otherPetAnimations = v })
	end)
	local hTrade = toggleRow(scroll, "Trade requests", nextOrder(), s.tradeRequests, function(v)
		queueSettingsPatch({ tradeRequests = v })
	end)

	-- POLA-735: About + Credits + build line (copy: CreditsAboutConfig / docs/POLA735_CreditsAndAboutCopyPass.md)
	sectionHeaderRow(scroll, CreditsAboutConfig.SECTION_ABOUT, nextOrder())
	longFormTextRow(scroll, nextOrder(), CreditsAboutConfig.ABOUT_BODY, 14, COLOR_TEXT_BODY)
	local buildVer = (game :: any).PlaceVersion
	if type(buildVer) ~= "number" or buildVer ~= buildVer then
		buildVer = 0
	end
	longFormTextRow(
		scroll,
		nextOrder(),
		`{CreditsAboutConfig.VERSION_LABEL_PREFIX} {math.floor(buildVer)}`,
		12,
		COLOR_TEXT_MUTED
	)
	sectionHeaderRow(scroll, CreditsAboutConfig.SECTION_CREDITS, nextOrder())
	longFormTextRow(scroll, nextOrder(), CreditsAboutConfig.CREDITS_BODY, 13, COLOR_TEXT_BODY)

	sectionHeaderRow(scroll, "Restore", nextOrder())
	resetToDefaultsRow(scroll, nextOrder())

	local function applySnapshot(ns: any)
		hSound.setSound(ns.sound)
		hMusic.setFraction(ns.musicVolume)
		hSfx.setFraction(ns.sfxVolume)
		hGfx.setFraction(ns.graphicsQuality / 2)
		hParticleD.setFraction(ns.particleDensity / 2)
		hReduced.setBool(ns.reducedMotion)
		hShowFps.setBool(ns.showFps)
		hParticles.setBool(ns.particles)
		hSteer.setFraction((ns.steeringSensitivity - 0.5) / 1.5)
		hAutoCenter.setBool(ns.autoCenter)
		hOtherPets.setBool(ns.otherPets)
		hOtherPetAnims.setBool(ns.otherPetAnimations)
		hTrade.setBool(ns.tradeRequests)
	end

	Remotes.getEvent("DataUpdate").OnClientEvent:Connect(function(d: any)
		if type(d) ~= "table" or type(d.settings) ~= "table" then
			return
		end
		applySnapshot(normalizeSettings(d.settings))
	end)

	accessibilityFooter(scroll, nextOrder())
end

return SettingsPanel
