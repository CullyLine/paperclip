--!strict
--[[
	HATCH CRACK VISUAL SPEC — Engineer-Consumable Config
	=====================================================
	Per-rarity egg hatch crack phase definitions. Each entry contains all
	parameters needed to drive the wobble → crack → break → burst sequence
	in VFXController.hatchReveal().

	Intended consumer: VFXController.hatchReveal() / EggService hatch flow.

	Cross-references:
	  - RebirthHatchDesignSpec.luau Section B  (narrative rationale)
	  - PetEntranceDesignSpec.luau            (rarity color constants)
	  - VFXController.luau                    (lodBurstMul, cameraShake)
	  - SoundFacade.luau                      (sound cue IDs)
]]

export type WobblePhase = {
	durationSec: number,
	frequencyHz: number,
	frequencyHzEnd: number?,
	maxAmplitudeDeg: number,
	maxAmplitudeDegEnd: number?,
	rampCurve: string,
	rampExponent: number?,
	jitterAfterSec: number?,
	jitterPx: number?,
}

export type CrackLine = {
	spawnTimeSec: number,
	sizeScale: UDim2,
	position: UDim2,
	rotationDeg: number,
	thicknessPx: number,
	fadeFrom: number,
	fadeTo: number,
	fadeDurationSec: number,
}

export type CrackStyle = {
	lineCount: number,
	color: Color3,
	lines: { CrackLine }?,
	glowPulseHz: number?,
	isRainbow: boolean?,
}

export type ShellShard = {
	count: number,
	sizePxMin: number,
	sizePxMax: number,
	hasTrail: boolean,
	trailColor: Color3?,
}

export type ScreenEffect = {
	vignetteDarkenTo: number?,
	vignetteDarkenAtSec: number?,
	vignetteDarkenDurationSec: number?,
	fullDarkenTo: number?,
	fullDarkenAtSec: number?,
	fullDarkenZIndex: number?,
	distortionLines: boolean,
	distortionLineCount: number?,
	distortionSlideSpeed: number?,
	flashColor: Color3?,
	flashDurationSec: number,
	flashPeakTransparency: number,
	secondFlashColor: Color3?,
	secondFlashDelaySec: number?,
	secondFlashDuration: number?,
	secondFlashPeakTransparency: number?,
}

export type BurstSpec = {
	coreCount: number,
	starCount: number,
	wispCount: number,
	boltCount: number,
	confettiCount: number,
	beamCount: number,
}

export type SfxTiming = {
	soundId: string,
	atSec: number,
}

export type HatchCrackEntry = {
	wobblePhases: WobblePhase,
	crackStyle: CrackStyle,
	glowColor: Color3,
	screenEffect: ScreenEffect,
	burstSize: BurstSpec,
	totalDurationSec: number,
	sfxTiming: { SfxTiming },
	eggSizeGrowth: number,
	shellShards: ShellShard?,
	hitstopSec: number?,
	lightRays: number?,
	lightRayColor: Color3?,
	cameraShakeIntensity: number?,
	cameraShakeDurationSec: number?,
	fovPunch: number?,
	fovReturnSec: number?,
	breakScaleMultiplier: number,
	breakDurationSec: number,
}

local HatchCrackVisualSpec = {}

