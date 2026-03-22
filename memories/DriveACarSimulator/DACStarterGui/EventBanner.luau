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
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

local EventBanner = {}

local hasPlayedFanfare = false
local lastCountdownSec: number? = nil
local isSliding = false
local shimmerConnection: RBXScriptConnection? = nil
local urgentPulseConnection: RBXScriptConnection? = nil
local lastUrgentLine: string? = nil

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
	local bar = gui:WaitForChild("Bar") :: Frame
	local stroke = bar:WaitForChild("Stroke") :: UIStroke
	local label = bar:WaitForChild("Headline") :: TextLabel
	local subLabel = bar:WaitForChild("Sub") :: TextLabel

	local endsAtUnix: number? = nil
	local headlineLine: string = "FOUNDER'S BONUS: 2x COINS!"
	local REST_POS = UDim2.new(0.5, 0, 0, 8)
	local OFFSCREEN_POS = UDim2.new(0.5, 0, 0, -60)

	local function slideIn()
		if isSliding then return end
		isSliding = true
		bar.Position = OFFSCREEN_POS
		local tween = TweenService:Create(bar, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = REST_POS })
		tween:Play()
		tween.Completed:Connect(function() isSliding = false end)
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
			local outTween = TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = OFFSCREEN_POS })
			outTween:Play()
			outTween.Completed:Wait()
			gui.Enabled = false
			isSliding = false
			flash:Destroy()
		end)
	end

	local shimmerPhase = 0
	local SHIMMER_SPEED = 1.8

	local function startShimmer()
		if shimmerConnection then return end
		shimmerPhase = 0
		shimmerConnection = RunService.RenderStepped:Connect(function(dt)
			shimmerPhase += dt * SHIMMER_SPEED
			local t = (math.sin(shimmerPhase) + 1) / 2
			stroke.Color = Color3.fromRGB(255, 200 + math.floor(t * 55), 80 + math.floor(t * 100))
			stroke.Thickness = 2 + t * 1.2
		end)
	end

	local function stopShimmer()
		if shimmerConnection then shimmerConnection:Disconnect(); shimmerConnection = nil end
		stroke.Color = Color3.fromRGB(255, 200, 80)
		stroke.Thickness = 2
	end

	local function stopUrgentPulse()
		if urgentPulseConnection then urgentPulseConnection:Disconnect(); urgentPulseConnection = nil end
		stroke.Color = Color3.fromRGB(255, 200, 80)
	end

	local function startUrgentPulse()
		if urgentPulseConnection then return end
		local t0 = os.clock()
		urgentPulseConnection = RunService.RenderStepped:Connect(function()
			local phase = (os.clock() - t0) * 4
			local w = (math.sin(phase) + 1) * 0.5
			stroke.Color = Color3.fromRGB(220 + math.floor(35 * w), 40 + math.floor(40 * (1 - w)), 40)
			stroke.Thickness = 2.2 + w * 2.2
		end)
	end

	local function tickPulse()
		local up = TweenService:Create(label, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = 18 })
		up:Play()
		up.Completed:Wait()
		TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = 16 }):Play()
	end

	local function refresh()
		if not endsAtUnix then return end
		local left = endsAtUnix - os.time()
		local currentSec = math.max(0, math.floor(left))
		label.Text = headlineLine
		if left < 3600 and left > 0 then
			if lastUrgentLine == nil then
				lastUrgentLine = MicrocopyConfig.EventCountdown[math.random(1, #MicrocopyConfig.EventCountdown)]
			end
			subLabel.Text = `{lastUrgentLine}  \u{2022}  {formatCountdown(left)}`
		else
			lastUrgentLine = nil
			subLabel.Text = `Ends in {formatCountdown(left)}`
		end
		if left < 300 and left > 0 then
			if not urgentPulseConnection then stopShimmer(); startUrgentPulse() end
		else
			if urgentPulseConnection then stopUrgentPulse() end
			startShimmer()
		end
		if lastCountdownSec ~= nil and currentSec ~= lastCountdownSec and currentSec > 0 then
			task.spawn(tickPulse)
		end
		lastCountdownSec = currentSec
		if left <= 0 then
			slideOut(); stopShimmer(); stopUrgentPulse(); lastUrgentLine = nil
		end
	end

	RunService.RenderStepped:Connect(function()
		if gui.Enabled and endsAtUnix then refresh() end
	end)

	Remotes.getEvent("LaunchEventState").OnClientEvent:Connect(function(state: any)
		if type(state) ~= "table" then return end
		if state.founderActive == true and type(state.founderEndsAtUnix) == "number" then
			endsAtUnix = state.founderEndsAtUnix
			headlineLine = MicrocopyConfig.EventBannerHeadlines[math.random(1, #MicrocopyConfig.EventBannerHeadlines)]
			lastCountdownSec = nil
			lastUrgentLine = nil
			gui.Enabled = true
			slideIn()
			startShimmer()
			if not hasPlayedFanfare then
				hasPlayedFanfare = true
				SoundFacade.playOneShot("event_fanfare")
			end
			refresh()
		else
			if gui.Enabled then
				slideOut(); stopShimmer(); stopUrgentPulse(); lastUrgentLine = nil
			end
		end
	end)
end

return EventBanner
