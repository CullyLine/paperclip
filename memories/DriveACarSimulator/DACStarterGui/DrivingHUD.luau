--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local SpeedMilestoneConfig = require(DAC:WaitForChild("Config"):WaitForChild("SpeedMilestoneConfig"))
local SpeedTierCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("SpeedTierCopyConfig"))
local SocialFeedConfig = require(DAC:WaitForChild("Config"):WaitForChild("SocialFeedConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local VFXFacade = require(DAC:WaitForChild("VFXFacade"))

local DrivingHUD = {}

local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local TweenService = game:GetService("TweenService")

local drivingUI: Frame
local gasBar: ImageLabel
local gasBackground: ImageLabel
local gasText: TextLabel
local gasPanicStroke: UIStroke? = nil
local gasGoldenStroke: UIStroke? = nil
local speedText: TextLabel
local powerText: TextLabel
local travelFrame: ImageLabel
local travelLabel: TextLabel
local lapsLabel: TextLabel
local recordFrame: Instance?

local isVisible = false
local maxGas = 0
local currentGas = 0
local currentDistance = 0
local currentLaps = 0
local currentSpeed = 0
local currentPower = 0
local bestDistance = 0

local DrivingController: any = nil
local hudMilestoneFlashBusy = false
local hudNearMissFlashBusy = false
local hudComboCelebrationBusy = false
local hudComboBreakBusy = false
local hudTierNameFlashBusy = false
local hudAccelCalloutBusy = false
local lastSpeedTierKey: string? = nil
local tierNameFlashQueue: { string } = {}
local accelCalloutQueue: { string } = {}

local speedUIScale: UIScale? = nil

local lastAlmostSpeedToastClock = 0.0
local lastAlmostSpeedToastThreshold: number? = nil
local ALMOST_SPEED_TOAST_COOLDOWN_SEC = 28.0
local lastGasPercentForHudSfx = 1.0

local C_SPEED_WHITE = Color3.fromRGB(255, 255, 255)
local C_SPEED_YELLOW = Color3.fromRGB(255, 230, 80)
local C_SPEED_ORANGE = Color3.fromRGB(255, 160, 40)
local C_SPEED_RED = Color3.fromRGB(255, 60, 40)
local C_SPEED_MAGENTA = Color3.fromRGB(255, 40, 200)

local function milestoneCelebrationColor(th: number): Color3
	local hex = SpeedMilestoneConfig.MilestoneColor[th]
	if type(hex) == "string" and hex ~= "" then
		local ok, c = pcall(function()
			return Color3.fromHex(hex)
		end)
		if ok and typeof(c) == "Color3" then
			return c
		end
	end
	return SpeedMilestoneConfig.CelebrationColor[th] or Color3.fromRGB(255, 230, 100)
end

local function speedToColor(s: number): Color3
	if s <= 50 then
		return C_SPEED_WHITE
	elseif s <= 100 then
		local t = (s - 50) / 50
		return C_SPEED_WHITE:Lerp(C_SPEED_YELLOW, t)
	elseif s <= 200 then
		local t = (s - 100) / 100
		return C_SPEED_YELLOW:Lerp(C_SPEED_ORANGE, t)
	elseif s <= 300 then
		local t = (s - 200) / 100
		return C_SPEED_ORANGE:Lerp(C_SPEED_RED, t)
	else
		return C_SPEED_MAGENTA
	end
end

local TIER_ORDER: { [string]: number } = {
	Cruising = 1,
	Fast = 2,
	Blazing = 3,
	Insane = 4,
	Legendary = 5,
}

local function speedTierKeyForSpeed(speed: number): string
	local k = "Cruising"
	for _, row in SpeedTierCopyConfig.TierThresholds do
		if speed >= row.min then
			k = row.key
		end
	end
	return k
end

local function tryGetDrivingController()
	if DrivingController then return end
	local ok, mod = pcall(function()
		local sps = player:WaitForChild("PlayerScripts", 2)
		if not sps then return nil end
		local dac = sps:FindFirstChild("DAC")
		if not dac then return nil end
		local ctrls = dac:FindFirstChild("Controllers")
		if not ctrls then return nil end
		local dc = ctrls:FindFirstChild("DrivingController")
		if not dc then return nil end
		return require(dc)
	end)
	if ok and mod then
		DrivingController = mod
	end
end

function DrivingHUD.show(stats: { gas: number, speed: number, power: number })
	maxGas = stats.gas
	currentGas = stats.gas
	currentDistance = 0
	currentLaps = 0
	currentSpeed = stats.speed
	currentPower = stats.power
	lastSpeedTierKey = nil
	table.clear(tierNameFlashQueue)
	table.clear(accelCalloutQueue)
	lastAlmostSpeedToastClock = 0.0
	lastAlmostSpeedToastThreshold = nil
	lastGasPercentForHudSfx = 1.0
	isVisible = true
	if drivingUI then
		drivingUI.Visible = true
	end
	if travelFrame then
		travelFrame.Visible = true
	end
end

function DrivingHUD.hide()
	isVisible = false
	lastSpeedTierKey = nil
	if drivingUI then
		drivingUI.Visible = false
	end
	if travelFrame then
		travelFrame.Visible = false
	end
end

local function render()
	if not isVisible then return end

	if DrivingController then
		local state = DrivingController.getRunState()
		if state then
			currentDistance = state.distance
			currentGas = state.gas
			currentSpeed = state.speed
			currentLaps = state.laps
		end
	end

	local gasPercent = if maxGas > 0 then math.clamp(currentGas / maxGas, 0, 1) else 0
	VFXFacade.fuelPanic(gasPercent)
	if lastGasPercentForHudSfx >= 0.05 and gasPercent < 0.05 then
		SoundFacade.playOneShot("fuel_warning")
	end
	lastGasPercentForHudSfx = gasPercent

	if gasBar then
		gasBar.Size = UDim2.new(gasPercent * 0.5, 0, gasBar.Size.Y.Scale, 0)
	end

	if gasText then
		gasText.Text = tostring(math.floor(currentGas))
		if gasPercent < 0.05 then
			gasText.TextTransparency = 0.25 + 0.55 * math.abs(math.sin(os.clock() * 10))
		else
			gasText.TextTransparency = 0
		end
	end

	if gasPanicStroke then
		if gasPercent < 0.05 then
			gasPanicStroke.Color = Color3.fromRGB(255, 45, 45)
			gasPanicStroke.Thickness = 3.2 + 1.8 * math.abs(math.sin(os.clock() * 11))
			gasPanicStroke.Transparency = 0.05 + 0.2 * math.abs(math.sin(os.clock() * 11))
		elseif gasPercent < 0.10 then
			gasPanicStroke.Color = Color3.fromRGB(255, 70, 70)
			gasPanicStroke.Thickness = 2.8 + 1.2 * math.abs(math.sin(os.clock() * 8))
			gasPanicStroke.Transparency = 0.1 + 0.15 * math.abs(math.sin(os.clock() * 8))
		elseif gasPercent < 0.25 then
			gasPanicStroke.Color = Color3.fromRGB(255, 190, 70)
			gasPanicStroke.Thickness = 2.2 + 0.6 * math.abs(math.sin(os.clock() * 5))
			gasPanicStroke.Transparency = 0.2 + 0.25 * math.abs(math.sin(os.clock() * 5))
		else
			gasPanicStroke.Transparency = 1
		end
	end

	if gasGoldenStroke then
		if VFXFacade.isFirstRunOfDay() then
			local pulse = 0.85 + 0.15 * math.sin(os.clock() * 3.5)
			gasGoldenStroke.Color = Color3.fromRGB(255, 215, 60):Lerp(Color3.fromRGB(255, 240, 160), 0.5 + 0.5 * math.sin(os.clock() * 2))
			gasGoldenStroke.Thickness = 2.5 + 1.0 * pulse
			gasGoldenStroke.Transparency = 0.05 + 0.1 * (1 - pulse)
		else
			gasGoldenStroke.Transparency = 1
		end
	end

	if speedText then
		speedText.Text = tostring(math.floor(currentSpeed))
		speedText.TextColor3 = speedToColor(currentSpeed)
	end

	if isVisible and DrivingController and DrivingController.popAccelCallout then
		local line = DrivingController.popAccelCallout()
		if type(line) == "string" and line ~= "" then
			table.insert(accelCalloutQueue, line)
		end
	end

	if isVisible and DrivingController then
		local tk = speedTierKeyForSpeed(currentSpeed)
		if lastSpeedTierKey ~= nil and tk ~= lastSpeedTierKey then
			local newO = TIER_ORDER[tk] or 0
			local oldO = TIER_ORDER[lastSpeedTierKey] or 0
			if newO > oldO then
				local pool = SpeedTierCopyConfig.TierNames[tk]
				if pool and #pool > 0 then
					table.insert(tierNameFlashQueue, pool[math.random(1, #pool)])
				end
			end
		end
		lastSpeedTierKey = tk
	end

	if speedUIScale then
		if currentSpeed >= 300 then
			speedUIScale.Scale = 1.0 + 0.08 * (0.5 + 0.5 * math.sin(os.clock() * 6))
		else
			speedUIScale.Scale = 1.0
		end
	end

	if isVisible and drivingUI and drivingUI.Visible then
		local nextTh: number? = nil
		for _, th in SpeedMilestoneConfig.Thresholds do
			if currentSpeed < th then
				nextTh = th
				break
			end
		end
		if nextTh and currentSpeed >= nextTh * 0.9 then
			local now = os.clock()
			local th = nextTh :: number
			if now - lastAlmostSpeedToastClock >= ALMOST_SPEED_TOAST_COOLDOWN_SEC or lastAlmostSpeedToastThreshold ~= th then
				lastAlmostSpeedToastClock = now
				lastAlmostSpeedToastThreshold = th
				local pct = math.floor(math.clamp((currentSpeed / th) * 100, 0, 100))
				local tpl = SocialFeedConfig.pickLine("AlmostNextTier")
				local line = tpl:gsub("{PERCENT}", tostring(pct)):gsub("{TARGET}", `{th} studs/s`)
				VFXFacade.milestonePopup(line, "almost_there")
			end
		end
	end

	if powerText then
		powerText.Text = tostring(math.floor(currentPower))
	end

	if travelLabel then
		local miles = currentDistance / 5280
		travelLabel.Text = string.format("%.1f Miles Driven", miles)
	end
	if lapsLabel then
		lapsLabel.Text = tostring(currentLaps) .. " Laps Driven"
	end

	if recordFrame and currentDistance > bestDistance then
		recordFrame.Visible = true
	end

	if not hudMilestoneFlashBusy and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.popHudMilestoneFlash then
			local th = DrivingController.popHudMilestoneFlash()
			if type(th) == "number" then
				hudMilestoneFlashBusy = true
				SoundFacade.playOneShot("milestone")
				local heads = SpeedMilestoneConfig.CelebrationText[th]
				local flavors = SpeedMilestoneConfig.FlavorText[th]
				local headline = if heads and #heads > 0 then heads[math.random(1, #heads)] else `SPEED {th}!`
				local flavor = if flavors and #flavors > 0 then flavors[math.random(1, #flavors)] else ""
				local col = milestoneCelebrationColor(th)
				local lbl = Instance.new("TextLabel")
				lbl.Name = "SpeedMilestoneFlash"
				lbl.BackgroundTransparency = 1
				lbl.Size = UDim2.new(0.9, 0, 0, 72)
				lbl.AnchorPoint = Vector2.new(0.5, 0.5)
				lbl.Position = UDim2.new(0.5, 0, 0.22, 0)
				lbl.Font = Enum.Font.GothamBlack
				lbl.TextSize = 32
				lbl.TextColor3 = col
				lbl.TextStrokeTransparency = 0.45
				lbl.TextStrokeColor3 = col:Lerp(Color3.new(0, 0, 0), 0.65)
				lbl.TextWrapped = true
				lbl.Text = if flavor ~= "" then headline .. "\n" .. flavor else headline
				lbl.ZIndex = 20
				lbl.Parent = drivingUI
				local sc = Instance.new("UIScale")
				sc.Scale = 0.35
				sc.Parent = lbl
				TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
				local flexLine = SpeedMilestoneConfig.FlexText[th]
				if type(flexLine) == "string" and flexLine ~= "" then
					task.delay(1.0, function()
						if not drivingUI or not drivingUI.Parent then
							return
						end
						local fl = Instance.new("TextLabel")
						fl.Name = "SpeedMilestoneFlex"
						fl.BackgroundTransparency = 1
						fl.Size = UDim2.new(0.88, 0, 0, 36)
						fl.AnchorPoint = Vector2.new(0.5, 0.5)
						fl.Position = UDim2.new(0.5, 0, 0.31, 10)
						fl.Font = Enum.Font.GothamBold
						fl.TextSize = 17
						fl.TextColor3 = Color3.fromRGB(235, 225, 255)
						fl.TextStrokeTransparency = 0.55
						fl.TextStrokeColor3 = Color3.fromRGB(30, 15, 40)
						fl.TextWrapped = true
						fl.RichText = true
						fl.Text = "<i>" .. flexLine .. "</i>"
						fl.TextTransparency = 1
						fl.ZIndex = 19
						fl.Parent = drivingUI
						TweenService:Create(fl, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextTransparency = 0,
							Position = UDim2.new(0.5, 0, 0.31, 0),
						}):Play()
						task.delay(1.6, function()
							if fl.Parent then
								TweenService:Create(fl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									TextTransparency = 1,
									TextStrokeTransparency = 1,
								}):Play()
							end
						end)
						task.delay(1.95, function()
							if fl.Parent then
								fl:Destroy()
							end
						end)
					end)
				end
				task.delay(0.22, function()
					if lbl.Parent then
						TweenService:Create(lbl, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextTransparency = 1,
							TextStrokeTransparency = 1,
						}):Play()
					end
				end)
				task.delay(0.52, function()
					hudMilestoneFlashBusy = false
					if lbl.Parent then
						lbl:Destroy()
					end
				end)
			end
		end
	end

	if not hudNearMissFlashBusy and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.popHudNearMissFlash then
			local nm = DrivingController.popHudNearMissFlash()
			if type(nm) == "string" and nm ~= "" then
				hudNearMissFlashBusy = true
				SoundFacade.playOneShot("near_miss")
				local lbl = Instance.new("TextLabel")
				lbl.Name = "NearMissHudFlash"
				lbl.BackgroundTransparency = 1
				lbl.Size = UDim2.new(0.88, 0, 0, 40)
				lbl.AnchorPoint = Vector2.new(0.5, 0.5)
				lbl.Position = UDim2.new(0.5, 0, 0.78, 0)
				lbl.Font = Enum.Font.GothamBold
				lbl.TextSize = 22
				lbl.TextColor3 = Color3.fromRGB(255, 245, 200)
				lbl.TextStrokeTransparency = 0.35
				lbl.TextStrokeColor3 = Color3.fromRGB(40, 20, 80)
				lbl.Text = nm
				lbl.ZIndex = 19
				lbl.Parent = drivingUI
				local sc = Instance.new("UIScale")
				sc.Scale = 0.3
				sc.Parent = lbl
				TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				task.delay(0.6, function()
					if lbl.Parent then
						TweenService:Create(lbl, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextTransparency = 1,
							TextStrokeTransparency = 1,
						}):Play()
					end
				end)
				task.delay(0.95, function()
					hudNearMissFlashBusy = false
					if lbl.Parent then
						lbl:Destroy()
					end
				end)
			end
		end
	end

	if not hudComboCelebrationBusy and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.popHudComboCelebration then
			local pack = DrivingController.popHudComboCelebration()
			if type(pack) == "table" and type((pack :: any).headline) == "string" then
				local headline = (pack :: any).headline
				local body = if type((pack :: any).body) == "string" then (pack :: any).body else ""
				local comboCount = if type((pack :: any).comboCount) == "number" then (pack :: any).comboCount else 2
				if headline ~= "" then
					hudComboCelebrationBusy = true
					local pitch = math.clamp(1 + 0.04 * math.max(0, comboCount - 2), 0.88, 1.38)
					SoundFacade.playOneShot("combo", pitch)
					local holder = Instance.new("Frame")
					holder.Name = "ComboCelebrationFlash"
					holder.BackgroundTransparency = 1
					holder.Size = UDim2.new(0.88, 0, 0, 72)
					holder.AnchorPoint = Vector2.new(0.5, 0.5)
					holder.Position = UDim2.new(0.5, 0, 0.35, 0)
					holder.ZIndex = 21
					holder.Parent = drivingUI
					local hl = Instance.new("TextLabel")
					hl.BackgroundTransparency = 1
					hl.Size = UDim2.new(1, 0, 0, body ~= "" and 36 or 44)
					hl.Position = UDim2.new(0, 0, 0, 0)
					hl.Font = Enum.Font.GothamBlack
					hl.TextSize = 26
					hl.TextColor3 = Color3.fromRGB(255, 220, 100)
					hl.TextStrokeTransparency = 0.4
					hl.TextStrokeColor3 = Color3.fromRGB(60, 30, 0)
					hl.TextWrapped = true
					hl.Text = headline
					hl.Parent = holder
					if body ~= "" then
						local bl = Instance.new("TextLabel")
						bl.BackgroundTransparency = 1
						bl.Size = UDim2.new(1, 0, 0, 32)
						bl.Position = UDim2.new(0, 0, 0, 38)
						bl.Font = Enum.Font.Gotham
						bl.TextSize = 15
						bl.TextColor3 = Color3.fromRGB(255, 245, 220)
						bl.TextStrokeTransparency = 0.5
						bl.TextWrapped = true
						bl.Text = body
						bl.Parent = holder
					end
					local sc = Instance.new("UIScale")
					sc.Scale = 0.4
					sc.Parent = holder
					TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					task.delay(0.65, function()
						if holder.Parent then
							TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								BackgroundTransparency = 1,
							}):Play()
							for _, d in holder:GetDescendants() do
								if d:IsA("TextLabel") then
									TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
										TextTransparency = 1,
										TextStrokeTransparency = 1,
									}):Play()
								end
							end
						end
					end)
					task.delay(1.05, function()
						hudComboCelebrationBusy = false
						if holder.Parent then
							holder:Destroy()
						end
					end)
				end
			end
		end
	end

	if not hudComboBreakBusy and drivingUI and drivingUI.Visible then
		tryGetDrivingController()
		if DrivingController and DrivingController.popHudComboBreak then
			local pack = DrivingController.popHudComboBreak()
			if type(pack) == "table" and type((pack :: any).headline) == "string" then
				local headline = (pack :: any).headline
				local body = if type((pack :: any).body) == "string" then (pack :: any).body else ""
				if headline ~= "" then
					hudComboBreakBusy = true
					local holder = Instance.new("Frame")
					holder.Name = "ComboBreakFlash"
					holder.BackgroundTransparency = 1
					holder.Size = UDim2.new(0.88, 0, 0, 72)
					holder.AnchorPoint = Vector2.new(0.5, 0.5)
					holder.Position = UDim2.new(0.5, 0, 0.42, 0)
					holder.ZIndex = 21
					holder.Parent = drivingUI
					local hl = Instance.new("TextLabel")
					hl.BackgroundTransparency = 1
					hl.Size = UDim2.new(1, 0, 0, body ~= "" and 36 or 44)
					hl.Position = UDim2.new(0, 0, 0, 0)
					hl.Font = Enum.Font.GothamBlack
					hl.TextSize = 24
					hl.TextColor3 = Color3.fromRGB(255, 140, 120)
					hl.TextStrokeTransparency = 0.35
					hl.TextStrokeColor3 = Color3.fromRGB(60, 20, 10)
					hl.TextWrapped = true
					hl.Text = headline
					hl.Parent = holder
					if body ~= "" then
						local bl = Instance.new("TextLabel")
						bl.BackgroundTransparency = 1
						bl.Size = UDim2.new(1, 0, 0, 32)
						bl.Position = UDim2.new(0, 0, 0, 38)
						bl.Font = Enum.Font.Gotham
						bl.TextSize = 15
						bl.TextColor3 = Color3.fromRGB(255, 220, 200)
						bl.TextStrokeTransparency = 0.5
						bl.TextWrapped = true
						bl.Text = body
						bl.Parent = holder
					end
					local sc = Instance.new("UIScale")
					sc.Scale = 0.4
					sc.Parent = holder
					TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					task.delay(0.65, function()
						if holder.Parent then
							for _, d in holder:GetDescendants() do
								if d:IsA("TextLabel") then
									TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
										TextTransparency = 1,
										TextStrokeTransparency = 1,
									}):Play()
								end
							end
						end
					end)
					task.delay(1.05, function()
						hudComboBreakBusy = false
						if holder.Parent then
							holder:Destroy()
						end
					end)
				end
			end
		end
	end

	if not hudTierNameFlashBusy and drivingUI and drivingUI.Visible and #tierNameFlashQueue > 0 then
		local tierLine = table.remove(tierNameFlashQueue, 1)
		if tierLine ~= "" then
			hudTierNameFlashBusy = true
			SoundFacade.playOneShot("speed_tier")
			local lbl = Instance.new("TextLabel")
			lbl.Name = "SpeedTierNameFlash"
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(0.95, 0, 0, 36)
			lbl.AnchorPoint = Vector2.new(0.5, 0.5)
			lbl.Position = UDim2.new(0.5, 0, 0.12, 0)
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextSize = 28
			lbl.TextColor3 = Color3.fromRGB(120, 220, 255)
			lbl.TextStrokeTransparency = 0.35
			lbl.TextStrokeColor3 = Color3.fromRGB(20, 40, 80)
			lbl.Text = tierLine
			lbl.ZIndex = 18
			lbl.Parent = drivingUI
			local sc = Instance.new("UIScale")
			sc.Scale = 0.5
			sc.Parent = lbl
			TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
			task.delay(0.55, function()
				if lbl.Parent then
					TweenService:Create(lbl, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextTransparency = 1,
						TextStrokeTransparency = 1,
					}):Play()
				end
			end)
			task.delay(0.95, function()
				hudTierNameFlashBusy = false
				if lbl.Parent then
					lbl:Destroy()
				end
			end)
		end
	end

	if not hudAccelCalloutBusy and drivingUI and drivingUI.Visible and #accelCalloutQueue > 0 then
		local aline = table.remove(accelCalloutQueue, 1)
		if aline ~= "" then
			hudAccelCalloutBusy = true
			local lbl = Instance.new("TextLabel")
			lbl.Name = "AccelCalloutFlash"
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(0, 200, 0, 28)
			lbl.AnchorPoint = Vector2.new(0.5, 0.5)
			lbl.Position = UDim2.new(0.5, 0, 0.62, 0)
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextSize = 20
			lbl.TextColor3 = Color3.fromRGB(255, 180, 90)
			lbl.TextStrokeTransparency = 0.4
			lbl.TextStrokeColor3 = Color3.fromRGB(40, 20, 0)
			lbl.Text = aline
			lbl.ZIndex = 17
			lbl.Parent = drivingUI
			local sc = Instance.new("UIScale")
			sc.Scale = 1
			sc.Parent = lbl
			TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.3 }):Play()
			task.delay(0.2, function()
				if sc.Parent then
					TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end)
			task.delay(0.5, function()
				if lbl.Parent then
					TweenService:Create(lbl, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextTransparency = 1,
						TextStrokeTransparency = 1,
					}):Play()
				end
			end)
			task.delay(0.92, function()
				hudAccelCalloutBusy = false
				if lbl.Parent then
					lbl:Destroy()
				end
			end)
		end
	end
