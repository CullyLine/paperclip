--!strict
--[[
	StarterGui modules cannot require StarterPlayerScripts. SoundController binds
	the real implementation after the client loads (see Bootstrap.client).
]]

local impl: any = nil

local SoundFacade = {}

function SoundFacade.bind(module: any)
	impl = module
end

function SoundFacade.playOneShot(name: string)
	if impl then
		impl.playOneShot(name)
	end
end

return SoundFacade
