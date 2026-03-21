--[[
	VFXConfig — Tunables for P0 VFX (tire smoke, panel sparks, windshield shatter, speed lines).

	Per-vehicle accent colors align with Bard’s color study (warm greys / amber smoke).
]]

export type VehicleVFXProfile = {
	smokeTint: Color3,
	sparkBrightness: number,
	speedLineTint: Color3,
	speedLineStartFrac: number, -- fraction of max speed where lines begin to show
}

export type TireSmokeConfig = {
	slipThreshold: number, -- lateral / forward ratio (match tire screech)
	rateMin: number,
	rateMax: number,
	sizeMin: number,
	sizeMax: number,
	lifetimeMin: number,
	lifetimeMax: number,
	transparency: number,
}

export type BurstVFXConfig = {
	countMin: number,
	countMax: number,
	speedMin: number,
	speedMax: number,
	sizeMin: number,
	sizeMax: number,
	lifetimeMin: number,
	lifetimeMax: number,
	spreadDeg: number,
}

export type SpeedLinesConfig = {
	streakCount: number,
	startSpeedFrac: number, -- 0.7 = 70% max speed
	maxOpacity: number,
	baseThicknessScale: number,
}

local VFXConfig = {}

VFXConfig.cullDistanceStuds = 100

local tireSmoke: TireSmokeConfig = {
	slipThreshold = 0.35,
	rateMin = 8,
	rateMax = 25,
	sizeMin = 1.5,
	sizeMax = 3.5,
	lifetimeMin = 0.8,
	lifetimeMax = 1.5,
	transparency = 0.8,
}
VFXConfig.tireSmoke = tireSmoke

local panelSparks: BurstVFXConfig = {
	countMin = 15,
	countMax = 25,
	speedMin = 15,
	speedMax = 30,
	sizeMin = 0.1,
	sizeMax = 0.3,
	lifetimeMin = 0.3,
	lifetimeMax = 0.6,
	spreadDeg = 120,
}
VFXConfig.panelSparks = panelSparks

local windshieldShatter: BurstVFXConfig = {
	countMin = 20,
	countMax = 30,
	speedMin = 10,
	speedMax = 35,
	sizeMin = 0.2,
	sizeMax = 0.5,
	lifetimeMin = 0.5,
	lifetimeMax = 1.0,
	spreadDeg = 90,
}
VFXConfig.windshieldShatter = windshieldShatter

local speedLines: SpeedLinesConfig = {
	streakCount = 24,
	startSpeedFrac = 0.7,
	maxOpacity = 0.45,
	baseThicknessScale = 1,
}
VFXConfig.speedLines = speedLines

VFXConfig.profiles = {
	nomad = {
		smokeTint = Color3.fromRGB(210, 200, 185),
		sparkBrightness = 1.0,
		speedLineTint = Color3.fromRGB(245, 245, 250),
		speedLineStartFrac = 0.68,
	},
	viper = {
		smokeTint = Color3.fromRGB(225, 190, 170),
		sparkBrightness = 1.05,
		speedLineTint = Color3.fromRGB(255, 240, 235),
		speedLineStartFrac = 0.65,
	},
	rhino = {
		smokeTint = Color3.fromRGB(185, 180, 175),
		sparkBrightness = 0.95,
		speedLineTint = Color3.fromRGB(230, 235, 240),
		speedLineStartFrac = 0.72,
	},
	all_rounder = {
		smokeTint = Color3.fromRGB(205, 198, 188),
		sparkBrightness = 1.0,
		speedLineTint = Color3.fromRGB(248, 248, 252),
		speedLineStartFrac = 0.7,
	},
	-- Registry ids (speedster / tank align with viper / rhino palettes)
	speedster = {
		smokeTint = Color3.fromRGB(225, 190, 170),
		sparkBrightness = 1.05,
		speedLineTint = Color3.fromRGB(255, 240, 235),
		speedLineStartFrac = 0.65,
	},
	tank = {
		smokeTint = Color3.fromRGB(185, 180, 175),
		sparkBrightness = 0.95,
		speedLineTint = Color3.fromRGB(230, 235, 240),
		speedLineStartFrac = 0.72,
	},
}

function VFXConfig.getProfile(vehicleId: string): VehicleVFXProfile
	return VFXConfig.profiles[vehicleId] or VFXConfig.profiles.all_rounder
end

return VFXConfig
