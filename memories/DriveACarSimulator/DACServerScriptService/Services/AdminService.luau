--!strict
--[[
	Founder/admin chat commands: /admin <subcommand> [args]
	Authorization: Studio (all), hardcoded UserIds, or optional Roblox group rank.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Utils = require(DAC:WaitForChild("Utils"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local UpgradeConfig = require(DAC:WaitForChild("Config"):WaitForChild("UpgradeConfig"))
local BattlePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local GamePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("GamePassConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local _dACRunService: any = nil
local _questService: any = nil
local _gamePassService: any = nil
local _battlePassService: any = nil

local function getDACRunService()
	if not _dACRunService then _dACRunService = require(script.Parent:WaitForChild("RunService")) end
	return _dACRunService
end
local function getQuestService()
	if not _questService then _questService = require(script.Parent:WaitForChild("QuestService")) end
	return _questService
end
local function getGamePassService()
	if not _gamePassService then _gamePassService = require(script.Parent:WaitForChild("GamePassService")) end
	return _gamePassService
end
local function getBattlePassService()
	if not _battlePassService then _battlePassService = require(script.Parent:WaitForChild("BattlePassService")) end
	return _battlePassService
end

local AdminService = {}

local VALIDATION_LOG_MAX = 80
local validationLog: {
	{
		t: number,
		userId: number,
		playerName: string,
		violationType: string,
		severity: string,
		detail: string,
	}
} = {}

function AdminService.logValidation(player: Player, violationType: string, severity: string, detail: string?)
	local msg = detail and (`{violationType}: {detail}`) or violationType
	warn(`[DAC][Validation][{severity}] {player.Name} ({player.UserId}) {msg}`)
	table.insert(validationLog, {
		t = os.time(),
		userId = player.UserId,
		playerName = player.Name,
		violationType = violationType,
		severity = severity,
		detail = detail or "",
	})
	while #validationLog > VALIDATION_LOG_MAX do
		table.remove(validationLog, 1)
	end
end

-- Add Roblox user IDs allowed to use /admin in published games (Studio bypasses this list).
local ADMIN_USER_IDS: { [number]: boolean } = {
	-- Example: [123456789] = true,
}

-- Optional: set to your group id and minimum rank (e.g. 250+). 0 = disabled.
local ADMIN_GROUP_ID = 0
local ADMIN_MIN_RANK = 250

local function reply(player: Player, msg: string)
	Remotes.getEvent("Notification"):FireClient(player, {
		type = "success",
		message = "[Admin] " .. msg,
	})
end

local function replyErr(player: Player, msg: string)
	Remotes.getEvent("Notification"):FireClient(player, {
		type = "error",
		message = "[Admin] " .. msg,
	})
end

local function isAuthorized(player: Player): boolean
	if RobloxRunService:IsStudio() then
		return true
	end
	if ADMIN_USER_IDS[player.UserId] then
		return true
	end
	if ADMIN_GROUP_ID > 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(ADMIN_GROUP_ID)
		end)
		if ok and type(rank) == "number" and rank >= ADMIN_MIN_RANK then
			return true
		end
	end
	return false
end

local function syncFull(player: Player)
	local data = DataManager.get(player)
	if data then
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
	end
end

local function parseWords(msg: string): { string }
	local out: { string } = {}
	for w in string.gmatch(msg, "%S+") do
		table.insert(out, w)
	end
	return out
end

local function runAdmin(player: Player, parts: { string })
	if #parts == 0 or string.lower(parts[1]) ~= "/admin" then
		return
	end

	if not isAuthorized(player) then
		return
	end

	local cmd = string.lower(parts[2] or "help")
	local data = DataManager.get(player)
	if not data and cmd ~= "help" then
		replyErr(player, "No profile loaded.")
		return
	end

	if cmd == "help" then
		reply(
			player,
			"give coins|gems|crystals|skulls <n> · setrebirth <n> · unlockworld <key> · unlockallcars · unlockallpets · resetdata · setgas <n> · maxstats · togglevip · listpasses · bp tier <n> · addquest <id>"
		)
		return
	end

	if cmd == "give" then
		local kind = string.lower(parts[3] or "")
		local n = tonumber(parts[4])
		if not n or n < 0 then
			replyErr(player, "Usage: /admin give coins|gems|crystals|skulls <amount>")
			return
		end
		if kind == "coins" or kind == "gems" or kind == "crystals" or kind == "skulls" then
			DataManager.addCurrency(player, kind, n, "admin")
			syncFull(player)
			reply(player, `Added {n} {kind}.`)
		else
			replyErr(player, "Unknown currency.")
		end
		return
	end

	if cmd == "setrebirth" then
		local n = tonumber(parts[3])
		if n == nil or n < 0 then
			replyErr(player, "Usage: /admin setrebirth <count>")
			return
		end
		data.rebirths = math.floor(n)
		syncFull(player)
		reply(player, `Rebirth count set to {data.rebirths}.`)
		return
	end

	if cmd == "unlockworld" then
		local key = parts[3]
		if not key then
			replyErr(player, "Usage: /admin unlockworld <worldKey>")
			return
		end
		if not WorldConfig.Worlds[key] then
			replyErr(player, "Unknown world.")
			return
		end
		data.unlockedWorlds[key] = true
		syncFull(player)
		reply(player, `Unlocked world: {key}`)
		return
	end

	if cmd == "unlockallcars" then
		for carId in CarConfig.Cars do
			if not data.cars[carId] then
				data.cars[carId] = {
					id = carId,
					gasLevel = 0,
					powerLevel = 0,
					speedLevel = 0,
				}
			end
		end
		syncFull(player)
		reply(player, "All cars granted.")
		return
	end

	if cmd == "unlockallpets" then
		for petId in PetConfig.Pets do
			local def = PetConfig.Pets[petId]
			local uid = Utils.generateUID()
			data.pets[uid] = {
				uid = uid,
				id = petId,
				power = def.basePower,
				equipped = false,
			}
			data.discoveredPets[petId] = true
		end
		syncFull(player)
		reply(player, "Granted one of every pet.")
		return
	end

	if cmd == "resetdata" then
		getDACRunService().adminAbortRunNoPayout(player)
		DataManager.resetToDefault(player)
		getGamePassService().checkAllPasses(player)
		getBattlePassService().ensureSeason(player)
		getQuestService().ensureQuests(player)
		local fresh = DataManager.get(player)
		if fresh then
			getQuestService().onWorldChanged(player, fresh.currentWorld)
		end
		syncFull(player)
		reply(player, "Profile reset to defaults (session).")
		return
	end

	if cmd == "setgas" then
		local n = tonumber(parts[3])
		if not n or n < 0 then
			replyErr(player, "Usage: /admin setgas <amount> (while in a run)")
			return
		end
		if getDACRunService().adminSetGasRemaining(player, n) then
			reply(player, `Gas set to {n}.`)
		else
			replyErr(player, "Not in an active run.")
		end
		return
	end

	if cmd == "maxstats" then
		local carId = data.equippedCar
		local owned = data.cars[carId]
		if not owned then
			replyErr(player, "No equipped car data.")
			return
		end
		for _, stat in { "gas", "power", "speed" } do
			local cfg = UpgradeConfig.Stats[stat]
			if cfg then
				local lk = stat .. "Level"
				owned[lk] = cfg.maxLevel
			end
		end
		syncFull(player)
		reply(player, `Maxed upgrades for equipped car ({carId}).`)
		return
	end

	if cmd == "togglevip" then
		local s = getGamePassService().adminCycleVipTesting(player)
		reply(player, s)
		return
	end

	if cmd == "listpasses" then
		local lines: { string } = {}
		for passId, passDef in GamePassConfig.Passes do
			local owns = getGamePassService().hasPass(player, passId)
			local yn = if owns then "yes" else "no"
			table.insert(lines, `{passId}: {yn} ({passDef.name})`)
		end
		table.sort(lines)
		reply(player, table.concat(lines, " · "))
		return
	end

	if cmd == "bp" then
		local sub = string.lower(parts[3] or "")
		if sub ~= "tier" then
			replyErr(player, "Usage: /admin bp tier <n>")
			return
		end
		local tier = tonumber(parts[4])
		if not tier or tier < 1 then
			replyErr(player, "Invalid tier.")
			return
		end
		tier = math.min(math.floor(tier), BattlePassConfig.TIER_COUNT)
		getBattlePassService().ensureSeason(player)
		local d = DataManager.get(player)
		if not d or not d.battlePass then
			replyErr(player, "No battle pass data.")
			return
		end
		d.battlePass.xp = BattlePassConfig.tierStartXp(tier)
		syncFull(player)
		reply(player, `Battle pass XP set to start of tier {tier}.`)
		return
	end

	if cmd == "addquest" then
		local qid = parts[3]
		if not qid then
			replyErr(player, "Usage: /admin addquest <questKey>")
			return
		end
		local ok, err = getQuestService().adminForceCompleteQuest(player, qid)
		if ok then
			reply(player, `Completed quest: {qid}`)
		else
			replyErr(player, err or "Failed")
		end
		return
	end

	replyErr(player, "Unknown command. Try /admin help")
end

function AdminService.init(_dataManager: any)
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(msg)
			local parts = parseWords(msg)
			runAdmin(player, parts)
		end)
	end)

	for _, player in Players:GetPlayers() do
		player.Chatted:Connect(function(msg)
			local parts = parseWords(msg)
			runAdmin(player, parts)
		end)
	end
end

return AdminService
