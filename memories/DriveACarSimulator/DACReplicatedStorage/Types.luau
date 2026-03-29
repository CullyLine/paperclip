--!strict

export type Currency = "coins"

export type CarStats = {
	gas: number,
	power: number,
	acceleration: number,
}

export type OwnedCar = {
	id: string,
}

export type Pet = {
	uid: string,
	id: string,
	power: number,
	equipped: boolean,
}

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic"

export type EggDrop = {
	petId: string,
	rarity: Rarity,
	weight: number,
}

export type EggDefinition = {
	id: string,
	name: string,
	price: number,
	currency: Currency,
	worldId: string,
	drops: { EggDrop },
	modelName: string?,
}

export type CarDefinition = {
	id: string,
	name: string,
	baseStats: CarStats,
	price: number,
	currency: Currency,
	worldId: string,
	description: string,
	modelName: string?,
}

export type PetDefinition = {
	id: string,
	name: string,
	basePower: number,
	rarity: Rarity,
	description: string,
	modelName: string?,
}

export type WorldDefinition = {
	id: string,
	name: string,
	order: number,
	universeId: string,
	highwayLength: number,
	unlockCost: number,
	unlockCurrency: Currency,
	coinMultiplier: number,
	description: string,
}

export type GamePassDefinition = {
	id: string,
	name: string,
	robuxPrice: number,
	description: string,
	gamePassId: number,
}

export type DevProductDefinition = {
	id: string,
	name: string,
	robuxPrice: number,
	description: string,
	productId: number,
}

export type PlayerSettings = {
	autoCenter: boolean,
	otherPets: boolean,
	otherPetAnimations: boolean,
	tradeRequests: boolean,
	particles: boolean,
	sound: boolean,
	musicVolume: number,
	sfxVolume: number,
	graphicsQuality: number,
	steeringSensitivity: number,
	reducedMotion: boolean,
	particleDensity: number,
	showFps: boolean,
	petLock: boolean,
}

export type DailyRewardData = {
	lastClaim: number,
	streak: number,
	lastClaimLostStreak: number?,
	authClaimGen: number?,
}

export type PlayerStats = {
	totalDistance: number,
	totalRebirths: number,
	totalEggsHatched: number,
	totalLaps: number,
	totalCoinsEarned: number,
	totalPlaytimeSeconds: number,
}

export type RebirthUpgrades = {
	moreGas: number,
	moreCurrency: number,
	moreLuck: number,
	moreAcceleration: number,
	moreEggsAtOnce: number,
	moreInventorySpace: number,
	moreRebirthSkips: number,
}

export type PlayerData = {
	coins: number,
	gems: number,

	cars: { [string]: OwnedCar },
	equippedCar: string,

	pets: { [string]: Pet },
	maxPetSlots: number,

	eggs: { [string]: number },

	rebirths: number,
	rebirthTrainingBonus: number,
	trainedPower: number,
	rebirthUpgrades: RebirthUpgrades,

	currentWorld: string,
	unlockedWorlds: { [string]: boolean },

	dailyReward: DailyRewardData,
	redeemedCodes: { [string]: boolean },
	settings: PlayerSettings,
	stats: PlayerStats,

	potions: { [string]: number },

	playtimeSecondsSinceBonus: number,
	lastRunOfDayBonusYday: number,
	starterPackPurchased: boolean,
	discoveredPets: { [string]: boolean },
	totalRobuxSpent: number,
}

return nil
