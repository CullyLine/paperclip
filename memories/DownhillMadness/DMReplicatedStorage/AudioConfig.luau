--[[
	AudioConfig — Tuning for Downhill Madness client audio.

	Asset IDs default to 0; replace after uploading previews from
	memories/DownhillMadness/audio/ to Roblox (see audio/AUDIO-CURATION.md).
]]

local AudioConfig = {}

export type VehicleAudioProfile = {
	-- Engine pitch range (PlaybackSpeed) at 0 speed vs full speed fraction
	enginePitchIdle: number,
	enginePitchMax: number,
	engineVolumeIdle: number,
	engineVolumeMax: number,
	-- Tire screech: "medium" | "low" (maps to asset slots in AudioManager)
	screechVariant: string,
	-- Extra pitch bias for personality (Viper higher, Rhino lower)
	enginePitchBias: number,
}

export type Spatial = {
	rolloffMode: Enum.RollOffMode,
	minDistance: number,
	maxDistance: number,
}

-- Logical keys → rbxassetid strings. 0 = not uploaded yet.
AudioConfig.AssetIds = {
	engine = {
		-- audio/engine/ESM_FG_mechanical_loop_engine_tractor_drive_1.wav.mp3 (primary)
		primary = "rbxassetid://0",
		-- audio/engine/shs_crd_44_texture_industrial_loop_Struggle_engine_motor.wav.mp3 (optional bed)
		bed = "rbxassetid://0",
	},
	crash = {
		-- Metal crunch variants (pick randomly at runtime)
		"rbxassetid://0", -- ESM_Game_Car_Crashes_Metal_Smash...
		"rbxassetid://0", -- ESM_Game_Car_Crash_Metal_Smash...
		"rbxassetid://0", -- ESM_Game_Car_Crash_2_Metal_Smash...
		"rbxassetid://0", -- SPLC-0562_FX_Oneshot_Metal_Tank_Impact
	},
	glass = "rbxassetid://0", -- ESM_Controlled_Glass_Break_Shatter_Rubble...
	tires = {
		medium = "rbxassetid://0", -- FF_CRT_sfx_car_screech_medium
		low = "rbxassetid://0", -- FF_CRT_foley_car_screech_low
	},
	wind = {
		-- Layer A: broader bed; B: turbulent / high-speed layer
		bed = "rbxassetid://0", -- wind_full_continuous_air_02
		turbulent = "rbxassetid://0", -- wind_constricted_flow_turbulent_01
	},
	ui = {
		click = "rbxassetid://0",
		hover = "rbxassetid://0",
		countdown = "rbxassetid://0",
		finish = "rbxassetid://0",
	},
}

AudioConfig.Spatial = {
	rolloffMode = Enum.RollOffMode.InverseTapered,
	minDistance = 8,
	maxDistance = 120,
} :: Spatial

-- Lateral |v·right| / |v·forward| style fraction above this → screech ramps in
AudioConfig.ScreechLateralThreshold = 0.35
AudioConfig.ScreechFadeIn = 8
AudioConfig.ScreechFadeOut = 14

-- Wind starts past this fraction of effective max speed
AudioConfig.WindSpeedStartFraction = 0.4
AudioConfig.WindPitchMin = 0.85
AudioConfig.WindPitchMax = 1.25

-- Crash one-shots: min gap between plays (seconds)
AudioConfig.CrashCooldown = 0.12
-- playImpact severity expected around impactSpeed / damageSpeedThreshold
AudioConfig.CrashSeverityClamp = { min = 0.2, max = 1.5 }

local PROFILES: { [string]: VehicleAudioProfile } = {
	all_rounder = {
		enginePitchIdle = 0.72,
		enginePitchMax = 1.45,
		engineVolumeIdle = 0.08,
		engineVolumeMax = 0.55,
		screechVariant = "medium",
		enginePitchBias = 0,
	},
	speedster = {
		enginePitchIdle = 0.88,
		enginePitchMax = 1.78,
		engineVolumeIdle = 0.1,
		engineVolumeMax = 0.58,
		screechVariant = "medium",
		enginePitchBias = 0.06,
	},
	tank = {
		enginePitchIdle = 0.52,
		enginePitchMax = 1.18,
		engineVolumeIdle = 0.12,
		engineVolumeMax = 0.62,
		screechVariant = "low",
		enginePitchBias = -0.08,
	},
}

function AudioConfig.getProfile(vehicleId: string): VehicleAudioProfile
	return PROFILES[vehicleId] or PROFILES.all_rounder
end

return AudioConfig