-- Note: do not use `Entries: Type =` here — Luau parses `:` after a field as a method, which breaks on `{`.
HatchCrackVisualSpec.Entries = {

	common = {
		wobblePhases = {
			durationSec = 1.0,
			frequencyHz = 2,
			maxAmplitudeDeg = 3,
			rampCurve = "linear",
		},
		crackStyle = {
			lineCount = 0,
			color = Color3.fromRGB(180, 180, 180),
		},
		glowColor = Color3.fromRGB(180, 180, 180),
		screenEffect = {
			flashColor = Color3.fromRGB(180, 180, 180),
			flashDurationSec = 0.18,
			flashPeakTransparency = 0.55,
			distortionLines = false,
		},
		burstSize = { coreCount = 20, starCount = 0, wispCount = 0, boltCount = 0, confettiCount = 0, beamCount = 0 },
		totalDurationSec = 1.5,
		sfxTiming = {
			{ soundId = "hatch_common", atSec = 1.0 },
		},
		eggSizeGrowth = 0,
		breakScaleMultiplier = 1.0,
		breakDurationSec = 0.25,
	},

	uncommon = {
		wobblePhases = {
			durationSec = 1.4,
			frequencyHz = 2.5,
			maxAmplitudeDeg = 4,
			rampCurve = "linear",
		},
		crackStyle = {
			lineCount = 1,
			color = Color3.fromRGB(80, 200, 80),
			lines = {
				{ spawnTimeSec = 0.8, sizeScale = UDim2.new(0, 2, 0.7, 0), position = UDim2.new(0.55, 0, 0.15, 0), rotationDeg = -15, thicknessPx = 2, fadeFrom = 0.8, fadeTo = 0.2, fadeDurationSec = 0.4 },
			},
		},
		glowColor = Color3.fromRGB(80, 200, 80),
		screenEffect = {
			flashColor = Color3.fromRGB(80, 200, 80),
			flashDurationSec = 0.18,
			flashPeakTransparency = 0.55,
			distortionLines = false,
		},
		burstSize = { coreCount = 30, starCount = 10, wispCount = 0, boltCount = 0, confettiCount = 0, beamCount = 0 },
		totalDurationSec = 2.0,
		sfxTiming = {
			{ soundId = "hatch_uncommon", atSec = 1.4 },
		},
		eggSizeGrowth = 0,
		breakScaleMultiplier = 1.15,
		breakDurationSec = 0.20,
	},

	rare = {
		wobblePhases = {
			durationSec = 1.8,
			frequencyHz = 3,
			maxAmplitudeDeg = 5,
			rampCurve = "quadratic",
			rampExponent = 1.3,
		},
		crackStyle = {
			lineCount = 3,
			color = Color3.fromRGB(60, 130, 255),
			lines = {
				{ spawnTimeSec = 0.8, sizeScale = UDim2.new(0, 2, 0.55, 0), position = UDim2.new(0.45, 0, 0.10, 0), rotationDeg = -12, thicknessPx = 2, fadeFrom = 0.7, fadeTo = 0.15, fadeDurationSec = 0.3 },
				{ spawnTimeSec = 1.1, sizeScale = UDim2.new(0, 2, 0.40, 0), position = UDim2.new(0.60, 0, 0.30, 0), rotationDeg = 25, thicknessPx = 2, fadeFrom = 0.7, fadeTo = 0.15, fadeDurationSec = 0.3 },
				{ spawnTimeSec = 1.4, sizeScale = UDim2.new(0, 2, 0.50, 0), position = UDim2.new(0.35, 0, 0.20, 0), rotationDeg = -35, thicknessPx = 2, fadeFrom = 0.7, fadeTo = 0.15, fadeDurationSec = 0.3 },
			},
		},
		glowColor = Color3.fromRGB(60, 130, 255),
		screenEffect = {
			flashColor = Color3.fromRGB(60, 130, 255),
			flashDurationSec = 0.18,
			flashPeakTransparency = 0.55,
			distortionLines = false,
		},
		burstSize = { coreCount = 50, starCount = 20, wispCount = 0, boltCount = 0, confettiCount = 0, beamCount = 4 },
		totalDurationSec = 2.5,
		sfxTiming = {
			{ soundId = "egg_crack_small", atSec = 0.8 },
			{ soundId = "hatch_rare", atSec = 1.8 },
		},
		eggSizeGrowth = 0,
		breakScaleMultiplier = 1.2,
		breakDurationSec = 0.25,
	},

	epic = {
		wobblePhases = {
			durationSec = 2.2,
			frequencyHz = 3.5,
			maxAmplitudeDeg = 6,
			rampCurve = "cubic",
			rampExponent = 1.6,
		},
		crackStyle = {
			lineCount = 6,
			color = Color3.fromRGB(180, 60, 255),
			glowPulseHz = 2,
		},
		glowColor = Color3.fromRGB(180, 60, 255),
		screenEffect = {
			vignetteDarkenTo = 0.78,
			vignetteDarkenAtSec = 1.0,
			vignetteDarkenDurationSec = 1.0,
			flashColor = Color3.fromRGB(180, 60, 255),
			flashDurationSec = 0.18,
			flashPeakTransparency = 0.55,
			distortionLines = false,
		},
		burstSize = { coreCount = 80, starCount = 30, wispCount = 20, boltCount = 0, confettiCount = 0, beamCount = 6 },
		totalDurationSec = 3.0,
		sfxTiming = {
			{ soundId = "egg_crack_small", atSec = 0.6 },
			{ soundId = "egg_crack_medium", atSec = 1.4 },
			{ soundId = "hatch_epic", atSec = 2.2 },
		},
		eggSizeGrowth = 0.10,
		shellShards = { count = 4, sizePxMin = 20, sizePxMax = 35, hasTrail = false },
		cameraShakeIntensity = 0.35,
		cameraShakeDurationSec = 0.2,
		breakScaleMultiplier = 1.3,
		breakDurationSec = 0.05,
	},

	legendary = {
		wobblePhases = {
			durationSec = 2.8,
			frequencyHz = 2,
			frequencyHzEnd = 5,
			maxAmplitudeDeg = 3,
			maxAmplitudeDegEnd = 8,
			rampCurve = "exponential",
			rampExponent = 2,
		},
		crackStyle = {
			lineCount = 9,
			color = Color3.fromRGB(255, 200, 50),
			glowPulseHz = 3,
		},
		glowColor = Color3.fromRGB(255, 200, 50),
		screenEffect = {
			vignetteDarkenTo = 0.75,
			vignetteDarkenAtSec = 0,
			vignetteDarkenDurationSec = 1.5,
			flashColor = Color3.fromRGB(255, 200, 50),
			flashDurationSec = 0.18,
			flashPeakTransparency = 0.55,
			distortionLines = false,
		},
		burstSize = { coreCount = 120, starCount = 50, wispCount = 0, boltCount = 16, confettiCount = 24, beamCount = 8 },
		totalDurationSec = 3.8,
		sfxTiming = {
			{ soundId = "egg_crack_small", atSec = 0.8 },
			{ soundId = "egg_crack_medium", atSec = 1.5 },
			{ soundId = "egg_crack_large", atSec = 2.3 },
			{ soundId = "hatch_legendary", atSec = 2.8 },
		},
		eggSizeGrowth = 0.20,
		shellShards = { count = 6, sizePxMin = 20, sizePxMax = 35, hasTrail = true, trailColor = Color3.fromRGB(255, 200, 50) },
		hitstopSec = 0.25,
		lightRays = 4,
		lightRayColor = Color3.fromRGB(255, 240, 160),
		cameraShakeIntensity = 0.35,
		cameraShakeDurationSec = 0.2,
		fovPunch = 4,
		fovReturnSec = 0.25,
		breakScaleMultiplier = 1.5,
		breakDurationSec = 0.03,
	},

	mythic = {
		wobblePhases = {
			durationSec = 3.5,
			frequencyHz = 1.5,
			frequencyHzEnd = 7,
			maxAmplitudeDeg = 2,
			maxAmplitudeDegEnd = 10,
			rampCurve = "exponential",
			rampExponent = 2.5,
			jitterAfterSec = 2.5,
			jitterPx = 1,
		},
		crackStyle = {
			lineCount = 12,
			color = Color3.fromRGB(255, 50, 80),
			glowPulseHz = 4,
			isRainbow = true,
		},
		glowColor = Color3.fromRGB(255, 50, 80),
		screenEffect = {
			fullDarkenTo = 0.55,
			fullDarkenAtSec = 1.0,
			fullDarkenZIndex = 38,
			flashColor = Color3.new(1, 1, 1),
			flashDurationSec = 0.20,
			flashPeakTransparency = 0.12,
			secondFlashColor = Color3.fromRGB(255, 50, 80),
			secondFlashDelaySec = 0.05,
			secondFlashDuration = 0.40,
			secondFlashPeakTransparency = 0.25,
			distortionLines = true,
			distortionLineCount = 5,
			distortionSlideSpeed = 0.12,
		},
		burstSize = { coreCount = 200, starCount = 80, wispCount = 40, boltCount = 24, confettiCount = 40, beamCount = 0 },
		totalDurationSec = 5.0,
		sfxTiming = {
			{ soundId = "egg_crack_small", atSec = 0.5 },
			{ soundId = "egg_crack_medium", atSec = 1.5 },
			{ soundId = "egg_crack_large", atSec = 2.2 },
			{ soundId = "egg_mythic_resonance", atSec = 2.8 },
			{ soundId = "egg_mythic_hum", atSec = 3.0 },
			{ soundId = "hatch_mythic", atSec = 3.5 },
		},
		eggSizeGrowth = 0.32,
		shellShards = { count = 8, sizePxMin = 20, sizePxMax = 40, hasTrail = true, trailColor = Color3.fromRGB(255, 50, 80) },
		hitstopSec = 0.50,
		lightRays = 7,
		lightRayColor = Color3.fromRGB(255, 100, 200),
		cameraShakeIntensity = 0.50,
		cameraShakeDurationSec = 0.35,
		fovPunch = 8,
		fovReturnSec = 0.35,
		breakScaleMultiplier = 1.0,
		breakDurationSec = 0,
	},
}

