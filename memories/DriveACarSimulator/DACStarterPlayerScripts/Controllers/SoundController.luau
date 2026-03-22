--!strict
--[[
	Client audio: categories (music / sfx / ambient), persistence from player settings,
	crossfading world themes, one-shot SFX, ambient loops per world.

	Sound IDs come from ReplicatedStorage.Audio: each registry key should match a Sound's Name
	(or optional StringValue holding rbxassetid://…). Uploads live in Studio only; see Audio/MANIFEST.md
	for the key ↔ source file map. Missing assets keep rbxassetid://0 and stay silent.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

export type SoundCategory = "music" | "sfx" | "ambient"

local SoundController = {}

local registry: {
	[string]: {
		soundId: string,
		category: SoundCategory,
	},
} = {}

local soundRoot: SoundGroup
local musicA: Sound
local musicB: Sound
local usingA = true
local currentMusicWorld: string? = nil
local ambientSound: Sound
local currentAmbientWorld: string? = nil

local sfxLoops: { [string]: Sound } = {}
local sfxLoopVolumeMul: { [string]: number } = {}

local masterEnabled = true
local musicVolume = 0.35
local sfxVolume = 0.25
local ambientMul = 0.5 -- ambient uses sfx bus, scaled for headroom vs SFX

local CROSSFADE_TIME = 0.85

local AUDIO_WAIT_SECS = 8

-- Board-uploaded sounds live in ReplicatedStorage.Audio (TOS-approved, ready to use).
-- hydrateFromReplicatedStorageAudio() matches Sound.Name → registry key at init.
-- If a Board sound uses a different Name than our key, add a mapping here.
local AUDIO_NAME_ALIASES: { [string]: string } = {
	-- music_grasslands = "grasslands",
}

local function soundIdFromInstance(inst: Instance): string?
	if inst:IsA("Sound") then
		local id = inst.SoundId
		if id ~= "" and id ~= "rbxassetid://0" then
			return id
		end
	elseif inst:IsA("StringValue") then
		local v = inst.Value
		if string.sub(v, 1, 11) == "rbxassetid:" or string.sub(v, 1, 7) == "http://" or string.sub(v, 1, 8) == "https://" then
			return v
		end
	end
	return nil
end

-- Finds a Sound or StringValue under `audioRoot` named `name` (direct child or any descendant).
local function findAudioNamed(audioRoot: Instance, name: string): Instance?
	local direct = audioRoot:FindFirstChild(name)
	if direct and (direct:IsA("Sound") or direct:IsA("StringValue")) then
		return direct
	end
	for _, d in audioRoot:GetDescendants() do
		if d.Name == name and (d:IsA("Sound") or d:IsA("StringValue")) then
			return d
		end
	end
	return nil
end

local function hydrateFromReplicatedStorageAudio()
	local audioRoot = ReplicatedStorage:FindFirstChild("Audio")
	if not audioRoot then
		local ok, folder = pcall(function()
			return ReplicatedStorage:WaitForChild("Audio", AUDIO_WAIT_SECS)
		end)
		if ok and folder then
			audioRoot = folder
		end
	end
	if not audioRoot then
		return
	end

	for key, reg in registry do
		local alias = AUDIO_NAME_ALIASES[key]
		local inst = findAudioNamed(audioRoot, key)
		if not inst and alias then
			inst = findAudioNamed(audioRoot, alias)
		end
		if inst then
			local id = soundIdFromInstance(inst)
			if id then
				reg.soundId = id
			end
		end
	end
end

local function categoryVolume(cat: SoundCategory): number
	if not masterEnabled then
		return 0
	end
	if cat == "music" then
		return musicVolume
	elseif cat == "ambient" then
		return sfxVolume * ambientMul
	end
	return sfxVolume
end

function SoundController.register(name: string, soundId: string, category: SoundCategory)
	registry[name] = { soundId = soundId, category = category }
end

local function tweenVolume(sound: Sound, target: number, duration: number)
	local t = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Volume = target,
	})
	t:Play()
	return t
end

local function ensureSounds()
	if soundRoot then
		return
	end
	soundRoot = Instance.new("SoundGroup")
	soundRoot.Name = "DACSounds"
	soundRoot.Volume = 0.1
	soundRoot.Parent = SoundService

	musicA = Instance.new("Sound")
	musicA.Name = "MusicA"
	musicA.Looped = true
	musicA.Volume = 0
	musicA.SoundGroup = soundRoot
	musicA.Parent = soundRoot

	musicB = Instance.new("Sound")
	musicB.Name = "MusicB"
	musicB.Looped = true
	musicB.Volume = 0
	musicB.SoundGroup = soundRoot
	musicB.Parent = soundRoot

	ambientSound = Instance.new("Sound")
	ambientSound.Name = "Ambient"
	ambientSound.Looped = true
	ambientSound.Volume = 0
	ambientSound.SoundGroup = soundRoot
	ambientSound.Parent = soundRoot
end

function SoundController.playLoop(name: string, pitch: number?, volumeScale: number?)
	ensureSounds()
	local reg = registry[name]
	if not reg or reg.category ~= "sfx" then
		return
	end
	local vol = categoryVolume("sfx")
	if vol < 0.001 then
		return
	end
	if reg.soundId == "rbxassetid://0" or reg.soundId == "" then
		return
	end
	local mul = if volumeScale ~= nil then math.clamp(volumeScale, 0, 2) else 0.55
	sfxLoopVolumeMul[name] = mul
	local existing = sfxLoops[name]
	if existing then
		existing.PlaybackSpeed = pitch or 1
		existing.Volume = vol * mul
		if not existing.IsPlaying then
			existing:Play()
		end
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Loop_" .. name
	s.SoundId = reg.soundId
	s.Looped = true
	s.PlaybackSpeed = pitch or 1
	s.Volume = vol * mul
	s.SoundGroup = soundRoot
	s.Parent = soundRoot
	sfxLoops[name] = s
	s:Play()
end

function SoundController.setLoopPitch(name: string, pitch: number)
	local s = sfxLoops[name]
	if s then
		s.PlaybackSpeed = pitch
	end
end

function SoundController.setLoopVolume(name: string, volumeScale: number)
	sfxLoopVolumeMul[name] = math.clamp(volumeScale, 0, 2)
	local s = sfxLoops[name]
	if s then
		s.Volume = categoryVolume("sfx") * sfxLoopVolumeMul[name]
	end
end

function SoundController.stopLoop(name: string, fadeDuration: number?)
	local s = sfxLoops[name]
	if not s then
		sfxLoopVolumeMul[name] = nil
		return
	end
	local dur = fadeDuration or 0
	if dur < 0.05 then
		s:Stop()
		s:Destroy()
		sfxLoops[name] = nil
		sfxLoopVolumeMul[name] = nil
		return
	end
	local tw = tweenVolume(s, 0, dur)
	tw.Completed:Connect(function()
		if s.Parent then
			s:Stop()
			s:Destroy()
		end
		sfxLoops[name] = nil
		sfxLoopVolumeMul[name] = nil
	end)
end

local function resolveSfxSoundId(name: string): (string?, SoundCategory?)
	local reg = registry[name]
	if not reg then
		return nil, nil
	end
	if reg.category ~= "sfx" then
		return nil, nil
	end
	if reg.soundId ~= "" and reg.soundId ~= "rbxassetid://0" then
		return reg.soundId, reg.category
	end
	local fb = registry["notification"]
	if fb and fb.category == "sfx" and fb.soundId ~= "" and fb.soundId ~= "rbxassetid://0" then
		return fb.soundId, fb.category
	end
	return nil, nil
end

function SoundController.playOneShot(name: string, pitch: number?)
	ensureSounds()
	local soundId, cat = resolveSfxSoundId(name)
	if not soundId or not cat then
		return
	end
	local vol = categoryVolume("sfx")
	if vol < 0.001 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.PlaybackSpeed = if pitch ~= nil then math.clamp(pitch, 0.5, 2) else 1
	s.Volume = vol
	s.SoundGroup = soundRoot
	s.Parent = soundRoot
	s:Play()
	Debris:AddItem(s, 6)
end

function SoundController.playOneShotPrefer(names: { string })
	for _, name in names do
		local soundId, cat = resolveSfxSoundId(name)
		if soundId and cat then
			SoundController.playOneShot(name)
			return
		end
	end
end

function SoundController.applySettings(settings: { [string]: any }?)
	if not settings then
		return
	end
	if type(settings.sound) == "boolean" then
		masterEnabled = settings.sound
	end
	if type(settings.musicVolume) == "number" then
		musicVolume = math.clamp(settings.musicVolume, 0, 1)
	end
	if type(settings.sfxVolume) == "number" then
		sfxVolume = math.clamp(settings.sfxVolume, 0, 1)
	end

	if not soundRoot then
		return
	end
	local mv = categoryVolume("music")
	local av = categoryVolume("ambient")
	local active = if usingA then musicA else musicB
	if active.IsPlaying and currentMusicWorld then
		active.Volume = mv
	end
	if ambientSound.IsPlaying and currentAmbientWorld then
		ambientSound.Volume = av
	end

	local sfxV = categoryVolume("sfx")
	for loopName, snd in sfxLoops do
		local mul = sfxLoopVolumeMul[loopName] or 0.55
		snd.Volume = sfxV * mul
	end
end

function SoundController.setWorld(worldId: string)
	ensureSounds()

	local mv = categoryVolume("music")
	local mkey = `music_{worldId}`
	local mreg = registry[mkey]

	if mreg and mreg.soundId ~= "rbxassetid://0" and mreg.soundId ~= "" then
		if currentMusicWorld == nil then
			musicA.SoundId = mreg.soundId
			musicA.Volume = mv
			musicA:Play()
			musicB:Stop()
			musicB.Volume = 0
			usingA = true
			currentMusicWorld = worldId
		elseif worldId == currentMusicWorld then
			local active = if usingA then musicA else musicB
			active.Volume = mv
		else
			local outgoing = if usingA then musicA else musicB
			local incoming = if usingA then musicB else musicA
			incoming.SoundId = mreg.soundId
			incoming.Volume = 0
			incoming:Play()
			tweenVolume(outgoing, 0, CROSSFADE_TIME)
			tweenVolume(incoming, mv, CROSSFADE_TIME)
			task.delay(CROSSFADE_TIME + 0.05, function()
				outgoing:Stop()
			end)
			usingA = not usingA
			currentMusicWorld = worldId
		end
	end

	local av = categoryVolume("ambient")
	local akey = `ambient_{worldId}`
	local areg = registry[akey]
	if not areg or areg.soundId == "rbxassetid://0" or areg.soundId == "" then
		return
	end
	if currentAmbientWorld == nil then
		ambientSound.SoundId = areg.soundId
		ambientSound.Volume = av
		ambientSound:Play()
		currentAmbientWorld = worldId
	elseif worldId ~= currentAmbientWorld then
		ambientSound.SoundId = areg.soundId
		ambientSound.Volume = 0
		ambientSound:Play()
		tweenVolume(ambientSound, av, 0.45)
		currentAmbientWorld = worldId
	else
		ambientSound.Volume = av
	end
end

local function registerDefaults()
	-- All IDs sourced from game.ReplicatedStorage.Audio (TOS-approved uploads).
	-- Hydration still runs as a fallback if names match registry keys.

	-- World music beds
	SoundController.register("music_grasslands", "rbxassetid://1841647093", "music") -- Life in an Elevator
	SoundController.register("music_desert", "rbxassetid://122720386196973", "music") -- Dealership (60s)
	SoundController.register("music_frozen", "rbxassetid://7640700658", "music") -- Witches' Brew (133s)
	SoundController.register("music_neon", "rbxassetid://97844915150974", "music") -- Rhythm Junkie (103s)

	-- World ambience
	SoundController.register("ambient_grasslands", "rbxassetid://73798751154555", "ambient") -- Lake
	SoundController.register("ambient_desert", "rbxassetid://9059618023", "ambient") -- Defiance_Ambiance03
	SoundController.register("ambient_frozen", "rbxassetid://11876250716", "ambient") -- snow
	SoundController.register("ambient_neon", "rbxassetid://2843658663", "ambient") -- City Sounds

	-- Engine idle loops
	SoundController.register("engine_buggy", "rbxassetid://12843280490", "sfx") -- idle (generic)
	SoundController.register("engine_sedan", "rbxassetid://8836845570", "sfx") -- Audi R8 Idle
	SoundController.register("engine_racer", "rbxassetid://130983335056535", "sfx") -- V10
	SoundController.register("engine_supercar", "rbxassetid://7136339316", "sfx") -- Aventador Low
	SoundController.register("engine_wind", "rbxassetid://11876250654", "sfx") -- asphalt (road surface layer)

	-- UI
	SoundController.register("click", "rbxassetid://10630778959", "sfx") -- Click
	SoundController.register("near_miss", "rbxassetid://14753859187", "sfx") -- bov_1 (whoosh)
	SoundController.register("combo_break", "rbxassetid://14755055417", "sfx") -- low_med_off (engine cut)
	SoundController.register("ui_whoosh", "rbxassetid://10849970849", "sfx") -- SpawnParticle (swoosh)
	SoundController.register("purchase", "rbxassetid://9545920468", "sfx") -- GoldCorn (cha-ching)
	SoundController.register("purchase_thankyou_buildup", "rbxassetid://9538232720", "sfx") -- PE-Electrical_BW.32224 (riser)
	SoundController.register("purchase_thankyou_reveal", "rbxassetid://9545920468", "sfx") -- GoldCorn
	SoundController.register("purchase_thankyou_reveal_vip", "rbxassetid://9660107771", "sfx") -- ClubSmash
	SoundController.register("purchase_thankyou_reveal_whale", "rbxassetid://9660466869", "sfx") -- Stomp (heavy impact)
	SoundController.register("purchase_fail", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179 (error buzz)
	SoundController.register("error", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179
	SoundController.register("tab_switch", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("panel_open", "rbxassetid://7938564577", "sfx") -- WarmPluck
	SoundController.register("panel_close", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("equip_item", "rbxassetid://9591690518", "sfx") -- Absorb
	SoundController.register("world_unlock", "rbxassetid://9460707764", "sfx") -- BustOpen
	SoundController.register("world_travel", "rbxassetid://12842999193", "sfx") -- startup
	SoundController.register("notification", "rbxassetid://10630729494", "sfx") -- UIBlip
	SoundController.register("quest_progress", "rbxassetid://7938634444", "sfx") -- ui_sound_12
	SoundController.register("ui_confirm", "rbxassetid://7938634444", "sfx") -- ui_sound_12
	SoundController.register("cha_ching", "rbxassetid://10849997662", "sfx") -- Coin
	SoundController.register("level_up", "rbxassetid://6971833728", "sfx") -- Item Collect

	-- Egg hatch (ascending intensity by rarity)
	SoundController.register("hatch", "rbxassetid://9546777688", "sfx") -- Bubble (default sting)
	SoundController.register("hatch_common", "rbxassetid://9546777688", "sfx") -- Bubble
	SoundController.register("hatch_uncommon", "rbxassetid://9554965517", "sfx") -- blinky
	SoundController.register("hatch_rare", "rbxassetid://10849970849", "sfx") -- SpawnParticle
	SoundController.register("hatch_epic", "rbxassetid://9460707764", "sfx") -- BustOpen
	SoundController.register("hatch_legendary", "rbxassetid://9660107771", "sfx") -- ClubSmash
	SoundController.register("hatch_mythic", "rbxassetid://9660482478", "sfx") -- Explosion
	SoundController.register("egg_crack_small", "rbxassetid://12946370827", "sfx") -- crackle_12
	SoundController.register("egg_crack_medium", "rbxassetid://9729017179", "sfx") -- Punch
	SoundController.register("egg_crack_large", "rbxassetid://9660466869", "sfx") -- Stomp
	SoundController.register("egg_mythic_hum", "rbxassetid://9538232720", "sfx") -- PE-Electrical_BW.32224
	SoundController.register("egg_mythic_resonance", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179

	-- Pet equip entrance (ascending intensity by rarity)
	SoundController.register("pet_equip_common", "rbxassetid://9546777688", "sfx") -- Bubble
	SoundController.register("pet_equip_uncommon", "rbxassetid://9591690518", "sfx") -- Absorb
	SoundController.register("pet_equip_rare", "rbxassetid://10849970849", "sfx") -- SpawnParticle
	SoundController.register("pet_equip_epic", "rbxassetid://7938564577", "sfx") -- WarmPluck
	SoundController.register("pet_equip_legendary_beam", "rbxassetid://9538232720", "sfx") -- PE-Electrical_BW.32224
	SoundController.register("pet_equip_legendary_impact", "rbxassetid://9575596194", "sfx") -- Impact
	SoundController.register("pet_equip_mythic_tear", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179
	SoundController.register("pet_equip_mythic_explosion", "rbxassetid://9660482478", "sfx") -- Explosion

	-- Rebirth fanfare layers
	SoundController.register("rebirth", "rbxassetid://9660107771", "sfx") -- ClubSmash (full sting)
	SoundController.register("rebirth_riser", "rbxassetid://9538232720", "sfx") -- PE-Electrical_BW.32224
	SoundController.register("rebirth_whoosh", "rbxassetid://9146096134", "sfx") -- StartedBoosting
	SoundController.register("rebirth_boom", "rbxassetid://9660482478", "sfx") -- Explosion
	SoundController.register("rebirth_confetti", "rbxassetid://9545920468", "sfx") -- GoldCorn

	-- Driving HUD
	SoundController.register("milestone", "rbxassetid://7938634444", "sfx") -- ui_sound_12
	SoundController.register("combo", "rbxassetid://9554965517", "sfx") -- blinky
	SoundController.register("speed_tier", "rbxassetid://9146096134", "sfx") -- StartedBoosting
	SoundController.register("fuel_warning", "rbxassetid://9554965517", "sfx") -- blinky
	SoundController.register("alert", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179
	SoundController.register("fusion", "rbxassetid://9591690518", "sfx") -- Absorb

	-- Driving SFX
	SoundController.register("screech", "rbxassetid://11864334285", "sfx") -- drift
	SoundController.register("boost", "rbxassetid://9146096251", "sfx") -- Boosting
	SoundController.register("collision", "rbxassetid://9575596194", "sfx") -- Impact
	SoundController.register("coin_pickup", "rbxassetid://10849997662", "sfx") -- Coin
	SoundController.register("distance_marker", "rbxassetid://7938634444", "sfx") -- ui_sound_12
	SoundController.register("lap_horn", "rbxassetid://14753859187", "sfx") -- bov_1

	-- Fuel warnings
	SoundController.register("fuel_warning_25", "rbxassetid://9554965517", "sfx") -- blinky (gentle beep)
	SoundController.register("fuel_warning_10", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179
	SoundController.register("fuel_warning_5", "rbxassetid://9538232720", "sfx") -- PE-Electrical_BW.32224
	SoundController.register("fuel_empty", "rbxassetid://14755055417", "sfx") -- low_med_off (engine stall)

	-- Premium welcome
	SoundController.register("premium_welcome", "rbxassetid://9545920468", "sfx") -- GoldCorn

	-- World pickup / HUD
	SoundController.register("currency", "rbxassetid://10849997662", "sfx") -- Coin

	-- Event banner
	SoundController.register("event_fanfare", "rbxassetid://9460707764", "sfx") -- BustOpen

	-- Tutorial
	SoundController.register("tutorial_step", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("tutorial_complete", "rbxassetid://6971833728", "sfx") -- Item Collect

	-- Payout panel
	SoundController.register("payout_card_pop", "rbxassetid://9546777688", "sfx") -- Bubble
	SoundController.register("payout_badge_tick", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("payout_run_of_day", "rbxassetid://7938564577", "sfx") -- WarmPluck
	SoundController.register("payout_tier_up", "rbxassetid://9545920468", "sfx") -- GoldCorn

	-- Trophy
	SoundController.register("trophy_bronze", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("trophy_silver", "rbxassetid://7938564577", "sfx") -- WarmPluck
	SoundController.register("trophy_gold", "rbxassetid://9545920468", "sfx") -- GoldCorn
	SoundController.register("trophy_diamond", "rbxassetid://9660107771", "sfx") -- ClubSmash
	SoundController.register("trophy_total_completion", "rbxassetid://6971833728", "sfx") -- Item Collect
end

function SoundController.init()
	registerDefaults()
	hydrateFromReplicatedStorageAudio()
	ensureSounds()
	SoundFacade.bind(SoundController)
	SoundController.setWorld("grasslands")
end

return SoundController
