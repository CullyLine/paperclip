--!strict
--[[
	StarterGui modules cannot require StarterPlayerScripts. Bootstrap binds the real
	VFXController implementation once the client loads.
]]

local impl: any = nil

local VFXFacade = {}

function VFXFacade.bind(module: any)
	impl = module
end

function VFXFacade.hatchReveal(petData: any)
	if impl then
		impl.hatchReveal(petData)
	end
end

function VFXFacade.rebirthFlash(rebirthCount: number)
	if impl then
		impl.rebirthFlash(rebirthCount)
	end
end

function VFXFacade.currencyPopup(currencyType: string, amount: number)
	if impl then
		impl.currencyPopup(currencyType, amount)
	end
end

function VFXFacade.skullDrop(amount: number)
	if impl then
		impl.skullDrop(amount)
	end
end

function VFXFacade.upgradeFlash()
	if impl then
		impl.upgradeFlash()
	end
end

function VFXFacade.boostOverlay(isActive: boolean)
	if impl and impl.boostOverlay then
		impl.boostOverlay(isActive)
	end
end

function VFXFacade.petOrbitGlow(petUid: string, model: Model?, rarity: string?, phase: string)
	if impl and impl.petOrbitGlow then
		impl.petOrbitGlow(petUid, model, rarity, phase)
	end
end

function VFXFacade.lapFlash(isPersonalBest: boolean)
	if impl and impl.lapFlash then
		impl.lapFlash(isPersonalBest)
	end
end

function VFXFacade.worldTransition(fromWorldId: string, toWorldId: string)
	if impl and impl.worldTransition then
		impl.worldTransition(fromWorldId, toWorldId)
	end
end

function VFXFacade.ambientStart()
	if impl and impl.ambientStart then
		impl.ambientStart()
	end
end

function VFXFacade.ambientStop()
	if impl and impl.ambientStop then
		impl.ambientStop()
	end
end

return VFXFacade
