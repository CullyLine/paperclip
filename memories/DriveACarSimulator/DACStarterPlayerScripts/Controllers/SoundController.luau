--!strict
--[[
	Client audio: categories (music / sfx / ambient), persistence from player settings,
	crossfading world themes, one-shot SFX, ambient loops per world.

	Sound IDs come from ReplicatedStorage.Audio: each registry key should match a Sound's Name
	(or optional StringValue holding rbxassetid://…). Uploads live in Studio only; see Audio/MANIFEST.md
	for the key ↔ source file map. Missing assets keep rbxassetid://0 and no-op at runtime; in Studio,
	invalid keys / zero IDs get one warn per key (see DEV_PREVIEW_PLACEHOLDER_KEYS to silence expected placeholders).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Constants = require(DAC:WaitForChild("Constants"))
local NotificationLaneBridge = require(DAC:WaitForChild("NotificationLaneBridge"))
local SoundFacade = require(DAC:WaitForChild("SoundFacade"))

export type SoundCategory = "music" | "sfx" | "ambient"

local SoundController = {}

-- Idempotent init: hot reload must not stack DescendantAdded / Destroying listeners.
local soundClientInitDone = false

local registry: {
	[string]: {
		soundId: string,
		category: SoundCategory,
	},
} = {}

local soundRoot: SoundGroup
-- Nested under soundRoot: duckBus (music + gameplay SFX) tweens down when modals open;
-- uiBus keeps panel/click cues clear. Product of group volumes (Roblox SoundGroup hierarchy).
local duckBus: SoundGroup
local uiBus: SoundGroup
local musicA: Sound
local musicB: Sound
local usingA = true
local currentMusicWorld: string? = nil
local ambientA: Sound
local ambientB: Sound
local usingAmbientA = true
local currentAmbientWorld: string? = nil
-- Single source for RS.Audio hot-reload re-apply (POLA-474 / POLA-563); avoids inferring from A/B buffer state.
local lastWorldBedId = "forest"

local sfxLoops: { [string]: Sound } = {}
local sfxLoopVolumeMul: { [string]: number } = {}

local masterEnabled = true
local musicVolume = 0.35
local sfxVolume = 0.25
local ambientMul = 0.5 -- ambient uses sfx bus, scaled for headroom vs SFX

local CROSSFADE_TIME = 0.85
-- Ambient is a texture bed — slightly faster crossfade than music; still overlap for no pops.
local AMBIENT_CROSSFADE_TIME = 0.62
-- WorldAtmosphereJuiceBible / MANIFEST: ambient leads the bed; music follows slightly (no hard pop).
local MUSIC_STAGGER_AFTER_AMBIENT_SEC = 0.12

-- Modal duck: smooth dip on gameplay bed (music, ambient, engine) while menus/payout read clearly.
-- Tween 0.2s, Quad InOut — panel/click sounds use uiBus and stay full relative to master trim.
-- Phase4NotificationLaneJuiceSpec §5.2: [C] trophy stingers ride duckBus with gameplay; they are
-- audibly reduced while [E] is open (achievement entrances are also deferred in AchievementController).
local MODAL_DUCK_MUL = 0.35
local MODAL_DUCK_TWEEN_SEC = 0.2

local menuModalOpen = false
local payoutModalOpen = false
-- Tutorial overlay: blocks driving input (event banner only ducks audio — see setModalOverlayOpen).
local tutorialGameplayBlocked = false
-- Tutorial overlay + event banner (and any other caller) can overlap; ref-count so duck stays until last closes.
local overlayModalRef = 0
local duckTween: Tween?
local uiMuteDuckTween: Tween?

-- Master mute toggle: very quiet UI blip; unmute ducks uiBus briefly (POLA-429).
local MUTE_TOGGLE_BEEP_MUL = 0.14
local UNMUTE_UI_DUCK_DOWN_SEC = 0.1
local UNMUTE_UI_DUCK_UP_SEC = 0.1

local AUDIO_WAIT_SECS = 8

--[[
	After `hydrateFromReplicatedStorageAudio`, copy real `soundId` from a sibling registry key
	into slots still `rbxassetid://0` so one-shots and loops play sensible audio until Board
	upload (POLA-95 / `Audio/MANIFEST.md`). RS.Audio hydration still wins when present.
]]
local PLACEHOLDER_SOUND_FALLBACKS: { [string]: string } = {
	cosmetic_select = "tab_switch",
	ui_quickbar_hover = "click",
	ui_quickbar_press = "click",
	ui_destructive_warn = "error",
	ui_destructive_confirm = "ui_confirm",
	tutorial_skip_open = "panel_open",
	tutorial_skip_confirm = "ui_confirm",
	lights_toggle_on = "tab_switch",
	lights_toggle_off = "tab_switch",
	ignition = "click",
	engine_start = "boost",
	spectator_enter = "panel_open",
	spectator_exit = "panel_close",
	lap_complete = "lap_horn",
	race_finish_fanfare = "quest_complete",
	horn_short = "lap_horn",
	horn_repeat = "lap_horn",
	fuel_low_warn = "fuel_warning",
	checkpoint_pass = "distance_marker",
	impact_heavy = "collision",
	coin_magnet_pickup = "coin_pickup",
	objective_ping = "notification",
	boost_ready = "boost",
	split_improve = "milestone",
	split_slower = "milestone",
	vehicle_reset = "error",
	vehicle_enter_prompt = "notification",
	vehicle_enter_success = "quest_complete",
	handbrake_on = "tab_switch",
	handbrake_off = "tab_switch",
}

-- Registry keys intentionally left at rbxassetid://0 until a Bard/POLA upload (no Studio warn spam).
local DEV_PREVIEW_PLACEHOLDER_KEYS: { [string]: boolean } = {
	ui_quickbar_hover = true,
	ui_quickbar_press = true,
	ui_destructive_warn = true,
	ui_destructive_confirm = true,
	tutorial_skip_open = true,
	tutorial_skip_confirm = true,
	lights_toggle_on = true,
	lights_toggle_off = true,
	ignition = true,
	engine_start = true,
	horn_short = true,
	horn_repeat = true,
	checkpoint_pass = true,
	objective_ping = true,
	boost_ready = true,
	split_improve = true,
	split_slower = true,
	rev_limiter = true,
	impact_heavy = true,
	coin_magnet_pickup = true,
	cosmetic_select = true,
	vehicle_reset = true,
	vehicle_enter_prompt = true,
	vehicle_enter_success = true,
	handbrake_on = true,
	handbrake_off = true,
}

local warnedPlayOneShotKey: { [string]: boolean } = {}
local warnedPlayLoopKey: { [string]: boolean } = {}
local warnedWorldMusicKey: { [string]: boolean } = {}
local warnedWorldAmbientKey: { [string]: boolean } = {}
local warnedPreferListKey: { [string]: boolean } = {}
local printedPlaceholderTable = false

local function isPlaceholderSoundId(soundId: string): boolean
	return soundId == "" or soundId == "rbxassetid://0"
end

local function warnOnce(
	store: { [string]: boolean },
	key: string,
	message: string
)
	if not RunService:IsStudio() or DEV_PREVIEW_PLACEHOLDER_KEYS[key] or store[key] then
		return
	end
	store[key] = true
	warn(message)
end

-- One-shots that must stay crisp over ducked gameplay (UI chrome + payout stingers).
local UI_ONE_SHOT_IDS: { [string]: boolean } = {
	panel_open = true,
	panel_close = true,
	click = true,
	ui_quickbar_hover = true,
	ui_quickbar_press = true,
	tab_switch = true,
	trophy_tab_swipe = true,
	cosmetic_select = true,
	ui_confirm = true,
	ui_destructive_warn = true,
	ui_destructive_confirm = true,
	tutorial_skip_open = true,
	tutorial_skip_confirm = true,
	mute_toggle = true,
	lights_toggle_on = true,
	lights_toggle_off = true,
	error = true,
	purchase_fail = true,
	alert = true,
	payout_card_pop = true,
	payout_badge_tick = true,
	payout_tick = true,
	payout_big = true,
	payout_run_of_day = true,
	payout_tier_up = true,
	code_redeem_success = true,
}

-- Board-uploaded sounds live in ReplicatedStorage.Audio (TOS-approved, ready to use).
-- hydrateFromReplicatedStorageAudio() matches Sound.Name → registry key at init.
-- If a Board sound uses a different Name than our key, add a mapping here.
local AUDIO_NAME_ALIASES: { [string]: string } = {
	-- music_forest = "forest",
}

local function soundIdFromInstance(inst: Instance): string?
	if inst:IsA("Sound") then
		local id = inst.SoundId
		if not isPlaceholderSoundId(id) then
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

local function applyPlaceholderSoundFallbacks()
	for key, fallbackKey in PLACEHOLDER_SOUND_FALLBACKS do
		local reg = registry[key]
		local fb = registry[fallbackKey]
		if reg and fb and reg.category == "sfx" and fb.category == "sfx" then
			if isPlaceholderSoundId(reg.soundId) and not isPlaceholderSoundId(fb.soundId) then
				reg.soundId = fb.soundId
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

local function shouldDuckGameplay(): boolean
	return menuModalOpen or payoutModalOpen or overlayModalRef > 0
end

local ensureSounds

local function tweenDuckBusToMatchModal()
	ensureSounds()
	if not duckBus then
		return
	end
	local target = if shouldDuckGameplay() then MODAL_DUCK_MUL else 1
	if duckTween then
		duckTween:Cancel()
	end
	-- Quad InOut: gentle ease both ways (matches UI panel scale tweens ~0.15–0.2s).
	duckTween = TweenService:Create(
		duckBus,
		TweenInfo.new(MODAL_DUCK_TWEEN_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Volume = target }
	)
	duckTween:Play()
end

function SoundController.setMenuModalOpen(open: boolean)
	menuModalOpen = open
	tweenDuckBusToMatchModal()
end

function SoundController.isPayoutModalOpen(): boolean
	return payoutModalOpen
end

function SoundController.setPayoutModalOpen(open: boolean)
	local wasOpen = payoutModalOpen
	payoutModalOpen = open
	tweenDuckBusToMatchModal()
	if wasOpen and not open then
		NotificationLaneBridge.resume()
	end
end

function SoundController.setModalOverlayOpen(open: boolean)
	if open then
		overlayModalRef += 1
	else
		overlayModalRef = math.max(0, overlayModalRef - 1)
	end
	tweenDuckBusToMatchModal()
end

function SoundController.setTutorialGameplayBlocked(open: boolean)
	tutorialGameplayBlocked = open
end

function SoundController.isTutorialGameplayBlocked(): boolean
	return tutorialGameplayBlocked
end

function SoundController.isGameplayDucked(): boolean
	return shouldDuckGameplay()
end

local function resetModalDuckState()
	menuModalOpen = false
	payoutModalOpen = false
	tutorialGameplayBlocked = false
	overlayModalRef = 0
	if duckBus then
		if duckTween then
			duckTween:Cancel()
		end
		duckBus.Volume = 1
	end
end

local function oneShotBusForId(name: string): SoundGroup
	if UI_ONE_SHOT_IDS[name] then
		return uiBus
	end
	return duckBus
end

ensureSounds = function()
	if soundRoot then
		return
	end
	soundRoot = Instance.new("SoundGroup")
	soundRoot.Name = "DACSounds"
	soundRoot.Volume = 0.1
	soundRoot.Parent = SoundService

	duckBus = Instance.new("SoundGroup")
	duckBus.Name = "DACDuckBus"
	duckBus.Volume = 1
	duckBus.Parent = soundRoot

	uiBus = Instance.new("SoundGroup")
	uiBus.Name = "DACUI"
	uiBus.Volume = 1
	uiBus.Parent = soundRoot

	musicA = Instance.new("Sound")
	musicA.Name = "MusicA"
	musicA.Looped = true
	musicA.Volume = 0
	musicA.SoundGroup = duckBus
	musicA.Parent = duckBus

	musicB = Instance.new("Sound")
	musicB.Name = "MusicB"
	musicB.Looped = true
	musicB.Volume = 0
	musicB.SoundGroup = duckBus
	musicB.Parent = duckBus

	ambientA = Instance.new("Sound")
	ambientA.Name = "AmbientA"
	ambientA.Looped = true
	ambientA.Volume = 0
	ambientA.SoundGroup = duckBus
	ambientA.Parent = duckBus

	ambientB = Instance.new("Sound")
	ambientB.Name = "AmbientB"
	ambientB.Looped = true
	ambientB.Volume = 0
	ambientB.SoundGroup = duckBus
	ambientB.Parent = duckBus
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
	if isPlaceholderSoundId(reg.soundId) then
		warnOnce(
			warnedPlayLoopKey,
			name,
			`[SoundController] playLoop: "{name}" is rbxassetid 0 / empty. See Audio/MANIFEST.md + ReplicatedStorage.Audio hydration.`
		)
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
	s.SoundGroup = duckBus
	s.Parent = duckBus
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
	if not isPlaceholderSoundId(reg.soundId) then
		return reg.soundId, reg.category
	end
	-- ActionBar quick slots: prefer tactile UI keys until dedicated `ui_quickbar_*` uploads hydrate (MANIFEST ui/).
	if name == "ui_quickbar_hover" then
		local clickFb = registry["click"]
		if clickFb and clickFb.category == "sfx" and not isPlaceholderSoundId(clickFb.soundId) then
			return clickFb.soundId, clickFb.category
		end
	elseif name == "ui_quickbar_press" then
		local tabFb = registry["tab_switch"]
		if tabFb and tabFb.category == "sfx" and not isPlaceholderSoundId(tabFb.soundId) then
			return tabFb.soundId, tabFb.category
		end
	end
	local fb = registry["notification"]
	if fb and fb.category == "sfx" and not isPlaceholderSoundId(fb.soundId) then
		return fb.soundId, fb.category
	end
	return nil, nil
end

function SoundController.playOneShot(name: string, pitch: number?)
	ensureSounds()
	local reg = registry[name]
	local soundId, cat = resolveSfxSoundId(name)
	if not soundId or not cat then
		if not reg then
			warnOnce(
				warnedPlayOneShotKey,
				name,
				`[SoundController] playOneShot: unknown registry key "{name}" (add SoundController.register or fix typo)`
			)
		elseif reg.category ~= "sfx" then
			warnOnce(
				warnedPlayOneShotKey,
				name,
				`[SoundController] playOneShot: "{name}" is category "{reg.category}", not sfx`
			)
		elseif isPlaceholderSoundId(reg.soundId) then
			warnOnce(
				warnedPlayOneShotKey,
				name,
				`[SoundController] playOneShot: "{name}" is rbxassetid 0 / empty and notification fallback is invalid. See Audio/MANIFEST.md`
			)
		else
			warnOnce(warnedPlayOneShotKey, name, `[SoundController] playOneShot: "{name}" did not resolve (unexpected).`)
		end
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
	local bus = oneShotBusForId(name)
	s.SoundGroup = bus
	s.Parent = bus
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
	local joined = table.concat(names, " | ")
	warnOnce(
		warnedPreferListKey,
		joined,
		`[SoundController] playOneShotPrefer: no valid SFX for candidates: {joined}`
	)
end

local function playMuteToggleBeep()
	ensureSounds()
	local soundId, cat = resolveSfxSoundId("mute_toggle")
	if not soundId or cat ~= "sfx" then
		return
	end
	local vol = categoryVolume("sfx") * MUTE_TOGGLE_BEEP_MUL
	if vol < 0.0001 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.PlaybackSpeed = 1
	s.Volume = vol
	s.SoundGroup = uiBus
	s.Parent = uiBus
	s:Play()
	Debris:AddItem(s, 4)
end

local function duckUiBusAfterUnmute()
	ensureSounds()
	if not uiBus then
		return
	end
	if uiMuteDuckTween then
		uiMuteDuckTween:Cancel()
		uiMuteDuckTween = nil
	end
	local low = 0.32
	uiMuteDuckTween = TweenService:Create(
		uiBus,
		TweenInfo.new(UNMUTE_UI_DUCK_DOWN_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = low }
	)
	local downDone: RBXScriptConnection?
	downDone = uiMuteDuckTween.Completed:Connect(function()
		if downDone then
			downDone:Disconnect()
			downDone = nil
		end
		uiMuteDuckTween = TweenService:Create(
			uiBus,
			TweenInfo.new(UNMUTE_UI_DUCK_UP_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Volume = 1 }
		)
		uiMuteDuckTween:Play()
	end)
	uiMuteDuckTween:Play()
end

--[[
	Call from Settings when the player toggles master audio — updates volumes immediately,
	plays a very quiet confirm blip, and briefly ducks uiBus on unmute (POLA-429).
]]
function SoundController.applyGameSoundMasterToggle(soundEnabled: boolean)
	if soundEnabled then
		SoundController.applySettings({ sound = true })
		playMuteToggleBeep()
		-- Let the confirm blip lead briefly, then duck UI bus for ~200ms (POLA-429).
		task.delay(0.04, duckUiBusAfterUnmute)
	else
		playMuteToggleBeep()
		SoundController.applySettings({ sound = false })
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
	local ambActive = if usingAmbientA then ambientA else ambientB
	if ambActive.IsPlaying and currentAmbientWorld then
		ambActive.Volume = av
	end

	local sfxV = categoryVolume("sfx")
	for loopName, snd in sfxLoops do
		local mul = sfxLoopVolumeMul[loopName] or 0.55
		snd.Volume = sfxV * mul
	end
end

function SoundController.onWorldLeave(_fromWorldId: string)
	ensureSounds()
	local mv = categoryVolume("music")
	local av = categoryVolume("ambient")
	if mv >= 0.001 then
		for _, s in { musicA, musicB } do
			if s.IsPlaying and s.Volume > 0.001 then
				tweenVolume(s, mv * 0.35, 0.22)
			end
		end
	end
	if av >= 0.001 then
		for _, s in { ambientA, ambientB } do
			if s.IsPlaying and s.Volume > 0.001 then
				tweenVolume(s, av * 0.35, 0.22)
			end
		end
	end
end

function SoundController.onWorldEnter(toWorldId: string)
	SoundController.setWorld(toWorldId)
end

function SoundController.setWorld(worldId: string)
	ensureSounds()
	lastWorldBedId = worldId

	local mv = categoryVolume("music")
	local av = categoryVolume("ambient")
	local mkey = `music_{worldId}`
	local akey = `ambient_{worldId}`
	local mreg = registry[mkey]
	local areg = registry[akey]
	if mreg and isPlaceholderSoundId(mreg.soundId) then
		warnOnce(
			warnedWorldMusicKey,
			mkey,
			`[SoundController] setWorld: "{mkey}" is rbxassetid 0 / empty. Audio/MANIFEST.md music/ + POLA-298.`
		)
	end
	if areg and isPlaceholderSoundId(areg.soundId) then
		warnOnce(
			warnedWorldAmbientKey,
			akey,
			`[SoundController] setWorld: "{akey}" is rbxassetid 0 / empty. Audio/MANIFEST.md ambient/ + POLA-298.`
		)
	end

	local hasMusic = mreg ~= nil and not isPlaceholderSoundId(mreg.soundId)
	local hasAmbient = areg ~= nil and not isPlaceholderSoundId(areg.soundId)

	local function fadeOutMusicBed(dur: number)
		for _, s in { musicA, musicB } do
			if s.IsPlaying and s.Volume > 0.001 then
				tweenVolume(s, 0, dur)
			end
		end
		task.delay(dur + 0.05, function()
			musicA:Stop()
			musicB:Stop()
			musicA.Volume = 0
			musicB.Volume = 0
		end)
		currentMusicWorld = nil
	end

	local function fadeOutAmbientBed(dur: number)
		for _, s in { ambientA, ambientB } do
			if s.IsPlaying and s.Volume > 0.001 then
				tweenVolume(s, 0, dur)
			end
		end
		task.delay(dur + 0.05, function()
			ambientA:Stop()
			ambientB:Stop()
			ambientA.Volume = 0
			ambientB.Volume = 0
		end)
		currentAmbientWorld = nil
	end

	local function runMusicLayer()
		if hasMusic then
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
		elseif currentMusicWorld ~= nil then
			fadeOutMusicBed(CROSSFADE_TIME)
		end
	end

	local function runAmbientLayer()
		if hasAmbient then
			if currentAmbientWorld == nil then
				ambientA.SoundId = areg.soundId
				ambientA.Volume = av
				ambientA:Play()
				ambientB:Stop()
				ambientB.Volume = 0
				usingAmbientA = true
				currentAmbientWorld = worldId
			elseif worldId == currentAmbientWorld then
				local active = if usingAmbientA then ambientA else ambientB
				active.Volume = av
			else
				local outgoing = if usingAmbientA then ambientA else ambientB
				local incoming = if usingAmbientA then ambientB else ambientA
				incoming.SoundId = areg.soundId
				incoming.Volume = 0
				incoming:Play()
				tweenVolume(outgoing, 0, AMBIENT_CROSSFADE_TIME)
				tweenVolume(incoming, av, AMBIENT_CROSSFADE_TIME)
				task.delay(AMBIENT_CROSSFADE_TIME + 0.05, function()
					outgoing:Stop()
				end)
				usingAmbientA = not usingAmbientA
				currentAmbientWorld = worldId
			end
		elseif currentAmbientWorld ~= nil then
			fadeOutAmbientBed(AMBIENT_CROSSFADE_TIME)
		end
	end

	local volumeOnlySameWorld = currentMusicWorld == worldId and currentAmbientWorld == worldId
	local stagger = hasMusic and hasAmbient and not volumeOnlySameWorld

	if stagger then
		runAmbientLayer()
		task.delay(MUSIC_STAGGER_AFTER_AMBIENT_SEC, runMusicLayer)
	else
		runAmbientLayer()
		runMusicLayer()
	end
end

local function registerDefaults()
	-- All IDs sourced from game.ReplicatedStorage.Audio (TOS-approved uploads).
	-- Hydration still runs as a fallback if names match registry keys.
	-- Key names align with Audio/MANIFEST.md paths (engines/, music/, ambient/, …).

	-- World music beds — MANIFEST `music/*.ogg`; POLA-298 world-bed Splice candidates (Bard mood alignment)
	SoundController.register("music_forest", "rbxassetid://1841647093", "music") -- forest.ogg — Life in an Elevator
	SoundController.register("music_desert", "rbxassetid://122720386196973", "music") -- desert.ogg — Dealership (60s)
	SoundController.register("music_ice", "rbxassetid://7640700658", "music") -- ice.ogg — Witches' Brew (133s)
	SoundController.register("music_volcano", "rbxassetid://97844915150974", "music") -- volcano.ogg — Rhythm Junkie (103s)
	SoundController.register("music_space", "rbxassetid://0", "music") -- space.ogg — TBD

	-- World ambience — MANIFEST `ambient/*.ogg`; POLA-298 ambient candidates
	SoundController.register("ambient_forest", "rbxassetid://73798751154555", "ambient") -- forest_amb.ogg — Lake
	SoundController.register("ambient_desert", "rbxassetid://9059618023", "ambient") -- desert_amb.ogg — Defiance_Ambiance03
	SoundController.register("ambient_ice", "rbxassetid://11876250716", "ambient") -- ice_amb.ogg — snow
	SoundController.register("ambient_volcano", "rbxassetid://2843658663", "ambient") -- volcano_amb.ogg — City Sounds
	SoundController.register("ambient_space", "rbxassetid://0", "ambient") -- space_amb.ogg — TBD

	-- Engine idle loops — MANIFEST `engines/*.ogg`
	SoundController.register("engine_buggy", "rbxassetid://12843280490", "sfx") -- buggy_idle.ogg — idle (generic)
	SoundController.register("engine_sedan", "rbxassetid://8836845570", "sfx") -- Audi R8 Idle
	SoundController.register("engine_racer", "rbxassetid://130983335056535", "sfx") -- V10
	SoundController.register("engine_supercar", "rbxassetid://7136339316", "sfx") -- Aventador Low
	SoundController.register("engine_wind", "rbxassetid://11876250654", "sfx") -- road wind layer (MANIFEST driving/ adj.)
	-- One-shot ignition (POLA-436): key turn + starter catch before idle loop ramps; placeholders until `engines/` upload
	SoundController.register("ignition", "rbxassetid://0", "sfx")
	SoundController.register("engine_start", "rbxassetid://0", "sfx")

	-- UI — MANIFEST `ui/*.ogg` (tab_switch, panel_*, click, …)
	SoundController.register("click", "rbxassetid://10630778959", "sfx") -- Click
	SoundController.register("ui_quickbar_hover", "rbxassetid://0", "sfx") -- ActionBar / MenuHub quick slots (hover; HUD polish)
	SoundController.register("ui_quickbar_press", "rbxassetid://0", "sfx") -- ActionBar / MenuHub quick slots (press; HUD polish)
	SoundController.register("near_miss", "rbxassetid://14753859187", "sfx") -- bov_1 (whoosh)
	SoundController.register("combo_break", "rbxassetid://14755055417", "sfx") -- low_med_off (engine cut)
	SoundController.register("ui_whoosh", "rbxassetid://10849970849", "sfx") -- SpawnParticle (swoosh)
	SoundController.register("purchase", "rbxassetid://9545920468", "sfx") -- GoldCorn (cha-ching)
	SoundController.register("purchase_thankyou_buildup", "rbxassetid://9538232720", "sfx") -- PE-Electrical_BW.32224 (riser)
	SoundController.register("purchase_thankyou_reveal", "rbxassetid://9545920468", "sfx") -- GoldCorn
	SoundController.register("purchase_thankyou_reveal_vip", "rbxassetid://9660107771", "sfx") -- ClubSmash
	SoundController.register("purchase_thankyou_reveal_mega", "rbxassetid://9660466869", "sfx") -- Stomp (heavy impact)
	SoundController.register("purchase_fail", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179 (error buzz)
	SoundController.register("error", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179
	SoundController.register("tab_switch", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("panel_open", "rbxassetid://7938564577", "sfx") -- WarmPluck
	SoundController.register("panel_close", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("equip_item", "rbxassetid://9591690518", "sfx") -- Absorb
	SoundController.register("cosmetic_select", "rbxassetid://0", "sfx") -- Garage Cosmetics car pick (alias tab_switch / equip_item in RS.Audio — MANIFEST ui/cosmetic_select)
	SoundController.register("world_unlock", "rbxassetid://9460707764", "sfx") -- BustOpen
	SoundController.register("world_travel", "rbxassetid://12842999193", "sfx") -- startup
	SoundController.register("world_portal_confirm", "rbxassetid://7938634444", "sfx") -- portal / travel UI confirm (alias ui_sound_12 until ui/world_portal_confirm.ogg — MANIFEST)
	SoundController.register("notification", "rbxassetid://10630729494", "sfx") -- UIBlip
	SoundController.register("collection_discover", "rbxassetid://7938564577", "sfx") -- Pet index new species (WarmPluck; alias until ui/collection_discover.ogg — MANIFEST)
	SoundController.register("quest_progress", "rbxassetid://7938634444", "sfx") -- ui_sound_12
	SoundController.register("quest_complete", "rbxassetid://6971833728", "sfx") -- Item Collect (Bootstrap quest toast)
	SoundController.register("quest_claim_fanfare", "rbxassetid://6971833728", "sfx") -- Quest row turn-in (alias quest_complete / level_up until dedicated upload)
	SoundController.register("ui_confirm", "rbxassetid://7938634444", "sfx") -- ui_sound_12
	-- Master mute / unmute confirm (very quiet; aliases `notification` / UIBlip — POLA-429)
	SoundController.register("mute_toggle", "rbxassetid://10630729494", "sfx")
	-- Destructive confirm modals (sell/fuse/rebirth) — POLA-410; placeholder until `ui/ui_destructive_*.ogg` upload
	SoundController.register("ui_destructive_warn", "rbxassetid://0", "sfx")
	SoundController.register("ui_destructive_confirm", "rbxassetid://0", "sfx")
	SoundController.register("cha_ching", "rbxassetid://10849997662", "sfx") -- Coin
	SoundController.register("code_redeem_success", "rbxassetid://9545920468", "sfx") -- promo code redeem fanfare (alias purchase / GoldCorn until ui/code_redeem_success.ogg — MANIFEST)
	SoundController.register("level_up", "rbxassetid://6971833728", "sfx") -- Item Collect
	SoundController.register("bp_tier_claim", "rbxassetid://6971833728", "sfx") -- Battle Pass tier banner (alias level_up until dedicated upload)
	SoundController.register("bp_xp_tick", "rbxassetid://7938634444", "sfx") -- BP XP bar tick (alias quest_progress / ui_sound_12)

	-- Spectator / follow camera (POLA-405) — no shipped spectator mode yet; keys reserved for future enter/exit SFX
	SoundController.register("spectator_enter", "rbxassetid://0", "sfx")
	SoundController.register("spectator_exit", "rbxassetid://0", "sfx")

	-- Headlights / high-beam HUD (POLA-420); `DrivingHUD` + optional `DACMain.PlayerInfo.DrivingUI.LightsToggle`
	SoundController.register("lights_toggle_on", "rbxassetid://0", "sfx")
	SoundController.register("lights_toggle_off", "rbxassetid://0", "sfx")
	-- POLA-457: cosmetic handbrake/drift engage (DrivingController + optional HandbrakeHud)
	SoundController.register("handbrake_on", "rbxassetid://0", "sfx")
	SoundController.register("handbrake_off", "rbxassetid://0", "sfx")

	-- Egg hatch (ascending intensity by rarity) — MANIFEST `hatch/*.ogg`
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

	-- Rebirth fanfare layers — MANIFEST `rebirth/*.ogg`
	SoundController.register("rebirth", "rbxassetid://9660107771", "sfx") -- ClubSmash (full sting)
	SoundController.register("rebirth_riser", "rbxassetid://9538232720", "sfx") -- PE-Electrical_BW.32224
	SoundController.register("rebirth_whoosh", "rbxassetid://9146096134", "sfx") -- StartedBoosting
	SoundController.register("rebirth_boom", "rbxassetid://9660482478", "sfx") -- Explosion
	SoundController.register("rebirth_confetti", "rbxassetid://9545920468", "sfx") -- GoldCorn

	-- Driving HUD
	SoundController.register("milestone", "rbxassetid://7938634444", "sfx") -- ui_sound_12
	SoundController.register("combo", "rbxassetid://9554965517", "sfx") -- blinky
	-- POLA-668: temp blinky; dedicated asset `driving/combo_ding.ogg` in Audio/MANIFEST — near-miss streak ding; pitch ramp in `VFXController.nearMissRecover`
	SoundController.register("combo_ding", "rbxassetid://9554965517", "sfx")
	SoundController.register("speed_tier", "rbxassetid://9146096134", "sfx") -- StartedBoosting
	SoundController.register("fuel_warning", "rbxassetid://9554965517", "sfx") -- blinky
	-- Full fuel / segment recharge ping (DrivingHUD; placeholder until MANIFEST upload)
	SoundController.register("boost_ready", "rbxassetid://0", "sfx")
	SoundController.register("alert", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179
	SoundController.register("fusion", "rbxassetid://9591690518", "sfx") -- Absorb

	-- Driving SFX — MANIFEST `driving/*.ogg`
	SoundController.register("screech", "rbxassetid://11864334285", "sfx") -- drift
	SoundController.register("boost", "rbxassetid://9146096251", "sfx") -- Boosting
	-- POLA-438: optional tick loop when speed ~ run cap (HUD redline proxy); placeholder until driving/rev_limiter.ogg
	SoundController.register("rev_limiter", "rbxassetid://0", "sfx")
	SoundController.register("collision", "rbxassetid://9575596194", "sfx") -- Impact
	SoundController.register("impact_heavy", "rbxassetid://0", "sfx") -- POLA-414 high-speed barrier hit; upload to MANIFEST driving/
	SoundController.register("coin_pickup", "rbxassetid://10849997662", "sfx") -- Coin
	-- World→HUD magnet streak (POLA-417); placeholder until `driving/coin_magnet_pickup.ogg` in MANIFEST
	SoundController.register("coin_magnet_pickup", "rbxassetid://0", "sfx")
	SoundController.register("distance_marker", "rbxassetid://7938634444", "sfx") -- ui_sound_12
	SoundController.register("lap_horn", "rbxassetid://14753859187", "sfx") -- bov_1 (legacy; lap juice uses lap_complete)
	SoundController.register("checkpoint_pass", "rbxassetid://0", "sfx") -- MANIFEST driving/checkpoint_pass — sector ping (placeholder)
	-- POLA-407: optional nav ping on tutorial step advance (debounced in TutorialOverlay); placeholder until upload
	SoundController.register("objective_ping", "rbxassetid://0", "sfx")
	SoundController.register("lap_complete", "rbxassetid://0", "sfx") -- MANIFEST driving/lap_complete — lap fanfare (placeholder; aliases lap_horn in Studio)
	-- POLA-452: primary sting for lap line / finish moment; `playOneShotPrefer` tries this before lap_complete
	SoundController.register("race_finish_fanfare", "rbxassetid://0", "sfx") -- MANIFEST driving/race_finish_fanfare — podium fanfare (placeholder)
	-- Lap split delta (POLA-450): vs last lap / PB; placeholders until driving/split_*.ogg
	SoundController.register("split_improve", "rbxassetid://0", "sfx")
	SoundController.register("split_slower", "rbxassetid://0", "sfx")
	SoundController.register("lap_pb_chime", "rbxassetid://7938634444", "sfx") -- ui_sound_12 (bell phrase TBD — DrivingVFXDesignSpec)
	-- Player horn (POLA-425): short on press, capped repeat while held — MANIFEST `driving/horn_*.ogg`
	SoundController.register("horn_short", "rbxassetid://0", "sfx")
	SoundController.register("horn_repeat", "rbxassetid://0", "sfx")
	-- POLA-442: reserved for a future manual recover / flip control + UI punch; not played yet (no control)
	SoundController.register("vehicle_reset", "rbxassetid://0", "sfx")
	-- POLA-447: lobby near-start ring + run begin sting (no ProximityPrompt / VehicleSeat — see MANIFEST)
	SoundController.register("vehicle_enter_prompt", "rbxassetid://0", "sfx")
	SoundController.register("vehicle_enter_success", "rbxassetid://0", "sfx")

	-- Fuel warnings — MANIFEST `fuel/*.ogg`
	SoundController.register("fuel_warning_25", "rbxassetid://9554965517", "sfx") -- blinky (gentle beep)
	SoundController.register("fuel_warning_10", "rbxassetid://9538241258", "sfx") -- PE-Electrical_BW.32179
	SoundController.register("fuel_warning_5", "rbxassetid://9538232720", "sfx") -- PE-Electrical_BW.32224
	-- POLA-443: soft periodic HUD chirp while 5–20% fuel (DrivingHUD; max once / 8s)
	SoundController.register("fuel_low_warn", "rbxassetid://0", "sfx")
	SoundController.register("fuel_empty", "rbxassetid://14755055417", "sfx") -- low_med_off (engine stall)

	-- Premium welcome
	SoundController.register("premium_welcome", "rbxassetid://9545920468", "sfx") -- GoldCorn

	-- World pickup / HUD
	SoundController.register("currency", "rbxassetid://10849997662", "sfx") -- Coin

	-- Event banner
	SoundController.register("event_fanfare", "rbxassetid://9460707764", "sfx") -- BustOpen
	SoundController.register("event_countdown_tick", "rbxassetid://10630729494", "sfx") -- UIBlip — one-shot on <1h / <10m / <5m threshold (EventBanner; alias notification)

	-- Tutorial
	SoundController.register("tutorial_step", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("tutorial_complete", "rbxassetid://6971833728", "sfx") -- Item Collect
	SoundController.register("tutorial_skip_open", "rbxassetid://0", "sfx") -- Skip confirm modal opens (POLA-455)
	SoundController.register("tutorial_skip_confirm", "rbxassetid://0", "sfx") -- Player confirms tutorial skip (POLA-455)

	-- Payout panel
	SoundController.register("payout_card_pop", "rbxassetid://9546777688", "sfx") -- Bubble
	SoundController.register("payout_badge_tick", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("payout_tick", "rbxassetid://9660507545", "sfx") -- Tap — staggered stat line (POLA-367)
	SoundController.register("payout_big", "rbxassetid://10849997662", "sfx") -- Coin — coins line climax (distinct from runEndFanfare purchase)
	SoundController.register("payout_run_of_day", "rbxassetid://7938564577", "sfx") -- WarmPluck
	SoundController.register("payout_tier_up", "rbxassetid://9545920468", "sfx") -- GoldCorn

	-- Trophy
	SoundController.register("trophy_bronze", "rbxassetid://9660507545", "sfx") -- Tap
	SoundController.register("trophy_tab_swipe", "rbxassetid://10849970849", "sfx") -- SpawnParticle (tab underline whoosh; placeholder ok)
	SoundController.register("trophy_silver", "rbxassetid://7938564577", "sfx") -- WarmPluck
	SoundController.register("trophy_gold", "rbxassetid://9545920468", "sfx") -- GoldCorn
	SoundController.register("trophy_diamond", "rbxassetid://9660107771", "sfx") -- ClubSmash
	SoundController.register("trophy_total_completion", "rbxassetid://6971833728", "sfx") -- Item Collect
end

-- Studio-only: one print per session listing registry rows still at rbxassetid 0 after hydration.
local function maybePrintPlaceholderRegistryTable()
	if not RunService:IsStudio() or printedPlaceholderTable or not Constants.DEBUG_BOOT_LOG then
		return
	end
	printedPlaceholderTable = true
	local lines = {}
	for key, reg in registry do
		if isPlaceholderSoundId(reg.soundId) and not DEV_PREVIEW_PLACEHOLDER_KEYS[key] then
			table.insert(lines, `  {key}  [{reg.category}]`)
		end
	end
	if #lines == 0 then
		return
	end
	table.sort(lines)
	print(
		"[SoundController] Placeholder audio (rbxassetid 0 / empty). See Audio/MANIFEST.md + POLA-298.\n"
			.. table.concat(lines, "\n")
	)
end

--[[
	When Studio uploads replace placeholders under ReplicatedStorage.Audio, re-resolve IDs
	without restarting the client (POLA-471 hot-reload).
]]
local function wireReplicatedStorageAudioHotReload()
	local audioRoot = ReplicatedStorage:FindFirstChild("Audio")
	if not audioRoot then
		return
	end
	local debounceToken = 0
	local function scheduleRehydrate()
		debounceToken += 1
		local t = debounceToken
		task.delay(0.35, function()
			if t ~= debounceToken then
				return
			end
			hydrateFromReplicatedStorageAudio()
			applyPlaceholderSoundFallbacks()
			SoundController.setWorld(lastWorldBedId)
		end)
	end
	audioRoot.DescendantAdded:Connect(scheduleRehydrate)
end

function SoundController.init()
	if soundClientInitDone then
		return
	end
	soundClientInitDone = true

	registerDefaults()
	hydrateFromReplicatedStorageAudio()
	applyPlaceholderSoundFallbacks()
	wireReplicatedStorageAudioHotReload()
	ensureSounds()
	SoundFacade.bind(SoundController)
	SoundController.setWorld("forest")
	task.defer(maybePrintPlaceholderRegistryTable)

	Players.LocalPlayer.Destroying:Connect(function()
		resetModalDuckState()
	end)
end

return SoundController
