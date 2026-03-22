--!strict
--[[
	StarterGui modules cannot require StarterPlayerScripts. SoundController binds
	the real implementation after the client loads (see Bootstrap.local.luau).
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

return SoundFacade
