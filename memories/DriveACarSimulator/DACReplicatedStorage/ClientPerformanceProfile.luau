--!strict
--[[
	Client-side graphics / motion preferences (POLA-334).
	Synced from persisted player settings via DataUpdate; mirrors to Player attributes
	for quick inspection/debug and optional tooling.

	POLA-501: Heartbeat-based smoothed FPS with hysteresis. When smoothed FPS stays
	below COSMETIC_THROTTLE_FPS_ENTER (default 28), idle cosmetic UI motion throttles;
	releases above COSMETIC_THROTTLE_FPS_EXIT (default 32). See isCosmeticUiMotionThrottled().
]]

local RunService = game:GetService("RunService")

local ClientPerformanceProfile = {}

-- Defaults (documented for tuning / Studio inspection)
local COSMETIC_THROTTLE_FPS_ENTER = 28
local COSMETIC_THROTTLE_FPS_EXIT = 32
local FPS_EMA_ALPHA = 0.12
local MIN_FRAMES_BEFORE_THROTTLE = 48

local fpsTrackingStarted = false
local frameIndex = 0
local smoothedFps = 60.0
local throttleCosmeticMotion = false
local localPlayerForAttr: Player? = nil

local ATTR_COSMETIC_THROTTLE = "DAC_CosmeticUiThrottled"

local particlesOn = true
local particleDensity = 2 -- 0 = minimal, 1 = medium, 2 = full (extra cap on top of adaptive LOD)
local reducedMotion = false
local showFps = false
-- 0 = low, 1 = medium, 2 = high (matches SettingsService / DataManager)
local graphicsQuality = 1

local ATTR_PARTICLES = "DAC_Settings_Particles"
local ATTR_DENSITY = "DAC_Settings_ParticleDensity"
local ATTR_REDUCED = "DAC_Settings_ReducedMotion"
local ATTR_FPS = "DAC_Settings_ShowFps"
local ATTR_GRAPHICS_Q = "DAC_Settings_GraphicsQuality"

function ClientPerformanceProfile.startFpsTracking(player: Player)
	if fpsTrackingStarted then
		return
	end
	fpsTrackingStarted = true
	localPlayerForAttr = player
	player:SetAttribute(ATTR_COSMETIC_THROTTLE, false)
	RunService.Heartbeat:Connect(function(dt: number)
		frameIndex += 1
		local inst = 1 / math.max(dt, 1e-4)
		if frameIndex == 1 then
			smoothedFps = inst
		else
			smoothedFps = smoothedFps * (1 - FPS_EMA_ALPHA) + inst * FPS_EMA_ALPHA
		end
		if frameIndex < MIN_FRAMES_BEFORE_THROTTLE then
			return
		end
		local nextThrottle = throttleCosmeticMotion
		if not throttleCosmeticMotion and smoothedFps <= COSMETIC_THROTTLE_FPS_ENTER then
			nextThrottle = true
		elseif throttleCosmeticMotion and smoothedFps >= COSMETIC_THROTTLE_FPS_EXIT then
			nextThrottle = false
		end
		if nextThrottle ~= throttleCosmeticMotion then
			throttleCosmeticMotion = nextThrottle
			if localPlayerForAttr then
				localPlayerForAttr:SetAttribute(ATTR_COSMETIC_THROTTLE, throttleCosmeticMotion)
			end
		end
	end)
end

--[[
	Smoothed instantaneous FPS (exponential moving average on Heartbeat deltas).
]]
function ClientPerformanceProfile.getSmoothedFps(): number
	return smoothedFps
end

--[[
	True when sustained low FPS should drop idle MenuHub / egg-shop cosmetic tweens (POLA-501).
	Independent of graphics tier — catches thermal throttling on high quality preset.
]]
function ClientPerformanceProfile.isCosmeticUiMotionThrottled(): boolean
	return throttleCosmeticMotion
end

function ClientPerformanceProfile.getCosmeticThrottleFpsThresholds(): (number, number)
	return COSMETIC_THROTTLE_FPS_ENTER, COSMETIC_THROTTLE_FPS_EXIT
end

function ClientPerformanceProfile.syncFromSettings(settings: any?)
	if type(settings) ~= "table" then
		return
	end
	if type(settings.particles) == "boolean" then
		particlesOn = settings.particles
	end
	if type(settings.particleDensity) == "number" then
		particleDensity = math.clamp(math.floor(settings.particleDensity), 0, 2)
	end
	if type(settings.reducedMotion) == "boolean" then
		reducedMotion = settings.reducedMotion
	end
	if type(settings.showFps) == "boolean" then
		showFps = settings.showFps
	end
	if type(settings.graphicsQuality) == "number" then
		graphicsQuality = math.clamp(math.floor(settings.graphicsQuality), 0, 2)
	end
end

function ClientPerformanceProfile.applyAttributes(player: Player)
	player:SetAttribute(ATTR_PARTICLES, particlesOn)
	player:SetAttribute(ATTR_DENSITY, particleDensity)
	player:SetAttribute(ATTR_REDUCED, reducedMotion)
	player:SetAttribute(ATTR_FPS, showFps)
	player:SetAttribute(ATTR_GRAPHICS_Q, graphicsQuality)
	player:SetAttribute(ATTR_COSMETIC_THROTTLE, throttleCosmeticMotion)
end

function ClientPerformanceProfile.userMaxVfxLod(): number
	if not particlesOn then
		return 1
	end
	return math.clamp(1 + particleDensity, 1, 3)
end

function ClientPerformanceProfile.isReducedMotion(): boolean
	return reducedMotion
end

function ClientPerformanceProfile.shouldShowFps(): boolean
	return showFps
end

function ClientPerformanceProfile.particlesEnabled(): boolean
	return particlesOn
end

function ClientPerformanceProfile.getGraphicsQuality(): number
	return graphicsQuality
end

-- Lowest quality preset (POLA-334): disable extra motion / FOV juice.
function ClientPerformanceProfile.isLowGraphicsTier(): boolean
	return graphicsQuality <= 0
end

--[[
	POLA-481: Weighted UI / HUD tween strength (0 = off).
	Low (0): no economy or panel punch juice. Medium (1): softer pops. High (2): full.
	Respects reduced motion, particles off, and graphics tier together.
]]
function ClientPerformanceProfile.uiJuiceStrength(): number
	if reducedMotion then
		return 0
	end
	if not particlesOn then
		return 0
	end
	if graphicsQuality <= 0 then
		return 0
	end
	if graphicsQuality == 1 then
		return 0.5
	end
	return 1
end

--[[
	Infinite tweens, per-frame sin pulses, and RenderStepped screen shimmers (banners, travel pulse).
	Requires high graphics, particles on, and reduced motion off.
]]
function ClientPerformanceProfile.allowsContinuousScreenMotion(): boolean
	if reducedMotion then
		return false
	end
	if not particlesOn then
		return false
	end
	if graphicsQuality < 2 then
		return false
	end
	return true
end

return ClientPerformanceProfile
