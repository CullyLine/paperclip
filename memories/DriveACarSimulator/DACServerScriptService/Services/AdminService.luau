--!strict
--[[
	Founder/admin chat commands: /admin <subcommand> [args]
	Authorization: Studio (all), hardcoded UserIds, or optional Roblox group rank.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

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
		local RebirthService = require(script.Parent:WaitForChild("RebirthService"))
		RebirthService.syncPrestigeAttributes(player)
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

-- Classic Roblox tool asset IDs (free library / classic gear)
local CLASSIC_TOOLS: { [string]: { name: string, assetId: number } } = {
	sword = { name = "Classic Sword", assetId = 125013769 },
	trowel = { name = "Classic Trowel", assetId = 73089166 },
	superball = { name = "Superball", assetId = 73089204 },
	rocket = { name = "Rocket Launcher", assetId = 73089190 },
	slingshot = { name = "Slingshot", assetId = 73089199 },
	bomb = { name = "Bomb", assetId = 73089167 },
	delete_tool = { name = "Delete Hammer", assetId = 73089169 },
	paint_bucket = { name = "Paint Bucket", assetId = 18474459 },
}

local function giveClassicTool(player: Player, toolKey: string)
	local char = player.Character
	if not char then
		replyErr(player, "No character.")
		return
	end
	local entry = CLASSIC_TOOLS[toolKey]
	if not entry then
		replyErr(player, "Unknown tool: " .. toolKey)
		return
	end
	local InsertService = game:GetService("InsertService")
	local ok, model = pcall(function()
		return InsertService:LoadAsset(entry.assetId)
	end)
	if ok and model then
		for _, child in model:GetChildren() do
			if child:IsA("Tool") or child:IsA("HopperBin") then
				child.Parent = player.Backpack
			end
		end
		model:Destroy()
		reply(player, "Gave " .. entry.name)
	else
		replyErr(player, "Failed to load tool asset")
	end
end

local function setCharacterScale(player: Player, scale: number)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	scale = math.clamp(scale, 0.2, 10)
	for _, desc in hum:GetDescendants() do
		if desc:IsA("NumberValue") and (
			desc.Name == "BodyDepthScale" or desc.Name == "BodyHeightScale"
			or desc.Name == "BodyWidthScale" or desc.Name == "HeadScale"
		) then
			desc.Value = scale
		end
	end
	reply(player, `Scale set to {scale}`)
end

local function setGodMode(player: Player, enabled: boolean)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if enabled then
		hum.MaxHealth = math.huge
		hum.Health = math.huge
		reply(player, "God mode ON")
	else
		hum.MaxHealth = 100
		hum.Health = 100
		reply(player, "God mode OFF")
	end
end

local function toggleSparkles(player: Player)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local existing = hrp:FindFirstChild("AdminSparkles")
	if existing then
		existing:Destroy()
		reply(player, "Sparkle Time OFF")
	else
		local s = Instance.new("Sparkles")
		s.Name = "AdminSparkles"
		s.SparkleColor = Color3.fromRGB(255, 255, 100)
		s.Parent = hrp
		reply(player, "Sparkle Time ON")
	end
end

local function filterText(text: string, fromUserId: number): string
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(text, fromUserId)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if ok and result then return result end
	return "[ filtered ]"
end

local pendingFinds: { [string]: { player: Player, priorityJoin: boolean } } = {}

local function setBallerScale(plr: Player)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, desc in hum:GetDescendants() do
		if desc:IsA("NumberValue") then
			if desc.Name == "BodyWidthScale" or desc.Name == "BodyDepthScale" then
				desc.Value = 3.5
			elseif desc.Name == "BodyHeightScale" then
				desc.Value = 0.4
			elseif desc.Name == "HeadScale" then
				desc.Value = 2.5
			end
		end
	end
end

local function handleAdminCommand(player: Player, payload: { [string]: any })
	if not isAuthorized(player) then return end

	local action = payload.action
	if type(action) ~= "string" then return end

	local target = player
	local targetId = payload.targetUserId
	if type(targetId) == "number" and targetId ~= player.UserId then
		local found = Players:GetPlayerByUserId(targetId)
		if found then target = found end
	end

	local data = DataManager.get(target)

	if action == "give_currency" then
		local kind = payload.currency
		local amount = tonumber(payload.amount)
		if type(kind) ~= "string" or not amount or amount <= 0 then return end
		if kind == "coins" or kind == "gems" or kind == "crystals" or kind == "skulls" then
			DataManager.addCurrency(target, kind, math.floor(amount), "admin")
			syncFull(target)
			reply(player, `Gave {target.Name} {Utils.formatNumber(amount)} {kind}`)
		end
		return
	end

	if action == "set_currency" then
		local kind = payload.currency
		local amount = tonumber(payload.amount)
		if type(kind) ~= "string" or not amount or not data then return end
		if data[kind] ~= nil then
			data[kind] = math.max(0, math.floor(amount))
			syncFull(target)
			reply(player, `Set {target.Name} {kind} to {Utils.formatNumber(amount)}`)
		end
		return
	end

	if action == "set_rebirths" then
		local n = tonumber(payload.count)
		if not n or not data then return end
		data.rebirths = math.max(0, math.floor(n))
		syncFull(target)
		reply(player, `Set {target.Name} rebirths to {data.rebirths}`)
		return
	end

	if action == "max_stats" then
		if not data then return end
		for carId, owned in data.cars do
			for _, stat in { "gas", "power", "speed" } do
				local cfg = UpgradeConfig.Stats[stat]
				if cfg then owned[stat .. "Level"] = cfg.maxLevel end
			end
		end
		syncFull(target)
		reply(player, `Maxed all car stats for {target.Name}`)
		return
	end

	if action == "unlock_all_cars" then
		if not data then return end
		for carId in CarConfig.Cars do
			if not data.cars[carId] then
				data.cars[carId] = { id = carId, gasLevel = 0, powerLevel = 0, speedLevel = 0 }
			end
		end
		syncFull(target)
		reply(player, `Unlocked all cars for {target.Name}`)
		return
	end

	if action == "give_all_pets" then
		if not data then return end
		for petId in PetConfig.Pets do
			local def = PetConfig.Pets[petId]
			local uid = Utils.generateUID()
			data.pets[uid] = { uid = uid, id = petId, power = def.basePower, equipped = false }
			data.discoveredPets[petId] = true
		end
		syncFull(target)
		reply(player, `Gave all pets to {target.Name}`)
		return
	end

	if action == "max_pet_slots" then
		if not data then return end
		data.maxPetSlots = 64
		syncFull(target)
		reply(player, `Max pet slots set to 64 for {target.Name}`)
		return
	end

	if action == "clear_pets" then
		if not data then return end
		data.pets = {}
		syncFull(target)
		reply(player, `Cleared all pets for {target.Name}`)
		return
	end

	if action == "unlock_all_worlds" then
		if not data then return end
		for worldId in WorldConfig.Worlds do
			data.unlockedWorlds[worldId] = true
		end
		syncFull(target)
		reply(player, `Unlocked all worlds for {target.Name}`)
		return
	end

	if action == "toggle_pass" then
		local passId = payload.passId
		if type(passId) ~= "string" then return end
		local gps = getGamePassService()
		if gps.adminTogglePass then
			gps.adminTogglePass(target, passId)
			syncFull(target)
			reply(player, `Toggled pass {passId} for {target.Name}`)
		else
			gps.adminCycleVipTesting(target)
			reply(player, "Toggled VIP")
		end
		return
	end

	if action == "set_bp_tier" then
		local tier = tonumber(payload.tier)
		if not tier or tier < 1 then return end
		tier = math.min(math.floor(tier), BattlePassConfig.TIER_COUNT)
		getBattlePassService().ensureSeason(target)
		local d = DataManager.get(target)
		if d and d.battlePass then
			d.battlePass.xp = BattlePassConfig.tierStartXp(tier)
			syncFull(target)
			reply(player, `BP tier set to {tier} for {target.Name}`)
		end
		return
	end

	if action == "reset_data" then
		getDACRunService().adminAbortRunNoPayout(target)
		DataManager.resetToDefault(target)
		getGamePassService().checkAllPasses(target)
		getBattlePassService().ensureSeason(target)
		getQuestService().ensureQuests(target)
		local fresh = DataManager.get(target)
		if fresh then getQuestService().onWorldChanged(target, fresh.currentWorld) end
		syncFull(target)
		reply(player, `Reset data for {target.Name}`)
		return
	end

	if action == "complete_tutorial" then
		if not data then return end
		data.tutorialStep = 99
		data.tutorialComplete = true
		syncFull(target)
		reply(player, `Tutorial completed for {target.Name}`)
		return
	end

	if action == "set_walkspeed" then
		local spd = tonumber(payload.speed)
		if not spd then return end
		local char = target.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = math.clamp(spd, 0, 500)
				reply(player, `Walkspeed set to {spd}`)
			end
		end
		return
	end

	if action == "set_scale" then
		local s = tonumber(payload.scale)
		if not s then return end
		setCharacterScale(target, s)
		return
	end

	if action == "god_mode" then
		setGodMode(target, payload.enabled == true)
		return
	end

	if action == "set_gravity" then
		local g = tonumber(payload.gravity)
		if not g then return end
		game.Workspace.Gravity = math.clamp(g, 0, 1000)
		reply(player, `Gravity set to {g}`)
		return
	end

	if action == "set_time" then
		local t = tonumber(payload.time)
		if not t then return end
		local lighting = game:GetService("Lighting")
		lighting.ClockTime = math.clamp(t, 0, 24)
		reply(player, `Time set to {string.format("%.1f", t)}`)
		return
	end

	if action == "explosion" then
		local pos = payload.position
		if type(pos) ~= "table" then return end
		local e = Instance.new("Explosion")
		e.Position = Vector3.new(pos.x or 0, pos.y or 0, pos.z or 0)
		e.BlastRadius = tonumber(payload.radius) or 30
		e.BlastPressure = 500000
		e.Parent = game.Workspace
		reply(player, "BOOM!")
		return
	end

	if action == "server_announce" then
		local msg = payload.message
		if type(msg) ~= "string" or msg == "" then return end
		msg = filterText(msg, player.UserId)
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "[Server] " .. msg,
			})
		end
		reply(player, "Announced: " .. msg)
		return
	end

	if action == "infinite_fuel" then
		if getDACRunService().adminSetGasRemaining(target, 99999) then
			reply(player, "Fuel set to 99999")
		else
			replyErr(player, "Not in a run")
		end
		return
	end

	if action == "max_everything" then
		if not data then return end
		data.coins = 999_999_999
		data.gems = 999_999
		data.crystals = 999_999
		data.skulls = 999_999
		for carId in CarConfig.Cars do
			if not data.cars[carId] then
				data.cars[carId] = { id = carId, gasLevel = 0, powerLevel = 0, speedLevel = 0 }
			end
			for _, stat in { "gas", "power", "speed" } do
				local cfg = UpgradeConfig.Stats[stat]
				if cfg then data.cars[carId][stat .. "Level"] = cfg.maxLevel end
			end
		end
		for petId in PetConfig.Pets do
			local def = PetConfig.Pets[petId]
			local uid = Utils.generateUID()
			data.pets[uid] = { uid = uid, id = petId, power = def.basePower, equipped = false }
			data.discoveredPets[petId] = true
		end
		data.maxPetSlots = 64
		for worldId in WorldConfig.Worlds do
			data.unlockedWorlds[worldId] = true
		end
		data.rebirths = 100
		data.rebirthStats = { gas = 500, power = 500, speed = 500 }
		data.tutorialStep = 99
		data.tutorialComplete = true
		syncFull(target)
		reply(player, "MAXED EVERYTHING for " .. target.Name)
		return
	end

	if action == "give_tool" then
		local toolKey = payload.tool
		if type(toolKey) ~= "string" then return end
		giveClassicTool(target, toolKey)
		return
	end

	if action == "sparkles" then
		toggleSparkles(target)
		return
	end

	if action == "fly" then
		reply(player, "Fly mode toggled (client-side)")
		return
	end

	if action == "speed_multiplier" then
		local mul = tonumber(payload.multiplier)
		if not mul then return end
		local char = target.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 16 * mul
				reply(player, `Speed x{mul}`)
			end
		end
		return
	end

	-- ========== SERVER-WIDE TROLL COMMANDS ==========

	if action == "sw_everyone_tiny" then
		for _, p in Players:GetPlayers() do setCharacterScale(p, 0.3) end
		reply(player, "Everyone is now TINY!")
		return
	end

	if action == "sw_everyone_giant" then
		for _, p in Players:GetPlayers() do setCharacterScale(p, 5) end
		reply(player, "Everyone is now GIANT!")
		return
	end

	if action == "sw_everyone_normal" then
		for _, p in Players:GetPlayers() do setCharacterScale(p, 1) end
		reply(player, "Everyone restored to normal size")
		return
	end

	if action == "sw_freeze_all" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 0 end
			end
		end
		reply(player, "Everyone is FROZEN!")
		return
	end

	if action == "sw_unfreeze_all" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 16 end
			end
		end
		reply(player, "Everyone unfrozen")
		return
	end

	if action == "sw_speed_demon" then
		local spd = tonumber(payload.speed) or 200
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = spd end
			end
		end
		reply(player, `Everyone speed set to {spd}!`)
		return
	end

	if action == "sw_fling_all" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local hrp = c:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						hrp.AssemblyLinearVelocity = Vector3.new(
							math.random(-200, 200),
							math.random(300, 600),
							math.random(-200, 200)
						)
					end
				end
			end
		end
		reply(player, "FLUNG EVERYONE!")
		return
	end

	if action == "sw_trip_all" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local h = c:FindFirstChildOfClass("Humanoid")
					if h then h.Sit = true end
				end
			end
		end
		reply(player, "Everyone just tripped!")
		return
	end

	if action == "sw_everyone_on_fire" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local hrp = c:FindFirstChild("HumanoidRootPart")
				if hrp then
					local existing = hrp:FindFirstChild("AdminFire")
					if existing then
						existing:Destroy()
					else
						local f = Instance.new("Fire")
						f.Name = "AdminFire"
						f.Size = 8
						f.Heat = 10
						f.Parent = hrp
					end
				end
			end
		end
		reply(player, "Everyone is ON FIRE! (toggle)")
		return
	end

	if action == "sw_confetti" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local head = c:FindFirstChild("Head")
				if head then
					local existing = head:FindFirstChild("AdminConfetti")
					if existing then
						existing:Destroy()
					else
						local pe = Instance.new("ParticleEmitter")
						pe.Name = "AdminConfetti"
						pe.Rate = 40
						pe.Lifetime = NumberRange.new(2, 4)
						pe.Speed = NumberRange.new(5, 15)
						pe.SpreadAngle = Vector2.new(180, 180)
						pe.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
							ColorSequenceKeypoint.new(0.25, Color3.fromRGB(50, 255, 50)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 50, 255)),
							ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 50)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 255)),
						})
						pe.Size = NumberSequence.new(0.3, 0.1)
						pe.Parent = head
					end
				end
			end
		end
		reply(player, "Confetti cannons! (toggle)")
		return
	end

	if action == "sw_spin_all" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local hrp = c:FindFirstChild("HumanoidRootPart")
					if hrp then
						local existing = hrp:FindFirstChild("AdminSpin")
						if existing then
							existing:Destroy()
						else
							local bav = Instance.new("BodyAngularVelocity")
							bav.Name = "AdminSpin"
							bav.AngularVelocity = Vector3.new(0, 20, 0)
							bav.MaxTorque = Vector3.new(0, math.huge, 0)
							bav.Parent = hrp
						end
					end
				end
			end
		end
		reply(player, "SPIN CYCLE! (toggle)")
		return
	end

	if action == "sw_bring_all" then
		local adminChar = player.Character
		if not adminChar then return end
		local adminHrp = adminChar:FindFirstChild("HumanoidRootPart")
		if not adminHrp then return end
		local basePos = adminHrp.Position
		local i = 0
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local hrp = c:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						i += 1
						local angle = (i / #Players:GetPlayers()) * math.pi * 2
						hrp.CFrame = CFrame.new(basePos + Vector3.new(math.cos(angle) * 10, 0, math.sin(angle) * 10))
					end
				end
			end
		end
		reply(player, "Brought everyone to you!")
		return
	end

	if action == "sw_scatter" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local hrp = c:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						hrp.CFrame = CFrame.new(
							math.random(-500, 500),
							50,
							math.random(-500, 500)
						)
					end
				end
			end
		end
		reply(player, "Everyone SCATTERED!")
		return
	end

	if action == "sw_fake_shutdown" then
		local delay = tonumber(payload.seconds) or 10
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = `[SYSTEM] Server shutting down in {delay} seconds for maintenance...`,
			})
		end
		task.delay(delay, function()
			for _, p in Players:GetPlayers() do
				Remotes.getEvent("Notification"):FireClient(p, {
					type = "success",
					message = "[SYSTEM] Just kidding! ;)",
				})
			end
		end)
		reply(player, `Fake shutdown in {delay}s... gottem`)
		return
	end

	if action == "sw_disco" then
		task.spawn(function()
			for i = 1, 30 do
				Lighting.Ambient = Color3.fromHSV(math.random(), 1, 1)
				Lighting.OutdoorAmbient = Color3.fromHSV(math.random(), 1, 1)
				Lighting.FogColor = Color3.fromHSV(math.random(), 0.5, 1)
				task.wait(0.15)
			end
			Lighting.Ambient = Color3.fromRGB(127, 127, 127)
			Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
			Lighting.FogColor = Color3.fromRGB(191, 191, 191)
		end)
		reply(player, "DISCO MODE!")
		return
	end

	if action == "sw_blackout" then
		Lighting.ClockTime = 0
		Lighting.Ambient = Color3.new(0, 0, 0)
		Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
		Lighting.Brightness = 0
		reply(player, "BLACKOUT!")
		return
	end

	if action == "sw_lights_on" then
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(127, 127, 127)
		Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
		Lighting.Brightness = 2
		reply(player, "Lights restored")
		return
	end

	if action == "sw_moon_gravity" then
		game.Workspace.Gravity = 30
		reply(player, "Moon gravity for the whole server!")
		return
	end

	if action == "sw_normal_gravity" then
		game.Workspace.Gravity = 196.2
		reply(player, "Gravity restored")
		return
	end

	if action == "sw_rain_explosions" then
		task.spawn(function()
			for i = 1, 20 do
				local e = Instance.new("Explosion")
				e.Position = Vector3.new(math.random(-300, 300), math.random(10, 50), math.random(-300, 300))
				e.BlastRadius = 15
				e.BlastPressure = 100000
				e.Parent = game.Workspace
				task.wait(0.2)
			end
		end)
		reply(player, "RAINING EXPLOSIONS!")
		return
	end

	if action == "sw_everyone_sparkle" then
		for _, p in Players:GetPlayers() do
			toggleSparkles(p)
		end
		reply(player, "Everyone is SPARKLING! (toggle)")
		return
	end

	if action == "sw_undo_all" then
		game.Workspace.Gravity = 196.2
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(127, 127, 127)
		Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
		Lighting.Brightness = 2
		Lighting.FogColor = Color3.fromRGB(191, 191, 191)
		for _, p in Players:GetPlayers() do
			setCharacterScale(p, 1)
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 16; h.Sit = false end
				for _, desc in c:GetDescendants() do
					if desc.Name == "AdminFire" or desc.Name == "AdminConfetti"
						or desc.Name == "AdminSparkles" or desc.Name == "AdminSpin" then
						desc:Destroy()
					end
				end
			end
		end
		reply(player, "All troll effects UNDONE")
		return
	end

	if action == "sw_kick_player" then
		local targetName = payload.playerName
		if type(targetName) ~= "string" then return end
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name):find(string.lower(targetName)) and p ~= player then
				p:Kick("Lost connection to the game server, please reconnect. (Error Code: 277)")
				reply(player, "Kicked " .. p.Name)
				return
			end
		end
		replyErr(player, "Player not found")
		return
	end

	-- ========== CROSS-SERVER (MESSAGING SERVICE) ==========

	if action == "global_announce" then
		local msg = payload.message
		if type(msg) ~= "string" or msg == "" then return end
		msg = filterText(msg, player.UserId)
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", {
				cmd = "announce",
				message = msg,
				from = player.Name,
			})
		end)
		reply(player, "Global announcement sent to ALL servers")
		return
	end

	if action == "global_prank" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", {
				cmd = "prank_message",
				from = player.Name,
			})
		end)
		reply(player, "Prank notification sent to ALL servers!")
		return
	end

	if action == "global_moon" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "moon_gravity", from = player.Name })
		end)
		reply(player, "Moon gravity applied to ALL servers!")
		return
	end

	if action == "global_normal_gravity" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "normal_gravity", from = player.Name })
		end)
		reply(player, "Gravity restored on ALL servers")
		return
	end

	if action == "global_tiny" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "everyone_tiny", from = player.Name })
		end)
		reply(player, "Everyone in EVERY server is now tiny!")
		return
	end

	if action == "global_giant" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "everyone_giant", from = player.Name })
		end)
		reply(player, "GIANTS everywhere, ALL servers!")
		return
	end

	if action == "global_normal_size" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "normal_size", from = player.Name })
		end)
		reply(player, "Normal size restored on ALL servers")
		return
	end

	if action == "global_blackout" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "blackout", from = player.Name })
		end)
		reply(player, "BLACKOUT across ALL servers!")
		return
	end

	if action == "global_lights_on" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "lights_on", from = player.Name })
		end)
		reply(player, "Lights restored on ALL servers")
		return
	end

	if action == "global_disco" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "disco", from = player.Name })
		end)
		reply(player, "DISCO on ALL servers!")
		return
	end

	if action == "global_speed_boost" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "speed_boost", from = player.Name })
		end)
		reply(player, "Speed boost on ALL servers!")
		return
	end

	if action == "global_fake_shutdown" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "fake_shutdown", from = player.Name })
		end)
		reply(player, "Fake shutdown on ALL servers... gottem")
		return
	end

	if action == "global_confetti" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "confetti", from = player.Name })
		end)
		reply(player, "Confetti across ALL servers!")
		return
	end

	if action == "global_fling" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "fling_all", from = player.Name })
		end)
		reply(player, "FLUNG everyone on ALL servers!")
		return
	end

	if action == "global_coin_gift" then
		local amount = tonumber(payload.amount) or 10000
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", {
				cmd = "coin_gift",
				amount = amount,
				from = player.Name,
			})
		end)
		reply(player, `Gifted {Utils.formatNumber(amount)} coins to EVERYONE across ALL servers!`)
		return
	end

	if action == "global_undo" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "undo_all", from = player.Name })
		end)
		reply(player, "Undoing all effects across ALL servers")
		return
	end

	if action == "global_rain_explosions" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "rain_explosions", from = player.Name })
		end)
		reply(player, "RAINING EXPLOSIONS on ALL servers!")
		return
	end

	if action == "global_freeze" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "freeze_all", from = player.Name })
		end)
		reply(player, "Everyone FROZEN on ALL servers!")
		return
	end

	if action == "global_unfreeze" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "unfreeze_all", from = player.Name })
		end)
		reply(player, "Everyone unfrozen on ALL servers")
		return
	end

	-- ========== MEME COMMANDS (SERVER-WIDE) ==========

	if action == "sw_skill_issue" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local h = c:FindFirstChildOfClass("Humanoid")
					if h then h.Health = 0 end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = if p == player then "[Admin] Skill issued." else "SKILL ISSUE",
			})
		end
		return
	end

	if action == "sw_l_ratio" then
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = "L + Ratio + You fell off + No one asked",
			})
		end
		reply(player, "L + Ratio'd the whole server")
		return
	end

	if action == "sw_sigma" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 500 end
				local hrp = c:FindFirstChild("HumanoidRootPart")
				if hrp then
					if not hrp:FindFirstChild("AdminSparkles") then
						local s = Instance.new("Sparkles")
						s.Name = "AdminSparkles"
						s.SparkleColor = Color3.fromRGB(255, 215, 0)
						s.Parent = hrp
					end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "SIGMA GRINDSET ACTIVATED. You are now the main character.",
			})
		end
		reply(player, "Sigma grindset engaged for entire server")
		return
	end

	if action == "sw_caught_4k" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local h = c:FindFirstChildOfClass("Humanoid")
					if h then h.WalkSpeed = 0 end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = "CAUGHT IN 4K",
			})
		end
		reply(player, "Caught them ALL in 4K")
		return
	end

	if action == "sw_ohio" then
		game.Workspace.Gravity = 25
		Lighting.ClockTime = 0
		Lighting.Ambient = Color3.fromRGB(40, 0, 0)
		Lighting.OutdoorAmbient = Color3.fromRGB(20, 0, 0)
		Lighting.Brightness = 0.2
		Lighting.FogEnd = 150
		Lighting.FogColor = Color3.fromRGB(60, 0, 0)
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local hrp = c:FindFirstChild("HumanoidRootPart")
				if hrp and not hrp:FindFirstChild("AdminFire") then
					local f = Instance.new("Fire")
					f.Name = "AdminFire"
					f.Size = 5
					f.Color = Color3.fromRGB(100, 0, 0)
					f.Parent = hrp
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = "Only in Ohio...",
			})
		end
		reply(player, "Welcome to Ohio.")
		return
	end

	if action == "sw_emotional_damage" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local h = c:FindFirstChildOfClass("Humanoid")
					if h then h.Health = 0 end
				end
			end
		end
		task.spawn(function()
			local msgs = {
				"EMOTIONAL DAMAGE",
				"Don't worry, respawning builds character.",
				"Plot twist: you're still the main character.",
			}
			for _, msg in msgs do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "error", message = msg })
				end
				task.wait(1.5)
			end
		end)
		reply(player, "Emotional damage dealt")
		return
	end

	if action == "sw_npc_mode" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local h = c:FindFirstChildOfClass("Humanoid")
					if h then
						h.WalkSpeed = 5
						h.Sit = true
					end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = "You are now an NPC. Embrace the vibe.",
			})
		end
		reply(player, "Everyone is now an NPC")
		return
	end

	if action == "sw_baller" then
		for _, p in Players:GetPlayers() do
			setBallerScale(p)
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "BALLER.",
			})
		end
		reply(player, "Everyone is now a BALLER")
		return
	end

	if action == "sw_fake_glitch" then
		local glitches = {
			"[SYSTEM] Loading texture pack: Comic Sans Edition...",
			"[GAME] Gravity.exe has stopped working",
			"[UPDATE] New feature: every car is now a shopping cart",
			"[SYSTEM] Deploying patch 4.20.69... please stand by",
			"[BUG] The lobby has gained sentience. We're working on it.",
			"[SYSTEM] The hamster powering the server just took a break",
			"[UPDATE] All roads have been replaced with trampolines",
		}
		local msg = glitches[math.random(1, #glitches)]
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, { type = "error", message = msg })
		end
		reply(player, "Fake glitch sent!")
		return
	end

	if action == "sw_yeet" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local hrp = c:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						hrp.AssemblyLinearVelocity = Vector3.new(
							math.random(-500, 500),
							math.random(800, 1500),
							math.random(-500, 500)
						)
					end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = if p == player then "YEETED." else "GET YEETED",
			})
		end
		return
	end

	if action == "sw_based" then
		task.spawn(function()
			local chain = {
				"Hello? Based Department?",
				"Yes, I'd like to report something extremely based.",
				"The based levels are off the charts.",
				"Deploying based countermeasures...",
				"Based status: CONFIRMED.",
			}
			for _, msg in chain do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
				end
				task.wait(2)
			end
		end)
		reply(player, "Based department has been contacted")
		return
	end

	if action == "sw_oof" then
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local c = p.Character
				if c then
					local h = c:FindFirstChildOfClass("Humanoid")
					if h then h.Health = 0 end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, { type = "error", message = "oof" })
		end
		reply(player, "oof'd everyone")
		return
	end

	if action == "sw_its_joever" then
		task.spawn(function()
			local msgs = {
				"It's so over...",
				"It's actually joever.",
				"We're so back! (just kidding, it's joever)",
				"The joeverening has begun.",
			}
			for _, msg in msgs do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "error", message = msg })
				end
				task.wait(2)
			end
			game.Workspace.Gravity = 25
			Lighting.Brightness = 0.1
		end)
		reply(player, "It's joever.")
		return
	end

	if action == "sw_we_are_so_back" then
		game.Workspace.Gravity = 196.2
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(127, 127, 127)
		Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
		Lighting.FogEnd = 100000
		for _, p in Players:GetPlayers() do
			setCharacterScale(p, 1)
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 16; h.Sit = false; h.Health = h.MaxHealth end
				for _, desc in c:GetDescendants() do
					if desc.Name == "AdminFire" or desc.Name == "AdminConfetti"
						or desc.Name == "AdminSparkles" or desc.Name == "AdminSpin" then
						desc:Destroy()
					end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = "WE ARE SO BACK." })
		end
		reply(player, "We are so back.")
		return
	end

	-- ========== MEME COMMANDS (CROSS-SERVER) ==========

	if action == "global_l_ratio" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "l_ratio", from = player.Name })
		end)
		reply(player, "L + Ratio deployed to ALL servers")
		return
	end

	if action == "global_rizzler" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "rizzler", from = player.Name })
		end)
		reply(player, "The Rizzler has been summoned across ALL servers")
		return
	end

	if action == "global_ohio_boss" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "ohio_boss", from = player.Name })
		end)
		reply(player, "Ohio Final Boss deployed to ALL servers")
		return
	end

	if action == "global_skill_issue" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "skill_issue_all", from = player.Name })
		end)
		reply(player, "Skill issued across ALL servers")
		return
	end

	if action == "global_based" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "based_chain", from = player.Name })
		end)
		reply(player, "Based department notified across ALL servers")
		return
	end

	if action == "global_its_joever" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "its_joever", from = player.Name })
		end)
		reply(player, "It's joever... everywhere.")
		return
	end

	if action == "global_we_are_so_back" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "we_are_so_back", from = player.Name })
		end)
		reply(player, "We are so back... everywhere.")
		return
	end

	-- ========== WHOLESOME COMMANDS (SERVER-WIDE) ==========

	if action == "sw_compliment_all" then
		local compliments = {
			"You're doing amazing! Keep it up!",
			"The server is 10x better because you're here!",
			"Your car choice? Chef's kiss.",
			"Honestly? You're built different (in a good way).",
			"You're the reason this server is vibing right now.",
			"Fun fact: you're awesome and that's not up for debate.",
			"Someone in this server thinks you're really cool. (It's everyone.)",
			"Your energy right now? Immaculate.",
		}
		for _, p in Players:GetPlayers() do
			local msg = compliments[math.random(1, #compliments)]
			Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
		end
		reply(player, "Compliments delivered!")
		return
	end

	if action == "sw_gold_stars" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local head = c:FindFirstChild("Head")
				if head then
					local existing = head:FindFirstChild("AdminGoldStar")
					if not existing then
						local pe = Instance.new("ParticleEmitter")
						pe.Name = "AdminGoldStar"
						pe.Rate = 8
						pe.Lifetime = NumberRange.new(1.5, 3)
						pe.Speed = NumberRange.new(2, 5)
						pe.SpreadAngle = Vector2.new(180, 180)
						pe.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
						pe.Size = NumberSequence.new(0.4, 0.1)
						pe.LightEmission = 1
						pe.Parent = head
					end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "You get a gold star! Everyone gets a gold star!",
			})
		end
		reply(player, "Gold stars for everyone!")
		return
	end

	if action == "sw_group_hug" then
		local adminChar = player.Character
		if not adminChar then return end
		local adminHrp = adminChar:FindFirstChild("HumanoidRootPart")
		if not adminHrp then return end
		local basePos = adminHrp.Position
		local players = Players:GetPlayers()
		for i, p in players do
			if p ~= player then
				local c = p.Character
				if c then
					local hrp = c:FindFirstChild("HumanoidRootPart")
					if hrp and hrp:IsA("BasePart") then
						local angle = (i / #players) * math.pi * 2
						hrp.CFrame = CFrame.new(basePos + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6))
					end
				end
			end
		end
		for _, p in players do
			local c = p.Character
			if c then
				local head = c:FindFirstChild("Head")
				if head and not head:FindFirstChild("AdminConfetti") then
					local pe = Instance.new("ParticleEmitter")
					pe.Name = "AdminConfetti"
					pe.Rate = 30
					pe.Lifetime = NumberRange.new(2, 4)
					pe.Speed = NumberRange.new(3, 8)
					pe.SpreadAngle = Vector2.new(180, 180)
					pe.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 200)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 200)),
					})
					pe.Size = NumberSequence.new(0.3, 0.1)
					pe.Parent = head
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "GROUP HUG! Everyone come together!",
			})
		end
		reply(player, "Group hug initiated!")
		return
	end

	if action == "sw_motivation" then
		local quotes = {
			"Believe in yourself. You're literally playing a video game, you've already won today.",
			"Every lap you drive makes you 1% more legendary. That's just science.",
			"You miss 100% of the eggs you don't hatch. - Wayne Gretzky - Michael Scott",
			"Today's forecast: 100% chance of you being awesome.",
			"Plot twist: you were the main character all along.",
			"Your pet believes in you. Don't let your pet down.",
			"Life is short. Hatch eggs. Be happy.",
		}
		local msg = quotes[math.random(1, #quotes)]
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
		end
		reply(player, "Motivation delivered!")
		return
	end

	if action == "sw_best_server" then
		task.spawn(function()
			local msgs = {
				"[SYSTEM] Running server quality analysis...",
				"[SYSTEM] Scanning vibes... vibes are immaculate.",
				"[SYSTEM] Checking player coolness levels... off the charts.",
				"[SYSTEM] RESULT: This is officially the BEST SERVER right now!",
				"[SYSTEM] Everyone here gets a gold star. No exceptions.",
			}
			for _, msg in msgs do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
				end
				task.wait(2)
			end
		end)
		reply(player, "Best server award ceremony started!")
		return
	end

	if action == "sw_standing_ovation" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local hrp = c:FindFirstChild("HumanoidRootPart")
				if hrp then
					if not hrp:FindFirstChild("AdminSparkles") then
						local s = Instance.new("Sparkles")
						s.Name = "AdminSparkles"
						s.SparkleColor = Color3.fromRGB(255, 215, 0)
						s.Parent = hrp
					end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "The whole server gives you a STANDING OVATION!",
			})
		end
		reply(player, "Standing ovation!")
		return
	end

	-- ========== WHOLESOME COMMANDS (CROSS-SERVER) ==========

	if action == "global_compliment" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "wholesome_compliment", from = player.Name })
		end)
		reply(player, "Compliments sent to ALL servers!")
		return
	end

	if action == "global_gold_stars" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "wholesome_gold_stars", from = player.Name })
		end)
		reply(player, "Gold stars for EVERYONE in EVERY server!")
		return
	end

	if action == "global_appreciation" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "wholesome_appreciation", from = player.Name })
		end)
		reply(player, "Appreciation sent to ALL servers!")
		return
	end

	if action == "global_motivation" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "wholesome_motivation", from = player.Name })
		end)
		reply(player, "Motivation deployed to ALL servers!")
		return
	end

	if action == "global_best_game" then
		pcall(function()
			MessagingService:PublishAsync("DACAdmin", { cmd = "wholesome_best_game", from = player.Name })
		end)
		reply(player, "Best game ceremony on ALL servers!")
		return
	end

	-- ========== SERVER HOP / PLAYER FINDER ==========

	if action == "find_and_join" then
		local userId = tonumber(payload.userId)
		local playerName = payload.playerName
		if userId then
			local found = Players:GetPlayerByUserId(userId)
			if found then
				reply(player, found.Name .. " is in THIS server already!")
				return
			end
		elseif type(playerName) == "string" and playerName ~= "" then
			for _, p in Players:GetPlayers() do
				if string.lower(p.Name):find(string.lower(playerName)) then
					reply(player, p.Name .. " is in THIS server already!")
					return
				end
			end
		end
		local requestId = Utils.generateUID()
		pendingFinds[requestId] = { player = player, priorityJoin = false }
		pcall(function()
			MessagingService:PublishAsync("DACAdminFind", {
				cmd = "find",
				userId = userId,
				playerName = playerName,
				requestId = requestId,
				requestingUserId = player.UserId,
			})
		end)
		reply(player, "Searching all servers...")
		task.delay(15, function()
			if pendingFinds[requestId] then
				pendingFinds[requestId] = nil
				if player.Parent then replyErr(player, "Player not found in any server (timed out)") end
			end
		end)
		return
	end

	if action == "force_join" then
		local userId = tonumber(payload.userId)
		local playerName = payload.playerName
		if userId then
			local found = Players:GetPlayerByUserId(userId)
			if found then
				reply(player, found.Name .. " is in THIS server already!")
				return
			end
		elseif type(playerName) == "string" and playerName ~= "" then
			for _, p in Players:GetPlayers() do
				if string.lower(p.Name):find(string.lower(playerName)) then
					reply(player, p.Name .. " is in THIS server already!")
					return
				end
			end
		end
		local requestId = Utils.generateUID()
		pendingFinds[requestId] = { player = player, priorityJoin = true }
		pcall(function()
			MessagingService:PublishAsync("DACAdminFind", {
				cmd = "find",
				userId = userId,
				playerName = playerName,
				requestId = requestId,
				requestingUserId = player.UserId,
			})
		end)
		reply(player, "Searching all servers (PRIORITY MODE)...")
		task.delay(15, function()
			if pendingFinds[requestId] then
				pendingFinds[requestId] = nil
				if player.Parent then replyErr(player, "Player not found in any server (timed out)") end
			end
		end)
		return
	end

	replyErr(player, "Unknown admin action: " .. tostring(action))
