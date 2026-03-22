--!strict
--[[
	Server-side anti-exploit: remote rate limits, currency source checks,
	speed sampling, periodic game pass re-verification, and save sanity checks.
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
}

-- Whitelisted sources for DataManager.addCurrency / CurrencyService.add
local ALLOWED_CURRENCY_SOURCES: { [string]: boolean } = {
	run_complete = true,
	code_redemption = true,
	daily_reward = true,
	battle_pass = true,
	dev_product = true,
	playtime = true,
	tutorial = true,
	admin = true,
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

local function cleanupPlayer(uid: number)
	purchaseLast[uid] = nil
	movementLast[uid] = nil
	speedSamplePos[uid] = nil
	speedSampleClock[uid] = nil
	speedFlagTimes[uid] = nil
	lastPassRecheck[uid] = nil
end

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayer(player.UserId)
end)

function ValidationService.logViolation(player: Player, violationType: string, severity: string, detail: string?)
	getAdminService().logValidation(player, violationType, severity, detail)
end

function ValidationService.checkRemoteRate(player: Player, remoteName: string): boolean
	local uid = player.UserId
	local now = os.clock()
	local isMovement = MOVEMENT_REMOTES[remoteName] == true
	local interval = if remoteName == "UpdateSettings"
		then SETTINGS_INTERVAL
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
		ValidationService.logViolation(
			player,
			"rate_limit",
			"medium",
			`remote={remoteName} interval={interval}`
		)
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
	local currencies = { "coins", "gems", "crystals", "skulls" }
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