end

function DrivingHUD.init()
	local screenGui = playerGui:WaitForChild("DACMain") :: ScreenGui
	local pInfo = screenGui:WaitForChild("PlayerInfo") :: Frame
	drivingUI = pInfo:WaitForChild("DrivingUI") :: Frame
	drivingUI.Visible = false

	local gasFrame = drivingUI:FindFirstChild("Gas")
	if gasFrame then
		gasBar = gasFrame:FindFirstChild("Bar") :: ImageLabel
		gasBackground = gasFrame:FindFirstChild("Background") :: ImageLabel
		local textFrame = gasFrame:FindFirstChild("Text")
		if textFrame then
			gasText = textFrame:FindFirstChild("TextLabel") :: TextLabel
		end
		local stroke = gasFrame:FindFirstChild("FuelPanicStroke") :: UIStroke?
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "FuelPanicStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Thickness = 2
			stroke.Transparency = 1
			stroke.Parent = gasFrame
		end
		gasPanicStroke = stroke

		local goldenStroke = gasFrame:FindFirstChild("GoldenGlowStroke") :: UIStroke?
		if not goldenStroke then
			goldenStroke = Instance.new("UIStroke")
			goldenStroke.Name = "GoldenGlowStroke"
			goldenStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			goldenStroke.LineJoinMode = Enum.LineJoinMode.Round
			goldenStroke.Color = Color3.fromRGB(255, 215, 60)
			goldenStroke.Thickness = 3
			goldenStroke.Transparency = 1
			goldenStroke.Parent = gasFrame
		end
		gasGoldenStroke = goldenStroke
	end

	local speedFrame = drivingUI:FindFirstChild("Speed")
	if speedFrame and speedFrame:IsA("Frame") then
		speedText = speedFrame:FindFirstChild("TextLabel") :: TextLabel
		local sc = speedFrame:FindFirstChildOfClass("UIScale")
		if not sc then
			sc = Instance.new("UIScale")
			sc.Scale = 1
			sc.Parent = speedFrame
		end
		speedUIScale = sc
	end

	local powerFrame = drivingUI:FindFirstChild("Power")
	if powerFrame then
		local pt = powerFrame:FindFirstChild("Text")
		if pt then
			powerText = pt:FindFirstChild("TextLabel") :: TextLabel
		end
	end

	travelFrame = drivingUI:FindFirstChild("Travel") :: ImageLabel
	if travelFrame then
		travelFrame.Visible = false
		travelLabel = travelFrame:FindFirstChild("Travel") :: TextLabel
		lapsLabel = travelFrame:FindFirstChild("Laps") :: TextLabel
		local rec = travelFrame:FindFirstChild("Record")
		if rec then
			recordFrame = rec
			rec.Visible = false
		end
	end

	tryGetDrivingController()

	RunService.RenderStepped:Connect(render)

	Remotes.getEvent("StartRun").OnClientEvent:Connect(function(runInfo)
		tryGetDrivingController()
		DrivingHUD.show(runInfo.stats)
	end)

	Remotes.getEvent("EndRun").OnClientEvent:Connect(function()
		if currentDistance > bestDistance then
			bestDistance = currentDistance
		end
		DrivingHUD.hide()
	end)

	print("[DAC] DrivingHUD initialized (using DACMain.DrivingUI)")
end

return DrivingHUD
