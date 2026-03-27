--!strict
--[[
	Top HUD banner during Founder's Bonus launch window with countdown to window end.
	UI is pre-built in StarterGui.DACEventBanner; this script only wires behavior.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local UILayerStack = require(DAC:WaitForChild("Config"):WaitForChild("UILayerStack"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))
local HudSafeArea = require(DAC:WaitForChild("HudSafeArea"))
local HudLayoutConfig = require(DAC:WaitForChild("Config"):WaitForChild("HudLayoutConfig"))
local ClientPerformanceProfile = require(DAC:WaitForChild("ClientPerformanceProfile"))

local EventBanner = {}

-- Tunable urgency (seconds remaining). Visual + SFX tier when crossing downward.
local URGENCY_SEC_1H = 3600
local URGENCY_SEC_10M = 600
local URGENCY_SEC_5M = 300
local SHIMMER_SPEED_CALM = 1.8
local SHIMMER_SPEED_WARN = 3.35
local EVENT_COUNTDOWN_TICK_SFX = "event_countdown_tick"
local ICON_BOUNCE_SCALE = 1.06
local ICON_BOUNCE_TIME = 0.14

local hasPlayedFanfare = false
local lastCountdownSec: number? = nil
local isSliding = false
local shimmerConnection: RBXScriptConnection? = nil
local urgentPulseConnection: RBXScriptConnection? = nil
local lastUrgentLine: string? = nil
local currentUrgencyVisual: string = ""
local prevLeftForThresholdSfx: number? = nil
local iconBounceScale: UIScale? = nil

local function formatCountdown(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	local sec = s % 60
	return string.format("%02d:%02d:%02d", h, m, sec)
end

function EventBanner.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("DACEventBanner") :: ScreenGui
	gui.DisplayOrder = UILayerStack.screenGui.hudEventBanner
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		SoundFacade.setModalOverlayOpen(gui.Enabled)
	end)
	if gui.Enabled then
		SoundFacade.setModalOverlayOpen(true)
	end
	local bar = gui:WaitForChild("Bar") :: Frame
	local stroke = bar:WaitForChild("Stroke") :: UIStroke
	local label = bar:WaitForChild("Headline") :: TextLabel
	local subLabel = bar:WaitForChild("Sub") :: TextLabel

	local endsAtUnix: number? = nil
	-- serverTimeUnix from LaunchEventState minus client os.time() at receive; keeps countdown aligned if device clock is skewed
	local timeOffsetSeconds = 0
	local headlineLine: string = MicrocopyConfig.FounderEventBannerHeadlines[1]
	local function restPos(): UDim2
		local _, topInset = HudSafeArea.getManualInsetForScreenGui(gui)
		return UDim2.new(0.5, 0, 0, HudLayoutConfig.eventBannerTopPadPx + topInset)
	end
	local function offscreenPos(): UDim2
		local _, topInset = HudSafeArea.getManualInsetForScreenGui(gui)
		return UDim2.new(0.5, 0, 0, -60 + topInset)
	end

	local function layoutBar()
		local vw = HudSafeArea.getViewportWidth()
		local insetLeft, insetTop = HudSafeArea.getManualInsetForScreenGui(gui)
		local maxW = math.min(HudLayoutConfig.eventBannerMaxWidthPx, vw - insetLeft - 2 * HudLayoutConfig.edgeMarginPx)
		bar.Position = UDim2.new(0.5, 0, 0, HudLayoutConfig.eventBannerTopPadPx + insetTop)
		local sz = bar.Size
		bar.Size = UDim2.new(0, math.max(200, maxW), sz.Y.Scale, sz.Y.Offset)
	end

	layoutBar()
	HudSafeArea.onLayoutChanged(layoutBar)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextWrapped = false
	subLabel.TextTruncate = Enum.TextTruncate.AtEnd
	subLabel.TextWrapped = true

	local function slideIn()
		if isSliding then return end
		isSliding = true
		layoutBar()
		bar.Position = offscreenPos()
		local tween = TweenService:Create(bar, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = restPos() })
		tween:Play()
		tween.Completed:Once(function()
			isSliding = false
		end)
	end

	local function slideOut()
		if isSliding then return end
		isSliding = true
		local flash = Instance.new("Frame")
		flash.Size = UDim2.new(1, 0, 1, 0)
		flash.BackgroundColor3 = Color3.fromRGB(255, 230, 140)
		flash.BackgroundTransparency = 0.3
		flash.BorderSizePixel = 0
		flash.ZIndex = 10
		flash.Parent = bar
		TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		task.delay(0.15, function()
			local outTween = TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = offscreenPos() })
			outTween:Play()
			outTween.Completed:Wait()
			gui.Enabled = false
			isSliding = false
			flash:Destroy()
		end)
	end

	local shimmerPhase = 0
	local barGradient = bar:FindFirstChildOfClass("UIGradient") :: UIGradient?
	local iconFrame = bar:FindFirstChild("Icon") :: GuiObject?

	local function stopShimmer()
		if shimmerConnection then shimmerConnection:Disconnect(); shimmerConnection = nil end
		stroke.Color = Color3.fromRGB(255, 200, 80)
		stroke.Thickness = 2
		if barGradient then
			barGradient.Rotation = 0
		end
	end

	local function stopUrgentPulse()
		if urgentPulseConnection then urgentPulseConnection:Disconnect(); urgentPulseConnection = nil end
		stroke.Color = Color3.fromRGB(255, 200, 80)
		stroke.Thickness = 2
	end

	local function applyStaticUrgency(kind: string)
		stopShimmer()
		stopUrgentPulse()
		if kind == "calm" then
			stroke.Color = Color3.fromRGB(255, 200, 80)
			stroke.Thickness = 2
			if barGradient then
				barGradient.Rotation = 0
			end
		elseif kind == "warn" then
			stroke.Color = Color3.fromRGB(255, 150, 55)
			stroke.Thickness = 2.4
			if barGradient then
				barGradient.Rotation = 0
			end
		elseif kind == "pulse10" then
			stroke.Color = Color3.fromRGB(235, 55, 45)
			stroke.Thickness = 3
			if barGradient then
				barGradient.Rotation = 0
			end
		else
			stroke.Color = Color3.fromRGB(230, 40, 35)
			stroke.Thickness = 3.4
			if barGradient then
				barGradient.Rotation = 0
			end
		end
	end

	local function startShimmer(speed: number, warnTint: boolean)
		if shimmerConnection then shimmerConnection:Disconnect(); shimmerConnection = nil end
		shimmerPhase = 0
		shimmerConnection = RunService.RenderStepped:Connect(function(dt)
			shimmerPhase += dt * speed
			local t = (math.sin(shimmerPhase) + 1) / 2
			if warnTint then
				stroke.Color = Color3.fromRGB(255, 160 + math.floor(t * 70), 50 + math.floor(t * 90))
				stroke.Thickness = 2.2 + t * 1.8
				if barGradient then
					barGradient.Rotation = math.sin(shimmerPhase * 0.6) * 6
				end
			else
				stroke.Color = Color3.fromRGB(255, 200 + math.floor(t * 55), 80 + math.floor(t * 100))
				stroke.Thickness = 2 + t * 1.2
			end
		end)
	end

	local function startUrgentPulse(phaseHz: number, thicknessAmp: number)
		if urgentPulseConnection then urgentPulseConnection:Disconnect(); urgentPulseConnection = nil end
		local t0 = os.clock()
		urgentPulseConnection = RunService.RenderStepped:Connect(function()
			local phase = (os.clock() - t0) * phaseHz
			local w = (math.sin(phase) + 1) * 0.5
			stroke.Color = Color3.fromRGB(220 + math.floor(35 * w), 40 + math.floor(40 * (1 - w)), 40)
			stroke.Thickness = 2.2 + w * thicknessAmp
			if barGradient then
				barGradient.Rotation = math.sin(phase * 0.35) * (4 + thicknessAmp * 0.4)
			end
		end)
	end

	local function playThresholdCrossSfx(prevLeft: number, left: number)
		if left <= 0 or prevLeft <= 0 then
			return
		end
		if prevLeft >= URGENCY_SEC_1H and left < URGENCY_SEC_1H then
			SoundFacade.playOneShot(EVENT_COUNTDOWN_TICK_SFX, 0.92)
		elseif prevLeft >= URGENCY_SEC_10M and left < URGENCY_SEC_10M then
			SoundFacade.playOneShot(EVENT_COUNTDOWN_TICK_SFX, 1)
		elseif prevLeft >= URGENCY_SEC_5M and left < URGENCY_SEC_5M then
			SoundFacade.playOneShot(EVENT_COUNTDOWN_TICK_SFX, 1.08)
		end
	end

	local function maybeBounceIcon()
		local target: GuiObject = iconFrame or bar
		local scale = iconBounceScale
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "UrgencyBounceScale"
			scale.Scale = 1
			scale.Parent = target
			iconBounceScale = scale
		end
		TweenService:Create(scale, TweenInfo.new(ICON_BOUNCE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = ICON_BOUNCE_SCALE }):Play()
		task.delay(ICON_BOUNCE_TIME, function()
			if scale.Parent then
				TweenService:Create(scale, TweenInfo.new(ICON_BOUNCE_TIME * 1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = 1 }):Play()
			end
		end)
	end

	local function applyUrgencyVisual(kind: string)
		if currentUrgencyVisual == kind then
			return
		end
		currentUrgencyVisual = kind
		if not ClientPerformanceProfile.allowsContinuousScreenMotion() then
			applyStaticUrgency(kind)
			return
		end
		stopShimmer()
		stopUrgentPulse()
		if kind == "calm" then
			startShimmer(SHIMMER_SPEED_CALM, false)
		elseif kind == "warn" then
			startShimmer(SHIMMER_SPEED_WARN, true)
		elseif kind == "pulse10" then
			startUrgentPulse(2.65, 1.85)
		else
			startUrgentPulse(4, 2.35)
		end
	end

	local function tickPulse()
		local up = TweenService:Create(label, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = 18 })
		up:Play()
		up.Completed:Wait()
		TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = 16 }):Play()
	end

	local function urgencyKind(left: number): string
		if left >= URGENCY_SEC_1H then
			return "calm"
		elseif left >= URGENCY_SEC_10M then
			return "warn"
		elseif left >= URGENCY_SEC_5M then
			return "pulse10"
		elseif left > 0 then
			return "pulse5"
		end
		return "calm"
	end

	local function syncedNow(): number
		return os.time() + timeOffsetSeconds
	end

	local function refresh()
		if not endsAtUnix then return end
		local left = endsAtUnix - syncedNow()
		local currentSec = math.max(0, math.floor(left))
		local prevForSfx = prevLeftForThresholdSfx
		if prevForSfx ~= nil and left > 0 and prevForSfx > 0 then
			playThresholdCrossSfx(prevForSfx, left)
			if prevForSfx >= URGENCY_SEC_10M and left < URGENCY_SEC_10M then
				maybeBounceIcon()
			end
		end
		prevLeftForThresholdSfx = if left > 0 then left else nil

		label.Text = headlineLine
		if left < URGENCY_SEC_1H and left > 0 then
			if lastUrgentLine == nil then
				lastUrgentLine =
					MicrocopyConfig.FounderEventCountdown[math.random(1, #MicrocopyConfig.FounderEventCountdown)]
			end
			subLabel.Text = `{lastUrgentLine}  \u{2022}  {formatCountdown(left)}`
		else
			lastUrgentLine = nil
			subLabel.Text = `Ends in {formatCountdown(left)}`
		end

		if left > 0 then
			applyUrgencyVisual(urgencyKind(left))
		end
		if lastCountdownSec ~= nil and currentSec ~= lastCountdownSec and currentSec > 0 then
			task.spawn(tickPulse)
		end
		lastCountdownSec = currentSec
		if left <= 0 then
			slideOut()
			stopShimmer()
			stopUrgentPulse()
			lastUrgentLine = nil
			currentUrgencyVisual = ""
			prevLeftForThresholdSfx = nil
		end
	end

	-- Countdown text only changes per wall second; avoid running refresh() every frame.
	local lastRefreshWallSec: number? = nil
	RunService.Heartbeat:Connect(function()
		if not gui.Enabled or not endsAtUnix then
			return
		end
		local wall = syncedNow()
		if lastRefreshWallSec == wall then
			return
		end
		lastRefreshWallSec = wall
		refresh()
	end)

	Remotes.getEvent("LaunchEventState").OnClientEvent:Connect(function(state: any)
		if type(state) ~= "table" then return end
		if type(state.serverTimeUnix) == "number" then
			timeOffsetSeconds = state.serverTimeUnix - os.time()
		end
		if state.founderActive == true and type(state.founderEndsAtUnix) == "number" then
			endsAtUnix = state.founderEndsAtUnix
			headlineLine = MicrocopyConfig.FounderEventBannerHeadlines[math.random(
				1,
				#MicrocopyConfig.FounderEventBannerHeadlines
			)]
			lastCountdownSec = nil
			lastUrgentLine = nil
			currentUrgencyVisual = ""
			prevLeftForThresholdSfx = nil
			gui.Enabled = true
			slideIn()
			if not hasPlayedFanfare then
				hasPlayedFanfare = true
				SoundFacade.playOneShot("event_fanfare")
			end
			refresh()
		else
			-- Window inactive: drop end time so Heartbeat cannot run with stale endsAtUnix.
			endsAtUnix = nil
			lastRefreshWallSec = nil
			if type(state.serverTimeUnix) == "number" then
				timeOffsetSeconds = state.serverTimeUnix - os.time()
			end
			if gui.Enabled then
				slideOut()
				stopShimmer()
				stopUrgentPulse()
				lastUrgentLine = nil
				currentUrgencyVisual = ""
				prevLeftForThresholdSfx = nil
			end
		end
	end)
end

return EventBanner
