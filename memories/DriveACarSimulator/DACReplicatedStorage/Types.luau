--!strict

export type Currency = "coins" | "sandGranules" | "icycles" | "magmaCores" | "infinitium"

export type CarStats = {
	gas: number,
	power: number,
	speed: number,
}

export type EffectiveCarStats = CarStats & {
	vipExclusiveSkin: boolean,
}

export type OwnedCar = {
	id: string,
	gasLevel: number,
	powerLevel: number,
	speedLevel: number,
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
	highwayLength: number,
	unlockCost: number,
	unlockCurrency: Currency,
	coinMultiplier: number,
	description: string,
}

export type UpgradeCost = {
	baseCost: number,
	costMultiplier: number,
	currency: Currency,
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
}

export type DailyRewardData = {
	lastClaim: number,
	streak: number,
	lastClaimLostStreak: number?,
	-- Server: last applied DACDailyRewardAuth_v1 generation (POLA-519).
	authClaimGen: number?,
}

export type PlayerStats = {
	totalDistance: number,
	totalRebirths: number,
	totalEggsHatched: number,
	totalLaps: number,
}

export type RebirthStats = {
	gas: number,
	power: number,
	speed: number,
}

export type PlayerData = {
	coins: number,
	sandGranules: number,
	icycles: number,
	magmaCores: number,
	infinitium: number,

	cars: { [string]: OwnedCar },
	equippedCar: string,

	pets: { [string]: Pet },
	maxPetSlots: number,

	eggs: { [string]: number },

	rebirths: number,
	rebirthStats: RebirthStats,

	currentWorld: string,
	unlockedWorlds: { [string]: boolean },

	dailyReward: DailyRewardData,
	redeemedCodes: { [string]: boolean },
	settings: PlayerSettings,
	stats: PlayerStats,

	playtimeSecondsSinceBonus: number,
	lastRunOfDayBonusYday: number,
	starterPackPurchased: boolean,
	discoveredPets: { [string]: boolean },
}

return nil
