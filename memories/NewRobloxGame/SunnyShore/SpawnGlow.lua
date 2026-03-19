--[[
	SpawnGlow.lua — Place inside TidePool_1_Starter model
	Pulses the glow disc to draw the player's attention during onboarding.
	Disables itself after the player's first discovery.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local glowDisc = script.Parent:FindFirstChild("GlowDisc")
if not glowDisc then
	warn("SpawnGlow: no GlowDisc found in parent model")
	return
end

local light = glowDisc:FindFirstChildOfClass("PointLight")

local PULSE_MIN_TRANSPARENCY = 0.3
local PULSE_MAX_TRANSPARENCY = 0.7
local PULSE_DURATION = 1.2
local LIGHT_MIN_BRIGHTNESS = 1.5
local LIGHT_MAX_BRIGHTNESS = 3

local tweenInfo = TweenInfo.new(PULSE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local glowTween = TweenService:Create(glowDisc, tweenInfo, {
	Transparency = PULSE_MAX_TRANSPARENCY,
})

if light then
	local lightTween = TweenService:Create(light, tweenInfo, {
		Brightness = LIGHT_MIN_BRIGHTNESS,
	})
	light.Brightness = LIGHT_MAX_BRIGHTNESS
	lightTween:Play()
end

glowDisc.Transparency = PULSE_MIN_TRANSPARENCY
glowTween:Play()

-- Stop pulsing after the player discovers something from this pool
local resultEvent = ReplicatedStorage:WaitForChild("TidePoolResult", 30)
if resultEvent then
	resultEvent.OnClientEvent:Connect(function(data)
		if data.success and data.poolId == "TidePool_1_Starter" then
			glowTween:Cancel()
			local fadeOut = TweenService:Create(glowDisc, TweenInfo.new(1), {
				Transparency = 0.9,
			})
			fadeOut:Play()
			if light then
				local lightFade = TweenService:Create(light, TweenInfo.new(1), {
					Brightness = 0.5,
				})
				lightFade:Play()
			end
		end
	end)
end
