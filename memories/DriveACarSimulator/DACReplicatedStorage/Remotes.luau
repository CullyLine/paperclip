--!strict
--[[
	Central remote event/function registry.
	Server calls Remotes.init() once at startup to create all instances.
	Both server and client use Remotes.get() to retrieve them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local REMOTE_EVENTS = {
	"StartRun",
	"EndRun",
	"RunUpdate",

	"BuyCar",
	"EquipCar",
	"UpgradeStat",

	"BuyEgg",
	"HatchEgg",
	"EquipPet",
	"UnequipPet",
	"FusePets",
	"FusionResult",

	"Rebirth",

	"UnlockWorld",
	"ChangeWorld",

	"ClaimDailyReward",
	"ClaimBattlePassTier",
	"RedeemCode",

	"PurchaseGamePass",
	"PurchaseDevProduct",
	"ClientPromptGamePass",
	"ClientPromptDevProduct",

	"UpdateSettings",
	"TradeRequest",
	"TradeRespond",

	"CurrencyUpdate",
	"DataUpdate",
	"Notification",
	-- Robux / GamePass purchase confirmed (server → client celebration)
	"PurchaseCelebration",
	-- Full post-purchase thank-you overlay (server → client)
	"PurchaseComplete",
	-- Thank-you dismissed; server may flush queued SpendMilestone payloads (client → server)
	"PurchaseThankYouAck",
	"LaunchEventState",

	"EasterEggDiscovered",

	-- Leaderboard rank improved (server → client VFX)
	"RankUpNotification",

	-- First-time / spend / streak milestone ceremonies (server → client VFX)
	"FirstTimeCeremony",
	"SpendMilestone",
	"StreakMilestone",

	-- Client reports lane near-miss during a run; server grants combo-scaled coins (server → client echo for VFX)
	"NearMissClaim",

	-- Server-wide rare+ hatch social proof (server → all clients)
	"ServerDropFeed",

	"TutorialStep",
	"TutorialSkip",

	"AchievementUnlocked",
	"AchievementProgress",
	"MarkAchievementsSeen",

	"AdminCommand",
}

local REMOTE_FUNCTIONS = {
	"GetPlayerData",
	"GetLeaderboard",
	"GetPassFlags",
	"GetQuests",
	"GetAchievementData",
	"AdminAuth",
}

local remotesFolder: Folder? = nil

function Remotes.init()
	local folder = Instance.new("Folder")
	folder.Name = "DACRemotes"
	
	for _, name in REMOTE_EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	
	for _, name in REMOTE_FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	
	folder.Parent = ReplicatedStorage
	remotesFolder = folder
end

function Remotes.get(name: string): Instance
	if not remotesFolder then
		remotesFolder = ReplicatedStorage:WaitForChild("DACRemotes")
	end
	local remote = (remotesFolder :: Folder):FindFirstChild(name)
	assert(remote, `Remote '{name}' not found`)
	return remote
end

function Remotes.getEvent(name: string): RemoteEvent
	return Remotes.get(name) :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	return Remotes.get(name) :: RemoteFunction
end

return Remotes
