--!strict
--[[
	Server-side anti-exploit: remote rate limits, currency source checks,
	speed sampling, periodic game pass re-verification, and save sanity checks.

	POLA-603 — Client → server remotes (inventory for audits):
	RemoteEvents: StartRun, EndRun, NearMissClaim | BuyCar, EquipCar, UpgradeStat |
	BuyEgg, HatchEgg | EquipPet, UnequipPet, FusePets | Rebirth | UnlockWorld, ChangeWorld, ReturnToLobby |
	ClaimDailyReward, ClaimBattlePassTier | RedeemCode | PurchaseGamePass, PurchaseDevProduct,
	PurchaseThankYouAck | UpdateSettings | TradeRequest, TradeRespond | TutorialSkip |
	AdminCommand | MarkAchievementsSeen | DismissGroupJoinPrompt
	RemoteFunctions: GetPlayerData | GetLeaderboard | GetPassFlags | GetQuests |
	GetAchievementData | AdminAuth | FirstSessionOnboarding | RequestVehicleReset
	(Server→client only remotes are omitted.)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")

local _adminService: any = nil
local function getAdminService()
	if not _adminService then _adminService = require(script.Parent:WaitForChild("AdminService")) end
	return _adminService
end

local _carService: any = nil
local function getCarService()
	if not _carService then _carService = require(script.Parent:WaitForChild("CarService")) end
	return _carService
end

local ValidationService = {}

local PURCHASE_INTERVAL = 0.5
local MOVEMENT_INTERVAL = 0.1
-- Settings sliders can legitimately fire faster than PURCHASE_INTERVAL; keep tighter than spam.
local SETTINGS_INTERVAL = 0.08

local MOVEMENT_REMOTES: { [string]: boolean } = {
	StartRun = true,
	EndRun = true,
	-- POLA-468: two-step lane snap can fire twice within <0.5s
	RequestVehicleReset = true,
}

-- Whitelisted sources for DataManager.addCurrency / CurrencyService.add
local ALLOWED_CURRENCY_SOURCES: { [string]: boolean } = {
	run_complete = true,
	near_miss = true,
	code_redemption = true,
	daily_reward = true,
	battle_pass = true,
	dev_product = true,
	playtime = true,
	tutorial = true,
	admin = true,
	admin_global = true,
	group_join = true,
}

local purchaseLast: { [number]: { [string]: number } } = {}
local movementLast: { [number]: { [string]: number } } = {}

local speedSamplePos: { [number]: Vector3? } = {}
local speedSampleClock: { [number]: number } = {}
local speedFlagTimes: { [number]: { number } } = {}

local PASS_RECHECK_INTERVAL = 30
local lastPassRecheck: { [number]: number } = {}

local MAX_REBIRTH_SAVE = 10000
local MAX_TOTAL_PETS = 500

-- Throttle repeated rate_limit warnings (same player + remote) to avoid console/ring-buffer spam under attack.
local RATE_LIMIT_LOG_INTERVAL_SEC = 5
local rateLimitLogLast: { [number]: { [string]: number } } = {}

ValidationService.MAX_REMOTE_STRING_ID_LEN = 64
local MAX_SETTINGS_PATCH_KEYS = 32

-- One log per (player, key) per session — pet/egg remote abuse without log spam.
local sessionAnomalyLogged: { [number]: { [string]: boolean } } = {}

local function cleanupPlayer(uid: number)
	purchaseLast[uid] = nil
	movementLast[uid] = nil
	speedSamplePos[uid] = nil
	speedSampleClock[uid] = nil
	speedFlagTimes[uid] = nil
	lastPassRecheck[uid] = nil
	sessionAnomalyLogged[uid] = nil
	rateLimitLogLast[uid] = nil
end

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayer(player.UserId)
end)

function ValidationService.logViolation(player: Player, violationType: string, severity: string, detail: string?)
	getAdminService().logValidation(player, violationType, severity, detail)
end

--[[
	POLA-510: Gameplay remotes must not run while dead or without a live character.

	- Character must exist with a Humanoid and Health > 0 (not Dead state).
	- DAC_ServerRemoteBlock: optional server/admin hard-block (trusted).
	Note: We do not read client-replicated "loading" flags here — they race world-travel
	(ChangeWorld fires mid-transition) and are spoofable; character checks are authoritative.
]]
function ValidationService.canActWithReason(player: Player): (boolean, string?)
	if not player or not player.Parent then
		return false, "no_player"
	end
	if player:GetAttribute("DAC_ServerRemoteBlock") == true then
		return false, "server_block"
	end
	local char = player.Character
	if not char then
		return false, "no_character"
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false, "no_humanoid"
	end
	if hum.Health <= 0 then
		return false, "dead"
	end
	if hum:GetState() == Enum.HumanoidStateType.Dead then
		return false, "dead"
	end
	return true, nil
end

function ValidationService.canAct(player: Player): boolean
	return select(1, ValidationService.canActWithReason(player))
end

--[[
	Non-empty string id within byte length (egg/car/world keys, etc.).
]]
function ValidationService.isBoundedStringId(value: unknown, maxLen: number): boolean
	return type(value) == "string" and (value :: string) ~= "" and #(value :: string) <= maxLen
end

--[[
	Rejects oversized or non-string-keyed settings tables (DoS via huge pair iteration).
]]
function ValidationService.validateSettingsPatchShape(player: Player, patch: { [any]: any }): boolean
	local n = 0
	for k, _ in patch do
		n += 1
		if n > MAX_SETTINGS_PATCH_KEYS then
			ValidationService.logAnomalyOncePerSession(player, "settings_patch_key_flood", tostring(n))
			return false
		end
		if type(k) ~= "string" then
			ValidationService.logAnomalyOncePerSession(player, "settings_patch_bad_key", "")
			return false
		end
		if #k > 48 then
			ValidationService.logAnomalyOncePerSession(player, "settings_key_len", "")
			return false
		end
	end
	return true
end

function ValidationService.logAnomalyOncePerSession(player: Player, anomalyKey: string, detail: string?)
	local uid = player.UserId
	local bucket = sessionAnomalyLogged[uid]
	if not bucket then
		bucket = {}
		sessionAnomalyLogged[uid] = bucket
	end
	if bucket[anomalyKey] then
		return
	end
	bucket[anomalyKey] = true
	getAdminService().logValidation(player, "remote_anomaly", "medium", detail or anomalyKey)
end

function ValidationService.checkRemoteRate(player: Player, remoteName: string): boolean
	local uid = player.UserId
	local now = os.clock()
	local isMovement = MOVEMENT_REMOTES[remoteName] == true
	-- Read-only idempotent queries use shorter intervals than purchase remotes.
	local isReadQuery = remoteName == "GetPlayerData"
		or remoteName == "GetQuests"
		or remoteName == "GetAchievementData"
		or remoteName == "GetPassFlags"
		or remoteName == "MarkAchievementsSeen"
		or remoteName == "PurchaseThankYouAck"
	local interval = if isReadQuery
		then 0.12
		elseif remoteName == "GetLeaderboard"
		then 0.22
		elseif remoteName == "UpdateSettings"
		then SETTINGS_INTERVAL
		elseif remoteName == "FirstSessionOnboarding"
		then 0.2
		elseif isMovement then MOVEMENT_INTERVAL
		else PURCHASE_INTERVAL
	local bucket = if isMovement then movementLast else purchaseLast
	local sub = bucket[uid]
	if not sub then
		sub = {}
		bucket[uid] = sub
	end
	local prev = sub[remoteName]
	if prev and now - prev < interval then
		local bucketRL = rateLimitLogLast[uid]
		if not bucketRL then
			bucketRL = {}
			rateLimitLogLast[uid] = bucketRL
		end
		local lastLog = bucketRL[remoteName]
		if not lastLog or now - lastLog >= RATE_LIMIT_LOG_INTERVAL_SEC then
			bucketRL[remoteName] = now
			ValidationService.logViolation(
				player,
				"rate_limit",
				"medium",
				`remote={remoteName} interval={interval}`
			)
		end
		return false
	end
	sub[remoteName] = now
	return true
end

function ValidationService.validateCurrencySource(source: string): boolean
	return ALLOWED_CURRENCY_SOURCES[source] == true
end

local function countPets(data: any): number
	local n = 0
	if data.pets and type(data.pets) == "table" then
		for _ in data.pets do
			n += 1
		end
	end
	return n
end

--[[
	Returns false if data was patched due to invalid values (caller should persist patched data).
]]
function ValidationService.validatePlayerDataForSave(player: Player, data: any): boolean
	local clean = true
	local currencies = { "coins", "sandGranules", "icycles", "magmaCores", "infinitium" }
	for _, c in currencies do
		local v = data[c]
		if type(v) ~= "number" or v < 0 then
			ValidationService.logViolation(player, "data_store_invalid_currency", "high", c)
			data[c] = math.max(0, if type(v) == "number" then v else 0)
			clean = false
		end
	end

	local rb = data.rebirths
	if type(rb) ~= "number" or rb < 0 or rb > MAX_REBIRTH_SAVE then
		ValidationService.logViolation(player, "data_store_rebirth", "high", tostring(rb))
		data.rebirths = math.clamp(if type(rb) == "number" then rb else 0, 0, MAX_REBIRTH_SAVE)
		clean = false
	end

	local pc = countPets(data)
	if pc > MAX_TOTAL_PETS then
		ValidationService.logViolation(player, "data_store_pet_count", "high", tostring(pc))
		clean = false
	end

	return clean
end

local function getDataManager()
	return require(script.Parent.Parent:WaitForChild("DataManager"))
end

local function getMaxSpeedStudsPerSec(player: Player): number
	local data = getDataManager().get(player)
	if not data then
		return 600
	end
	local carId = data.equippedCar
	if type(carId) ~= "string" then
		return 600
	end
	local stats = getCarService().getEffectiveStats(player, carId)
	if stats and type(stats.speed) == "number" and stats.speed > 0 then
		return stats.speed
	end
	return 600
end

local function trimOldFlags(times: { number }, windowSec: number, now: number)
	local i = 1
	while i <= #times do
		if now - times[i] > windowSec then
			table.remove(times, i)
		else
			i += 1
		end
	end
end

local function onSpeedHeartbeat()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end
		local uid = player.UserId
		local pos = hrp.Position
		local lastPos = speedSamplePos[uid]
		local lastT = speedSampleClock[uid]
		if not lastPos or not lastT then
			speedSamplePos[uid] = pos
			speedSampleClock[uid] = now
			continue
		end
		if now - lastT < 1 then
			continue
		end

		local dist = (pos - lastPos).Magnitude
		local maxSpeed = getMaxSpeedStudsPerSec(player)
		local maxDist = maxSpeed * 1.5
		-- Teleport / respawn / large physics snap — reset baseline, do not flag.
		if dist > 500 then
			speedSamplePos[uid] = pos
			speedSampleClock[uid] = now
			continue
		end
		speedSamplePos[uid] = pos
		speedSampleClock[uid] = now

		if dist > maxDist then
			local flags = speedFlagTimes[uid]
			if not flags then
				flags = {}
				speedFlagTimes[uid] = flags
			end
			table.insert(flags, now)
			trimOldFlags(flags, 10, now)
			ValidationService.logViolation(
				player,
				"speed_anomaly",
				"high",
				`dist={math.floor(dist)} max={math.floor(maxDist)}`
			)
			if #flags >= 3 and not RunService:IsStudio() then
				speedFlagTimes[uid] = {}
				player:Kick("Unexpected movement detected")
			end
		end
	end
end

local function onPassRecheckHeartbeat()
	local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
	local t = os.clock()
	for _, player in Players:GetPlayers() do
		local uid = player.UserId
		local last = lastPassRecheck[uid] or 0
		if t - last < PASS_RECHECK_INTERVAL then
			continue
		end
		lastPassRecheck[uid] = t
		GamePassService.checkAllPasses(player)
	end
end

function ValidationService.init()
	RunService.Heartbeat:Connect(function()
		onSpeedHeartbeat()
		onPassRecheckHeartbeat()
	end)
end

return ValidationService