end

local function handleGlobalCommand(data: { [string]: any })
	local cmd = data.cmd

	if cmd == "announce" then
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "[GLOBAL] " .. (data.message or ""),
			})
		end
	elseif cmd == "prank_message" then
		local messages = {
			"[SYSTEM] Loading texture pack: Comic Sans Edition...",
			"[UPDATE] All cars have been replaced with unicycles. Enjoy!",
			"[GAME] Physics engine said 'nah' and went on vacation",
			"[SYSTEM] The server hamster has unionized. Expect delays.",
			"[BUG] The lobby just asked for a raise. We said no.",
			"[UPDATE] Patch 4.20.69 deployed. Everything is fine. Probably.",
		}
		local msg = messages[math.random(1, #messages)]
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, { type = "error", message = msg })
		end
	elseif cmd == "moon_gravity" then
		game.Workspace.Gravity = 30
	elseif cmd == "normal_gravity" then
		game.Workspace.Gravity = 196.2
	elseif cmd == "everyone_tiny" then
		for _, p in Players:GetPlayers() do setCharacterScale(p, 0.3) end
	elseif cmd == "everyone_giant" then
		for _, p in Players:GetPlayers() do setCharacterScale(p, 5) end
	elseif cmd == "normal_size" then
		for _, p in Players:GetPlayers() do setCharacterScale(p, 1) end
	elseif cmd == "blackout" then
		Lighting.ClockTime = 0
		Lighting.Ambient = Color3.new(0, 0, 0)
		Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
		Lighting.Brightness = 0
	elseif cmd == "lights_on" then
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(127, 127, 127)
		Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
		Lighting.Brightness = 2
	elseif cmd == "disco" then
		task.spawn(function()
			for i = 1, 30 do
				Lighting.Ambient = Color3.fromHSV(math.random(), 1, 1)
				Lighting.OutdoorAmbient = Color3.fromHSV(math.random(), 1, 1)
				Lighting.FogColor = Color3.fromHSV(math.random(), 0.5, 1)
				task.wait(0.15)
			end
			Lighting.Ambient = Color3.fromRGB(127, 127, 127)
			Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
			Lighting.FogColor = Color3.fromRGB(191, 191, 191)
		end)
	elseif cmd == "speed_boost" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 100 end
			end
		end
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "[EVENT] Speed Boost activated!",
			})
		end
	elseif cmd == "fake_shutdown" then
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = "[SYSTEM] Server shutting down in 10 seconds for maintenance...",
			})
		end
		task.delay(10, function()
			for _, p in Players:GetPlayers() do
				Remotes.getEvent("Notification"):FireClient(p, {
					type = "success",
					message = "[SYSTEM] Just kidding! ;)",
				})
			end
		end)
	elseif cmd == "confetti" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local head = c:FindFirstChild("Head")
				if head then
					local existing = head:FindFirstChild("AdminConfetti")
					if not existing then
						local pe = Instance.new("ParticleEmitter")
						pe.Name = "AdminConfetti"
						pe.Rate = 40
						pe.Lifetime = NumberRange.new(2, 4)
						pe.Speed = NumberRange.new(5, 15)
						pe.SpreadAngle = Vector2.new(180, 180)
						pe.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
							ColorSequenceKeypoint.new(0.25, Color3.fromRGB(50, 255, 50)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 50, 255)),
							ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 255, 50)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 255)),
						})
						pe.Size = NumberSequence.new(0.3, 0.1)
						pe.Parent = head
					end
				end
			end
		end
	elseif cmd == "fling_all" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local hrp = c:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					hrp.AssemblyLinearVelocity = Vector3.new(
						math.random(-200, 200), math.random(300, 600), math.random(-200, 200)
					)
				end
			end
		end
	elseif cmd == "coin_gift" then
		local amount = tonumber(data.amount) or 10000
		for _, p in Players:GetPlayers() do
			local d = DataManager.get(p)
			if d then
				DataManager.addCurrency(p, "coins", amount, "admin_global")
				syncFull(p)
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = `[GIFT] The creator gave everyone {Utils.formatNumber(amount)} coins!`,
			})
		end
	elseif cmd == "rain_explosions" then
		task.spawn(function()
			for i = 1, 20 do
				local e = Instance.new("Explosion")
				e.Position = Vector3.new(math.random(-300, 300), math.random(10, 50), math.random(-300, 300))
				e.BlastRadius = 15
				e.BlastPressure = 100000
				e.Parent = game.Workspace
				task.wait(0.2)
			end
		end)
	elseif cmd == "freeze_all" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 0 end
			end
		end
	elseif cmd == "unfreeze_all" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 16 end
			end
		end
	elseif cmd == "undo_all" then
		game.Workspace.Gravity = 196.2
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(127, 127, 127)
		Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
		Lighting.Brightness = 2
		Lighting.FogColor = Color3.fromRGB(191, 191, 191)
		Lighting.FogEnd = 100000
		for _, p in Players:GetPlayers() do
			setCharacterScale(p, 1)
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 16; h.Sit = false end
				for _, desc in c:GetDescendants() do
					if desc.Name == "AdminFire" or desc.Name == "AdminConfetti"
						or desc.Name == "AdminSparkles" or desc.Name == "AdminSpin" then
						desc:Destroy()
					end
				end
			end
		end

	-- ========== MEME GLOBAL HANDLERS ==========

	elseif cmd == "l_ratio" then
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = "L + Ratio + You fell off + No one asked (from the creator)",
			})
		end

	elseif cmd == "rizzler" then
		task.spawn(function()
			local msgs = {
				"[SYSTEM] Something approaches...",
				"[SYSTEM] The Rizzler has entered the game.",
				"[SYSTEM] Rizz levels are being evaluated...",
				"[SYSTEM] Results: Maximum rizz detected. Everyone here is valid.",
				"[SYSTEM] The Rizzler approves this server. Keep grinding.",
			}
			for _, msg in msgs do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
				end
				task.wait(3)
			end
		end)

	elseif cmd == "ohio_boss" then
		game.Workspace.Gravity = 25
		Lighting.ClockTime = 0
		Lighting.Ambient = Color3.fromRGB(40, 0, 0)
		Lighting.OutdoorAmbient = Color3.fromRGB(20, 0, 0)
		Lighting.Brightness = 0.2
		Lighting.FogEnd = 150
		Lighting.FogColor = Color3.fromRGB(60, 0, 0)
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local hrp = c:FindFirstChild("HumanoidRootPart")
				if hrp then
					if not hrp:FindFirstChild("AdminFire") then
						local f = Instance.new("Fire")
						f.Name = "AdminFire"
						f.Size = 5
						f.Color = Color3.fromRGB(100, 0, 0)
						f.Parent = hrp
					end
				end
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 5 end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = "OHIO FINAL BOSS HAS ARRIVED.",
			})
		end

	elseif cmd == "skill_issue_all" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.Health = 0 end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "error",
				message = "SKILL ISSUE (from the creator, with love)",
			})
		end

	elseif cmd == "based_chain" then
		task.spawn(function()
			local chain = {
				"Hello? Based Department?",
				"Yes, I'd like to report something extremely based.",
				"The based levels are off the charts.",
				"Deploying based countermeasures...",
				"Based status: CONFIRMED.",
			}
			for _, msg in chain do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
				end
				task.wait(2)
			end
		end)

	elseif cmd == "its_joever" then
		task.spawn(function()
			local msgs = {
				"It's so over...",
				"It's actually joever.",
				"We're so back! (just kidding, it's joever)",
				"The joeverening has begun.",
			}
			for _, msg in msgs do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "error", message = msg })
				end
				task.wait(2)
			end
			game.Workspace.Gravity = 25
			Lighting.Brightness = 0.1
		end)

	elseif cmd == "we_are_so_back" then
		game.Workspace.Gravity = 196.2
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(127, 127, 127)
		Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
		Lighting.FogEnd = 100000
		for _, p in Players:GetPlayers() do
			setCharacterScale(p, 1)
			local c = p.Character
			if c then
				local h = c:FindFirstChildOfClass("Humanoid")
				if h then h.WalkSpeed = 16; h.Sit = false; h.Health = h.MaxHealth end
				for _, desc in c:GetDescendants() do
					if desc.Name == "AdminFire" or desc.Name == "AdminConfetti"
						or desc.Name == "AdminSparkles" or desc.Name == "AdminSpin" then
						desc:Destroy()
					end
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = "WE ARE SO BACK." })
		end

	-- ========== WHOLESOME GLOBAL HANDLERS ==========

	elseif cmd == "wholesome_compliment" then
		local compliments = {
			"You're doing amazing! Keep it up!",
			"The game is better because you're playing it!",
			"Honestly? You're built different (in a good way).",
			"Fun fact: you're awesome and that's not up for debate.",
			"Someone in this game thinks you're really cool. (It's the creator.)",
			"Your energy right now? Immaculate.",
		}
		for _, p in Players:GetPlayers() do
			local msg = compliments[math.random(1, #compliments)]
			Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
		end

	elseif cmd == "wholesome_gold_stars" then
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				local head = c:FindFirstChild("Head")
				if head and not head:FindFirstChild("AdminGoldStar") then
					local pe = Instance.new("ParticleEmitter")
					pe.Name = "AdminGoldStar"
					pe.Rate = 8
					pe.Lifetime = NumberRange.new(1.5, 3)
					pe.Speed = NumberRange.new(2, 5)
					pe.SpreadAngle = Vector2.new(180, 180)
					pe.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
					pe.Size = NumberSequence.new(0.4, 0.1)
					pe.LightEmission = 1
					pe.Parent = head
				end
			end
			Remotes.getEvent("Notification"):FireClient(p, {
				type = "success",
				message = "You get a gold star! Everyone gets a gold star!",
			})
		end

	elseif cmd == "wholesome_appreciation" then
		task.spawn(function()
			local msgs = {
				"[CREATOR] Hey, just wanted to say...",
				"[CREATOR] Thank you for playing this game.",
				"[CREATOR] Every single one of you makes this worth building.",
				"[CREATOR] You're all awesome. That's it. That's the message.",
			}
			for _, msg in msgs do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
				end
				task.wait(2.5)
			end
		end)

	elseif cmd == "wholesome_motivation" then
		local quotes = {
			"Believe in yourself. You're literally playing a video game, you've already won today.",
			"Every lap you drive makes you 1% more legendary. That's just science.",
			"Today's forecast: 100% chance of you being awesome.",
			"Plot twist: you were the main character all along.",
			"Your pet believes in you. Don't let your pet down.",
		}
		local msg = quotes[math.random(1, #quotes)]
		for _, p in Players:GetPlayers() do
			Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
		end

	elseif cmd == "wholesome_best_game" then
		task.spawn(function()
			local msgs = {
				"[SYSTEM] Running vibes analysis across all servers...",
				"[SYSTEM] Results: Every single server is incredible.",
				"[SYSTEM] OFFICIAL VERDICT: Best game on Roblox right now.",
				"[SYSTEM] Thank you all for being here. You're what makes this special.",
			}
			for _, msg in msgs do
				for _, p in Players:GetPlayers() do
					Remotes.getEvent("Notification"):FireClient(p, { type = "success", message = msg })
				end
				task.wait(2.5)
			end
		end)
	end
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

	Remotes.getEvent("AdminCommand").OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then return end
		handleAdminCommand(player, payload)
	end)

	Remotes.getFunction("AdminAuth").OnServerInvoke = function(player)
		return isAuthorized(player)
	end

	pcall(function()
		MessagingService:SubscribeAsync("DACAdmin", function(message)
			local data = message.Data
			if type(data) ~= "table" then return end
			handleGlobalCommand(data)
		end)
	end)

	pcall(function()
		MessagingService:SubscribeAsync("DACAdminFind", function(message)
			local data = message.Data
			if type(data) ~= "table" then return end

			if data.cmd == "find" then
				local targetPlayer: Player? = nil
				if data.userId then
					targetPlayer = Players:GetPlayerByUserId(data.userId)
				elseif type(data.playerName) == "string" then
					for _, p in Players:GetPlayers() do
						if string.lower(p.Name):find(string.lower(data.playerName)) then
							targetPlayer = p
							break
						end
					end
				end
			if targetPlayer then
				pcall(function()
					MessagingService:PublishAsync("DACAdminResponse", {
						cmd = "player_found",
						requestId = data.requestId,
						requestingUserId = data.requestingUserId,
						jobId = game.JobId,
						playerName = targetPlayer.Name,
						targetUserId = targetPlayer.UserId,
						playerCount = #Players:GetPlayers(),
						maxPlayers = Players.MaxPlayers,
					})
				end)
			end

		elseif data.cmd == "make_room" then
			if game.JobId == data.targetJobId then
				local targetUserId = data.targetUserId
				local adminUserId = data.adminUserId

				local protectedIds: { [number]: boolean } = {}
				if targetUserId then protectedIds[targetUserId] = true end
				if adminUserId then protectedIds[adminUserId] = true end

				if targetUserId then
					local targetPlayer = Players:GetPlayerByUserId(targetUserId)
					if targetPlayer then
						for _, p in Players:GetPlayers() do
							if p.UserId ~= targetUserId then
								local isFriend = false
								pcall(function()
									isFriend = p:IsFriendsWith(targetUserId)
								end)
								if isFriend then
									protectedIds[p.UserId] = true
								end
							end
						end
					end
				end

				local toKick: Player? = nil
				for _, p in Players:GetPlayers() do
					if not protectedIds[p.UserId] then
						toKick = p
					end
				end
				if toKick then
					toKick:Kick("Lost connection to the game server, please reconnect. (Error Code: 277)")
				end
			end
			end
		end)
	end)

	pcall(function()
		MessagingService:SubscribeAsync("DACAdminResponse", function(message)
			local data = message.Data
			if type(data) ~= "table" or data.cmd ~= "player_found" then return end

			local pending = pendingFinds[data.requestId]
			if not pending then return end
			pendingFinds[data.requestId] = nil

			local adminPlayer = pending.player
			if not adminPlayer or not adminPlayer.Parent then return end

			local isFull = data.playerCount >= data.maxPlayers

			reply(adminPlayer, `Found {data.playerName} in server {string.sub(data.jobId, 1, 8)}... ({data.playerCount}/{data.maxPlayers})`)

			if pending.priorityJoin and isFull then
				reply(adminPlayer, "Server is full. Kicking a random to make room...")
				pcall(function()
					MessagingService:PublishAsync("DACAdminFind", {
						cmd = "make_room",
						targetJobId = data.jobId,
						adminUserId = adminPlayer.UserId,
						targetUserId = data.targetUserId,
					})
				end)
				task.delay(3, function()
					if adminPlayer.Parent then
						reply(adminPlayer, "Teleporting...")
						local opts = Instance.new("TeleportOptions")
						opts.ServerInstanceId = data.jobId
						pcall(function()
							TeleportService:TeleportAsync(game.PlaceId, {adminPlayer}, opts)
						end)
					end
				end)
			else
				reply(adminPlayer, "Teleporting...")
				local opts = Instance.new("TeleportOptions")
				opts.ServerInstanceId = data.jobId
				pcall(function()
					TeleportService:TeleportAsync(game.PlaceId, {adminPlayer}, opts)
				end)
			end
		end)
	end)
end

return AdminService
