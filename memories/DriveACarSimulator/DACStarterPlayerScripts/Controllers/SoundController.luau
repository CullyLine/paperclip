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

local soundRoot: Folder
local musicA: Sound
local musicB: Sound
local usingA = true
local currentMusicWorld: string? = nil
local ambientSound: Sound
local currentAmbientWorld: string? = nil

local masterEnabled = true
local musicVolume = 0.7
local sfxVolume = 0.8
local ambientMul = 0.75 -- ambient uses sfx bus, scaled for headroom vs SFX

local CROSSFADE_TIME = 0.85

local WORLDS = { "grasslands", "desert", "frozen", "neon" }

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
	soundRoot = Instance.new("Folder")
	soundRoot.Name = "DACSounds"
	soundRoot.Parent = SoundService

	musicA = Instance.new("Sound")
	musicA.Name = "MusicA"
	musicA.Looped = true
	musicA.Volume = 0
	musicA.Parent = soundRoot

	musicB = Instance.new("Sound")
	musicB.Name = "MusicB"
	musicB.Looped = true
	musicB.Volume = 0
	musicB.Parent = soundRoot

	ambientSound = Instance.new("Sound")
	ambientSound.Name = "Ambient"
	ambientSound.Looped = true
	ambientSound.Volume = 0
	ambientSound.Parent = soundRoot
end

function SoundController.playOneShot(name: string)
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
	local s = Instance.new("Sound")
	s.SoundId = reg.soundId
	s.Volume = vol
	s.Parent = soundRoot
	s:Play()
	Debris:AddItem(s, 6)
end

-- Legacy name used by older call sites
function SoundController.play(soundName: string)
	SoundController.playOneShot(soundName)
end

function SoundController.setMusic(enabled: boolean)
	masterEnabled = enabled
	SoundController.applySettings({
		sound = enabled,
		musicVolume = musicVolume,
		sfxVolume = sfxVolume,
	})
end

function SoundController.setSFX(enabled: boolean)
	-- Kept for API compat; full mute uses settings.sound
	sfxVolume = if enabled then math.max(sfxVolume, 0.01) else 0
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
	-- World beds — disk: memories/DriveACarSimulator/Audio/music/<world>.ogg & ambient/<world>_amb.ogg
	for _, id in WORLDS do
		SoundController.register(`music_{id}`, "rbxassetid://0", "music") -- Audio/music/<id>.ogg
		SoundController.register(`ambient_{id}`, "rbxassetid://0", "ambient") -- Audio/ambient/<id>_amb.ogg
	end

	-- Engine idle loops (vehicle wiring TBD) — Audio/engines/*.ogg
	SoundController.register("engine_buggy", "rbxassetid://0", "sfx") -- buggy_idle.ogg
	SoundController.register("engine_sedan", "rbxassetid://0", "sfx") -- sedan_idle.ogg
	SoundController.register("engine_racer", "rbxassetid://0", "sfx") -- racer_idle.ogg
	SoundController.register("engine_supercar", "rbxassetid://0", "sfx") -- supercar_idle.ogg

	-- UI — Audio/ui/*.ogg
	SoundController.register("click", "rbxassetid://0", "sfx") -- click.ogg
	SoundController.register("purchase", "rbxassetid://0", "sfx") -- purchase_success.ogg
	SoundController.register("purchase_fail", "rbxassetid://0", "sfx") -- purchase_fail.ogg
	SoundController.register("tab_switch", "rbxassetid://0", "sfx") -- tab_switch.ogg
	SoundController.register("panel_open", "rbxassetid://0", "sfx") -- panel_open.ogg
	SoundController.register("panel_close", "rbxassetid://0", "sfx") -- panel_close.ogg
	SoundController.register("notification", "rbxassetid://0", "sfx") -- notification.ogg
	SoundController.register("level_up", "rbxassetid://0", "sfx") -- level_up.ogg

	-- Egg hatch by rarity — Audio/hatch/<tier>.ogg (code still calls hatch until rarity is threaded)
	SoundController.register("hatch", "rbxassetid://0", "sfx") -- common.ogg (default sting)
	SoundController.register("hatch_common", "rbxassetid://0", "sfx") -- common.ogg
	SoundController.register("hatch_uncommon", "rbxassetid://0", "sfx") -- uncommon.ogg
	SoundController.register("hatch_rare", "rbxassetid://0", "sfx") -- rare.ogg
	SoundController.register("hatch_epic", "rbxassetid://0", "sfx") -- epic.ogg
	SoundController.register("hatch_legendary", "rbxassetid://0", "sfx") -- legendary.ogg
	SoundController.register("hatch_mythic", "rbxassetid://0", "sfx") -- mythic.ogg

	-- Rebirth fanfare layers — Audio/rebirth/*.ogg
	SoundController.register("rebirth", "rbxassetid://0", "sfx") -- full sting (riser+layers); see rebirth/*.ogg
	SoundController.register("rebirth_riser", "rbxassetid://0", "sfx") -- riser.ogg
	SoundController.register("rebirth_whoosh", "rbxassetid://0", "sfx") -- whoosh.ogg
	SoundController.register("rebirth_boom", "rbxassetid://0", "sfx") -- boom.ogg
	SoundController.register("rebirth_confetti", "rbxassetid://0", "sfx") -- confetti.ogg

	-- Driving — Audio/driving/*.ogg
	SoundController.register("screech", "rbxassetid://0", "sfx") -- screech.ogg
	SoundController.register("boost", "rbxassetid://0", "sfx") -- boost.ogg
	SoundController.register("collision", "rbxassetid://0", "sfx") -- collision.ogg
	SoundController.register("coin_pickup", "rbxassetid://0", "sfx") -- coin_pickup.ogg
	SoundController.register("distance_marker", "rbxassetid://0", "sfx") -- distance_marker.ogg
	SoundController.register("lap_horn", "rbxassetid://0", "sfx") -- lap_horn.ogg

	-- Fuel warnings — Audio/fuel/*.ogg
	SoundController.register("fuel_warning_25", "rbxassetid://0", "sfx") -- warning_25.ogg
	SoundController.register("fuel_warning_10", "rbxassetid://0", "sfx") -- warning_10.ogg
	SoundController.register("fuel_warning_5", "rbxassetid://0", "sfx") -- warning_5.ogg
	SoundController.register("fuel_empty", "rbxassetid://0", "sfx") -- empty_stall.ogg

	-- World pickup / HUD (reuse coin ding until a distinct asset is sourced)
	SoundController.register("currency", "rbxassetid://0", "sfx") -- coin_pickup.ogg (same file in Audio/)
end

function SoundController.init()
	registerDefaults()
	hydrateFromReplicatedStorageAudio()
	ensureSounds()
	SoundFacade.bind(SoundController)
	SoundController.setWorld("grasslands")
end

return SoundController
