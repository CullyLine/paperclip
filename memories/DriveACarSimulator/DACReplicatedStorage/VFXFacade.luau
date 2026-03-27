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

function VFXFacade.fusionReveal(payload: any)
	if impl and impl.fusionReveal then
		impl.fusionReveal(payload)
	end
end

function VFXFacade.rebirthFlash(rebirthCount: number, milestoneKey: string?, suppressTextLabels: boolean?)
	if impl then
		impl.rebirthFlash(rebirthCount, milestoneKey, suppressTextLabels)
	end
end

function VFXFacade.cameraShake(intensity: number, duration: number)
	if impl and impl.cameraShake then
		impl.cameraShake(intensity, duration)
	end
end

function VFXFacade.heavyCollisionImpact()
	if impl and impl.heavyCollisionImpact then
		impl.heavyCollisionImpact()
	end
end

function VFXFacade.currencyPopup(currencyType: string, amount: number, flavorLine: string?)
	if impl then
		impl.currencyPopup(currencyType, amount, flavorLine)
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

function VFXFacade.petEquipEntrance(petUid: string, model: Model?, rarity: string?)
	if impl and impl.petEquipEntrance then
		impl.petEquipEntrance(petUid, model, rarity)
	end
end

function VFXFacade.lapFlash(
	isPersonalBest: boolean,
	lapTimeSeconds: number?,
	lapDeltaSecondsFromBest: number?,
	lapDeltaSecondsFromLast: number?
)
	if impl and impl.lapFlash then
		impl.lapFlash(isPersonalBest, lapTimeSeconds, lapDeltaSecondsFromBest, lapDeltaSecondsFromLast)
	end
end

function VFXFacade.speedMilestone(speed: number)
	if impl and impl.speedMilestone then
		impl.speedMilestone(speed)
	end
end

function VFXFacade.failureFeedback(line: string, kind: string?)
	if impl and impl.failureFeedback then
		impl.failureFeedback(line, kind)
	end
end

function VFXFacade.worldTransition(fromWorldId: string, toWorldId: string, onFadeOutComplete: (() -> ())?)
	if impl and impl.worldTransition then
		impl.worldTransition(fromWorldId, toWorldId, onFadeOutComplete)
	end
end

function VFXFacade.finishWorldTravel(currentWorld: string)
	if impl and impl.finishWorldTravel then
		impl.finishWorldTravel(currentWorld)
	end
end

function VFXFacade.abortWorldTravel(restoreWorldId: string?)
	if impl and impl.abortWorldTravel then
		impl.abortWorldTravel(restoreWorldId)
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

function VFXFacade.runEndFanfare(isRecord: boolean, isRunOfDay: boolean?)
	if impl and impl.runEndFanfare then
		impl.runEndFanfare(isRecord, isRunOfDay)
	end
end

-- Slot-machine coins line: UI vignette pulse only (no camera FOV — RunEndFanfare owns FOV).
function VFXFacade.payoutStaggerBigLine()
	if impl and impl.payoutStaggerBigLine then
		impl.payoutStaggerBigLine()
	end
end

function VFXFacade.milestonePopup(text: string, style: string?)
	if impl and impl.milestonePopup then
		impl.milestonePopup(text, style)
	end
end

function VFXFacade.nearMissSpark(fromRight: boolean, comboStreak: number?)
	if impl and impl.nearMissSpark then
		impl.nearMissSpark(fromRight, comboStreak)
	end
end

function VFXFacade.speedRushOverlay(speed: number)
	if impl and impl.speedRushOverlay then
		impl.speedRushOverlay(speed)
	end
end

function VFXFacade.fuelPanic(gasPercent: number)
	if impl and impl.fuelPanic then
		impl.fuelPanic(gasPercent)
	end
end

function VFXFacade.purchaseCelebration(productType: string, tier: string?, carIdForCar: string?)
	if impl and impl.purchaseCelebration then
		impl.purchaseCelebration(productType, tier, carIdForCar)
	end
end

function VFXFacade.carUnlockCelebration(carId: string, carDisplayName: string)
	if impl and impl.carUnlockCelebration then
		impl.carUnlockCelebration(carId, carDisplayName)
	end
end

function VFXFacade.statLevelUp(statName: string, oldLevel: number, newLevel: number)
	if impl and impl.statLevelUp then
		impl.statLevelUp(statName, oldLevel, newLevel)
	end
end

function VFXFacade.questComplete(questTitle: string, rewardType: string, rewardAmount: number)
	if impl and impl.questComplete then
		impl.questComplete(questTitle, rewardType, rewardAmount)
	end
end

function VFXFacade.battlePassTierUp(newTier: number, isPremium: boolean, rewardName: string?)
	if impl and impl.battlePassTierUp then
		impl.battlePassTierUp(newTier, isPremium, rewardName)
	end
end

function VFXFacade.rewardChestBurst()
	if impl and impl.rewardChestBurst then
		impl.rewardChestBurst()
	end
end

function VFXFacade.codeRedeemConfettiBurst()
	if impl and impl.codeRedeemConfettiBurst then
		impl.codeRedeemConfettiBurst()
	end
end

function VFXFacade.leaderboardRankFanfare(payload: any)
	if impl and impl.leaderboardRankFanfare then
		impl.leaderboardRankFanfare(payload)
	end
end

function VFXFacade.firstRunEntrance()
	if impl and impl.firstRunEntrance then
		impl.firstRunEntrance()
	end
end

function VFXFacade.isFirstRunOfDay(): boolean
	if impl and impl.isFirstRunOfDay then
		return impl.isFirstRunOfDay()
	end
	return false
end

function VFXFacade.petIndexDiscovery(petId: string)
	if impl and impl.petIndexDiscovery then
		impl.petIndexDiscovery(petId)
	end
end

function VFXFacade.premiumWelcomeFanfare()
	if impl and impl.premiumWelcomeFanfare then
		impl.premiumWelcomeFanfare()
	end
end

function VFXFacade.serverDropFeedBanner(payload: any)
	if impl and impl.serverDropFeedBanner then
		impl.serverDropFeedBanner(payload)
	end
end

function VFXFacade.resetTravelFlashState()
	if impl and impl.resetTravelFlashState then
		impl.resetTravelFlashState()
	end
end

return VFXFacade