--[[
	RARITY ESCALATION AT A GLANCE

	| Rarity    | Duration | Wobble Hz   | Cracks | Glow Pulse | Hitstop | Darken | FOV  | Shards |
	|-----------|----------|-------------|--------|------------|---------|--------|------|--------|
	| common    | 1.5s     | 2           | 0      | —          | —       | —      | —    | 0      |
	| uncommon  | 2.0s     | 2.5         | 1      | —          | —       | —      | —    | 0      |
	| rare      | 2.5s     | 3           | 3      | —          | —       | —      | —    | 0      |
	| epic      | 3.0s     | 3.5         | 5-7    | 2Hz        | —       | 0.78   | —    | 4      |
	| legendary | 3.8s     | 2→5         | 8-10   | 3Hz        | 0.25s   | 0.75   | +4   | 6      |
	| mythic    | 5.0s     | 1.5→7       | 10-14  | 4Hz        | 0.50s   | 0.55   | +8   | 8      |

	SOUND CUES NEEDED:
	  egg_crack_small      — hairline snap (0.2s)
	  egg_crack_medium     — spreading crackle (0.3s)
	  egg_crack_large      — deep resonant fracture (0.4s)
	  egg_mythic_hum       — loopable sub-bass (0.5s loop, during hitstop)
	  egg_mythic_resonance — otherworldly deep tone (0.5s one-shot)
]]

function HatchCrackVisualSpec.getForRarity(rarity: string): HatchCrackEntry?
	return HatchCrackVisualSpec.Entries[rarity]
end

function HatchCrackVisualSpec.wobbleAt(entry: HatchCrackEntry, t: number): number
	local w = entry.wobblePhases
	local progress = math.clamp(t / w.durationSec, 0, 1)

	local ramp: number
	if w.rampCurve == "linear" then
		ramp = progress
	elseif w.rampCurve == "quadratic" or w.rampCurve == "cubic" then
		ramp = progress ^ (w.rampExponent or 1.3)
	elseif w.rampCurve == "exponential" then
		ramp = progress ^ (w.rampExponent or 2)
	else
		ramp = progress
	end

	local freq = w.frequencyHz
	if w.frequencyHzEnd then
		freq = w.frequencyHz + (w.frequencyHzEnd - w.frequencyHz) * ramp
	end

	local amp = w.maxAmplitudeDeg
	if w.maxAmplitudeDegEnd then
		amp = w.maxAmplitudeDeg + (w.maxAmplitudeDegEnd - w.maxAmplitudeDeg) * ramp
	end

	return math.sin(t * freq * math.pi * 2) * amp * ramp
end

return HatchCrackVisualSpec
