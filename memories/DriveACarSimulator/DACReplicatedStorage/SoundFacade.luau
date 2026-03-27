--!strict
--[[
	StarterGui modules cannot require StarterPlayerScripts. SoundController binds
	the real implementation after the client loads (see Bootstrap.local.luau).

	Placeholder / invalid rbxassetid handling (one-time Studio warns, dev-preview keys)
	lives in SoundController — this module only forwards to the bound impl.
]]

local impl: any = nil

local SoundFacade = {}

function SoundFacade.bind(module: any)
	impl = module
end

function SoundFacade.playOneShot(name: string, pitch: number?)
	if impl then
		impl.playOneShot(name, pitch)
	end
end

function SoundFacade.playOneShotPrefer(names: { string })
	if impl and impl.playOneShotPrefer then
		impl.playOneShotPrefer(names)
	end
end

function SoundFacade.playLoop(name: string, pitch: number?, volumeScale: number?)
	if impl and impl.playLoop then
		impl.playLoop(name, pitch, volumeScale)
	end
end

function SoundFacade.stopLoop(name: string, fadeDuration: number?)
	if impl and impl.stopLoop then
		impl.stopLoop(name, fadeDuration)
	end
end

function SoundFacade.setLoopPitch(name: string, pitch: number)
	if impl and impl.setLoopPitch then
		impl.setLoopPitch(name, pitch)
	end
end

function SoundFacade.setLoopVolume(name: string, volumeScale: number)
	if impl and impl.setLoopVolume then
		impl.setLoopVolume(name, volumeScale)
	end
end

function SoundFacade.setMenuModalOpen(open: boolean)
	if impl and impl.setMenuModalOpen then
		impl.setMenuModalOpen(open)
	end
end

function SoundFacade.setPayoutModalOpen(open: boolean)
	if impl and impl.setPayoutModalOpen then
		impl.setPayoutModalOpen(open)
	end
end

function SoundFacade.setModalOverlayOpen(open: boolean)
	if impl and impl.setModalOverlayOpen then
		impl.setModalOverlayOpen(open)
	end
end

function SoundFacade.setTutorialGameplayBlocked(open: boolean)
	if impl and impl.setTutorialGameplayBlocked then
		impl.setTutorialGameplayBlocked(open)
	end
end

function SoundFacade.isGameplayDucked(): boolean
	if impl and impl.isGameplayDucked then
		return impl.isGameplayDucked()
	end
	return false
end

--[[
	Optimistic client-side master mute: quiet confirm SFX + optional UI-bus duck on unmute.
	Call when the player toggles "Game sound" (before or with server patch).
]]
function SoundFacade.applyGameSoundMasterToggle(soundEnabled: boolean)
	if impl and impl.applyGameSoundMasterToggle then
		impl.applyGameSoundMasterToggle(soundEnabled)
	end
end

function SoundFacade.onWorldLeave(fromWorldId: string)
	if impl and impl.onWorldLeave then
		impl.onWorldLeave(fromWorldId)
	end
end

function SoundFacade.onWorldEnter(toWorldId: string)
	if impl and impl.onWorldEnter then
		impl.onWorldEnter(toWorldId)
	end
end

return SoundFacade
