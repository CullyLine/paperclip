--!strict
--[[
	Manages driving runs: start, distance tracking, laps, gas depletion,
	checkpoint-based coin awards, car spawning/despawning.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RobloxRunService = game:GetService("RunService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local Constants = require(DAC:WaitForChild("Constants"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))
local CheckpointConfig = require(DAC:WaitForChild("Config"):WaitForChild("CheckpointConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CarService = require(script.Parent:WaitForChild("CarService"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))
local GroupRewardService = require(script.Parent:WaitForChild("GroupRewardService"))
local FriendBonusService = require(script.Parent:WaitForChild("FriendBonusService"))
local FirstSessionOnboardingService = require(script.Parent:WaitForChild("FirstSessionOnboardingService"))
local WorldSpawnUtil = require(script.Parent:WaitForChild("WorldSpawnUtil"))

local DACRunService = {}

local function isFiniteNumber(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function positionIsPlausible(p: Vector3): boolean
	if not isFiniteNumber(p.X) or not isFiniteNumber(p.Y) or not isFiniteNumber(p.Z) then
		return false
	end
	local m = Constants.RUN_POSITION_MAX_ABS_STUDS
	return math.abs(p.X) <= m and math.abs(p.Y) <= m and math.abs(p.Z) <= m
end

local function readLaneAnchorFromCharacter(char: Model): (number, number)
	local car = char:FindFirstChild("Car") :: Model?
	if car and car.PrimaryPart then
		local pos = car.PrimaryPart.Position
		if positionIsPlausible(pos) then
			return pos.X, pos.Z
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		local pos = hrp.Position
		if positionIsPlausible(pos) then
			return pos.X, pos.Z
		end
	end
	return 0, 0
end

local function clampNonNegativeFinite(n: number, fallback: number): number
	if type(n) ~= "number" or not isFiniteNumber(n) or n < 0 then
		return fallback
	end
	return n
end

type ActiveRun = {
	player: Player,
	carId: string,
	worldId: string,
	startTime: number,
	totalDistance: number,
	currentLapDistance: number,
	laps: number,
	gasRemaining: number,
	power: number,
	acceleration: number,
	highwayLength: number,
	checkpointsHit: { [number]: boolean },
	coinsEarnedThisRun: number,
	nearMissChain: number?,
	nearMissChainAt: number?,
	nearMissLastClaim: number?,
	nearMissCoinsThisRun: number?,
	nearMissBestChain: number,
	lapStartClock: number,
	lastLapTimeSeconds: number?,
	lastVehicleResetClock: number?,
	laneCenterX: number,
	laneAnchorZ: number,
	lastPhysicsRecoveryAt: number?,
	physicsCheckAccum: number,
	currentSpeed: number,
	distanceAtMaxSpeed: number,
}

local activeRuns: { [number]: ActiveRun } = {}
local startZoneCooldowns: { [number]: number } = {}

local function nearMissComboMultiplier(streak: number): number
	if streak >= 5 then
		return 2.0
	elseif streak == 4 then
		return 1.75
	elseif streak == 3 then
		return 1.5
	elseif streak == 2 then
		return 1.25
	end
	return 1.0
end

function DACRunService.claimNearMiss(player: Player)
	local run = activeRuns[player.UserId]
	if not run then
		return
	end
	local now = os.clock()
	local lastClaim = run.nearMissLastClaim or 0
	if now - lastClaim < Constants.NEAR_MISS_CLAIM_MIN_INTERVAL then
		return
	end
	run.nearMissLastClaim = now

	local chainAt = run.nearMissChainAt or 0
	local chain = run.nearMissChain or 0
	if now - chainAt > Constants.NEAR_MISS_CHAIN_RESET_SEC then
		chain = 1
	else
		chain += 1
	end
	run.nearMissChain = chain
	run.nearMissChainAt = now
	if chain > (run.nearMissBestChain or 0) then
		run.nearMissBestChain = chain
	end

	local mult = nearMissComboMultiplier(chain)
	local rawFloat = Constants.NEAR_MISS_BASE_COINS * mult
	if not isFiniteNumber(rawFloat) or rawFloat < 0 then
		return
	end
	local raw = math.floor(rawFloat + 0.5)
	local spent = run.nearMissCoinsThisRun or 0
	local capLeft = Constants.NEAR_MISS_MAX_COINS_PER_RUN - spent
	if capLeft <= 0 then
		return
	end
	local grant = math.min(raw, capLeft)
	run.nearMissCoinsThisRun = spent + grant

	CurrencyService.add(player, "coins", grant, "near_miss")
	Remotes.getEvent("NearMissClaim"):FireClient(player, {
		amount = grant,
		streak = chain,
		multiplier = mult,
	})
end

local function utcDateString(): string
	local t = os.date("!*t", os.time())
	return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

-- Car model spawning/despawning

local function prepareDrivingCarModel(car: Model)
	if not car.PrimaryPart then
		local p = car:FindFirstChildWhichIsA("BasePart", true)
		if p and p:IsA("BasePart") then
			car.PrimaryPart = p
		end
	end
	for _, d in car:GetDescendants() do
		if d:IsA("BodyMover") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.Massless = true
		end
	end
end

local function destroyCarForPlayer(player: Player)
	local char = player.Character
	if not char then return end
	local existing = char:FindFirstChild("Car")
	if existing then existing:Destroy() end
end

local function spawnCarForPlayer(player: Player, carId: string): boolean
	local folder = ServerStorage:FindFirstChild("CarModels")
	if not folder or not folder:IsA("Folder") then
		warn("[DAC] ServerStorage.CarModels folder missing")
		return false
	end
	local templateName = CarConfig.getCarTemplateName(carId)
	if not templateName then return false end
	local template = folder:FindFirstChild(templateName)
	if not template or not template:IsA("Model") then
		warn("[DAC] No car model '" .. tostring(templateName) .. "' in ServerStorage.CarModels (carId=" .. carId .. ")")
		return false
	end
	local char = player.Character
	if not char then return false end
	destroyCarForPlayer(player)
	local car = template:Clone()
	car.Name = "Car"
	prepareDrivingCarModel(car)
	car.Parent = char
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and car.PrimaryPart then
		car:PivotTo(root.CFrame * CFrame.new(0, -3, 0))
	end
	return true
end

local function hookPlayerCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if activeRuns[player.UserId] then
				DACRunService.endRun(player)
			end
		end)
	end
	if activeRuns[player.UserId] then
		local run = activeRuns[player.UserId]
		task.defer(function()
			if activeRuns[player.UserId] ~= run then
				return
			end
			if spawnCarForPlayer(player, run.carId) then
				local lx, lz = readLaneAnchorFromCharacter(character)
				run.laneCenterX = lx
				run.laneAnchorZ = lz
			end
		end)
	end
end

-- Checkpoint reward logic

local function getCheckpointThresholds(highwayLength: number): { number }
	local count = Constants.CHECKPOINT_COUNT
	local thresholds = {}
	for i = 1, count do
		thresholds[i] = highwayLength * i / count
	end
	return thresholds
end

local function tryAwardCheckpoints(run: ActiveRun)
	local thresholds = getCheckpointThresholds(run.highwayLength)
	local rewards = CheckpointConfig.getRewards(run.worldId)
	local data = DataManager.get(run.player)
	if not data then
		return
	end

	local upgrades = data.rebirthUpgrades or {}
	local currencyMult = 1 + ((upgrades :: any).moreCurrency or 0) * 5 / 100

	for i, threshold in thresholds do
		if run.currentLapDistance >= threshold and not run.checkpointsHit[i] then
			run.checkpointsHit[i] = true
			local baseReward = rewards[i] or 0
			local finalReward = math.floor(baseReward * currencyMult)

			CurrencyService.add(run.player, "coins", finalReward, "checkpoint")
			run.coinsEarnedThisRun += finalReward

			if type(data.stats) == "table" then
				data.stats.totalCoinsEarned = (data.stats.totalCoinsEarned or 0) + finalReward
			end

			Remotes.getEvent("CheckpointHit"):FireClient(run.player, {
				checkpoint = i,
				totalCheckpoints = Constants.CHECKPOINT_COUNT,
				reward = finalReward,
				totalCoinsThisRun = run.coinsEarnedThisRun,
			})
		end
	end
end

-- Run lifecycle

function DACRunService.startRun(player: Player): (boolean, string?)
	if activeRuns[player.UserId] then
		return false, "Already in a run"
	end

	local data = DataManager.get(player)
	if not data then return false, "No data" end

	local carId = data.equippedCar
	local stats = CarService.getEffectiveStats(player, carId)
	if not stats then return false, "No car equipped" end

	local gas = stats.gas
	if type(gas) == "number" and gas < 1e9 and gas <= 0 then
		return false, "No fuel"
	end

	local world = WorldConfig.Worlds[data.currentWorld]
	if not world then return false, "Invalid world" end

	local gas0 = stats.gas
	if not isFiniteNumber(gas0) or gas0 < 0 then
		return false, "Invalid vehicle stats"
	end
	local pow0 = clampNonNegativeFinite(stats.power, 0)
	local accel0 = clampNonNegativeFinite(stats.acceleration, 30)

	if not spawnCarForPlayer(player, carId) then
		local tmpl = CarConfig.getCarTemplateName(carId) or carId
		return false, "No car model '" .. tostring(tmpl) .. "' in ServerStorage.CarModels"
	end

	WorldSpawnUtil.teleportPlayerToStartZone(player, data.currentWorld)

	local char0 = player.Character
	local lc, lz = 0, 0
	if char0 then
		lc, lz = readLaneAnchorFromCharacter(char0)
	end

	activeRuns[player.UserId] = {
		player = player,
		carId = carId,
		worldId = data.currentWorld,
		startTime = os.clock(),
		totalDistance = 0,
		currentLapDistance = 0,
		laps = 0,
		gasRemaining = gas0,
		power = pow0,
		acceleration = accel0,
		highwayLength = world.highwayLength,
		checkpointsHit = {},
		coinsEarnedThisRun = 0,
		nearMissChain = 0,
		nearMissChainAt = 0,
		nearMissLastClaim = 0,
		nearMissCoinsThisRun = 0,
		nearMissBestChain = 0,
		lapStartClock = os.clock(),
		lastLapTimeSeconds = nil,
		lastVehicleResetClock = nil,
		laneCenterX = lc,
		laneAnchorZ = lz,
		lastPhysicsRecoveryAt = nil,
		physicsCheckAccum = 0,
		currentSpeed = 0,
		distanceAtMaxSpeed = 0,
	}

	local today = utcDateString()
	local isFirstRunOfDay = data.lastRunOfDayDate ~= today

	Remotes.getEvent("StartRun"):FireClient(player, {
		carId = carId,
		stats = stats,
		worldId = data.currentWorld,
		highwayLength = world.highwayLength,
		isFirstRunOfDay = isFirstRunOfDay,
		checkpointCount = Constants.CHECKPOINT_COUNT,
	})

	TutorialService.onStartRun(player)

	return true, nil
end

local PHYS_CHECK_INTERVAL = 0.45

local function tryRecoverRunPhysics(run: ActiveRun): ()
	local now = os.clock()
	local last = run.lastPhysicsRecoveryAt
	if last and (now - last) < Constants.RUN_POSITION_RECOVERY_COOLDOWN_SEC then
		return
	end

	local plr = run.player
	local char = plr.Character
	if not char then
		return
	end

	local car = char:FindFirstChild("Car") :: Model?
	local needFix = false
	if not car or not car.PrimaryPart then
		needFix = true
	else
		local p = car.PrimaryPart.Position
		if not positionIsPlausible(p) then
			needFix = true
		end
	end

	if not needFix then
		return
	end

	run.lastPhysicsRecoveryAt = now
	if not car or not car.PrimaryPart then
		spawnCarForPlayer(plr, run.carId)
		car = char:FindFirstChild("Car") :: Model?
		if car and car.PrimaryPart then
			local p = car.PrimaryPart.Position
			run.laneCenterX = p.X
			run.laneAnchorZ = p.Z
		end
	end
	if car and car.PrimaryPart then
		local y = car.PrimaryPart.Position.Y
		if not isFiniteNumber(y) then
			y = 0
		end
		local z = car.PrimaryPart.Position.Z
		if not isFiniteNumber(z) then
			z = run.laneAnchorZ
		end
		car:PivotTo(CFrame.new(run.laneCenterX, y, z))
	end
end

function DACRunService.tick(dt: number)
	for _, run in activeRuns do
		if not run.player.Parent then
			DACRunService.finalizeRunOnLeave(run.player)
			continue
		end

		local safeDt = math.min(dt, 0.25)
		run.physicsCheckAccum += safeDt
		if run.physicsCheckAccum >= PHYS_CHECK_INTERVAL then
			run.physicsCheckAccum = 0
			tryRecoverRunPhysics(run)
		end

		local gasConsumed = Constants.GAS_DRAIN_RATE * safeDt
		if not isFiniteNumber(run.gasRemaining) then
			DACRunService.endRun(run.player)
			continue
		end
		run.gasRemaining -= gasConsumed

		if run.gasRemaining <= 0 then
			DACRunService.endRun(run.player)
			continue
		end

		local maxSpeed = run.power
		if not isFiniteNumber(maxSpeed) or maxSpeed < 0 then
			local st = CarService.getEffectiveStats(run.player, run.carId)
			maxSpeed = if st and isFiniteNumber(st.power) and st.power >= 0 then st.power else 0
			run.power = maxSpeed
		end

		local accelTime = run.acceleration
		if not isFiniteNumber(accelTime) or accelTime <= 0 then
			accelTime = 30
		end
		local accelRate = maxSpeed / accelTime
		run.currentSpeed = math.min(maxSpeed, run.currentSpeed + accelRate * safeDt)
		local spd = run.currentSpeed

		if spd >= maxSpeed * 0.98 then
			run.distanceAtMaxSpeed += spd * safeDt
		end

		local distanceTraveled = spd * safeDt
		local maxStep = spd * safeDt * 1.25
		if not isFiniteNumber(distanceTraveled) or not isFiniteNumber(maxStep) then
			distanceTraveled = 0
		else
			distanceTraveled = math.min(distanceTraveled, maxStep)
		end
		if not isFiniteNumber(run.totalDistance) then
			run.totalDistance = 0
		end
		run.totalDistance += distanceTraveled
		run.currentLapDistance += distanceTraveled
		if not isFiniteNumber(run.currentLapDistance) or run.currentLapDistance < 0 then
			run.currentLapDistance = 0
		end

		tryAwardCheckpoints(run)

		if run.currentLapDistance >= run.highwayLength then
			run.laps += 1
			run.currentLapDistance = run.currentLapDistance - run.highwayLength
			run.checkpointsHit = {}

			local nowClock = os.clock()
			local lapTimeSeconds = math.max(0, nowClock - run.lapStartClock)
			run.lapStartClock = nowClock

			local prevLapInRun = run.lastLapTimeSeconds
			local lapDeltaSecondsFromLast: number? = nil
			if type(prevLapInRun) == "number" then
				lapDeltaSecondsFromLast = lapTimeSeconds - prevLapInRun
			end

			local isPersonalBest = false
			local lapDeltaSecondsFromBest: number? = nil
			local data = DataManager.get(run.player)
			if data and type(data.stats) == "table" then
				local statsBlock = data.stats
				local prevBest = statsBlock.bestLapSeconds
				if type(prevBest) == "number" then
					lapDeltaSecondsFromBest = lapTimeSeconds - prevBest
				end
				if type(prevBest) ~= "number" then
					isPersonalBest = true
					statsBlock.bestLapSeconds = lapTimeSeconds
					DataManager.scheduleSave(run.player)
				elseif lapTimeSeconds < prevBest then
					isPersonalBest = true
					statsBlock.bestLapSeconds = lapTimeSeconds
					DataManager.scheduleSave(run.player)
				end
			end

			run.lastLapTimeSeconds = lapTimeSeconds

			Remotes.getEvent("RunUpdate"):FireClient(run.player, {
				type = "lap",
				laps = run.laps,
				totalDistance = run.totalDistance,
				gasRemaining = run.gasRemaining,
				isPersonalBest = isPersonalBest,
				lapTimeSeconds = lapTimeSeconds,
				lapDeltaSecondsFromBest = lapDeltaSecondsFromBest,
				lapDeltaSecondsFromLast = lapDeltaSecondsFromLast,
				coinsEarnedThisRun = run.coinsEarnedThisRun,
			})

			if
				GamePassService.hasPass(run.player, "auto_collect")
				and run.laps >= Constants.AUTO_COLLECT_LAPS_BEFORE_BANK
			then
				DACRunService.endRun(run.player)
				continue
			end
		end
	end
end

function DACRunService.endRun(player: Player)
	local run = activeRuns[player.UserId]
	if not run then return end

	local data = DataManager.get(player)
	if not data then
		activeRuns[player.UserId] = nil
		return
	end

	activeRuns[player.UserId] = nil

	GroupRewardService.syncGroupMembership(player)
	GroupRewardService.tryGrantJoinRewards(player)

	data.stats.totalDistance += run.totalDistance
	data.stats.totalLaps += run.laps

	if type(data.stats.totalRunsCompleted) ~= "number" then
		data.stats.totalRunsCompleted = 0
	end
	local prevRuns = data.stats.totalRunsCompleted
	if prevRuns == 0 then
		FirstSessionOnboardingService.markPendingFirstPayout(player)
	end
	data.stats.totalRunsCompleted = prevRuns + 1
	MilestoneCeremonyService.tryTotalRunsMilestones(player, data, prevRuns, data.stats.totalRunsCompleted)

	local isPersonalBest = false
	local statsBlock = data.stats
	if type(statsBlock) == "table" then
		if type(statsBlock.bestSingleRun) ~= "number" then
			statsBlock.bestSingleRun = 0
		end
		local prevBest = statsBlock.bestSingleRun
		isPersonalBest = run.totalDistance > prevBest
		statsBlock.bestSingleRun = math.max(prevBest, run.totalDistance)
	end

	AchievementService.onRunEnded(player, {
		worldId = run.worldId,
		speed = run.power,
		maxNearMissChain = run.nearMissBestChain or 0,
		laps = run.laps,
	})

	destroyCarForPlayer(player)

	startZoneCooldowns[player.UserId] = os.clock() + 3

	task.defer(function()
		if player.Parent then
			WorldSpawnUtil.teleportPlayerToWorldLobby(player, run.worldId)
		end
	end)

	local nearMissChain = run.nearMissBestChain or 0
	if not isFiniteNumber(nearMissChain) or nearMissChain < 0 then
		nearMissChain = 0
	end
	local nmRaw = run.nearMissCoinsThisRun or 0
	local nearMissBonusCoins = if isFiniteNumber(nmRaw) and nmRaw >= 0 then math.floor(nmRaw) else 0

	TutorialService.onRunEnd(player, run.coinsEarnedThisRun)

	Remotes.getEvent("EndRun"):FireClient(player, {
		totalDistance = run.totalDistance,
		laps = run.laps,
		coinsEarned = run.coinsEarnedThisRun,
		nearMissBestChain = nearMissChain,
		nearMissBonusCoins = nearMissBonusCoins,
		currencyKey = "coins",
		currencyName = WorldConfig.getCurrencyName(run.worldId),
		isPersonalBest = isPersonalBest,
	})
end

function DACRunService.isInRun(player: Player): boolean
	return activeRuns[player.UserId] ~= nil
end

function DACRunService.getRunState(player: Player): ActiveRun?
	return activeRuns[player.UserId]
end

function DACRunService.adminSetGasRemaining(player: Player, amount: number): boolean
	local run = activeRuns[player.UserId]
	if not run then
		return false
	end
	run.gasRemaining = math.max(0, amount)
	return true
end

function DACRunService.adminAbortRunNoPayout(player: Player)
	activeRuns[player.UserId] = nil
end

function DACRunService.finalizeRunOnLeave(player: Player)
	if activeRuns[player.UserId] == nil then
		return
	end
	DACRunService.endRun(player)
end

-- Physical start zones

local START_ZONE_COOLDOWN = 2

local function wireStartZone(part: BasePart)
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local now = os.clock()
		local last = startZoneCooldowns[player.UserId] or 0
		if now - last < START_ZONE_COOLDOWN then return end
		startZoneCooldowns[player.UserId] = now

		if activeRuns[player.UserId] then return end

		local success, err = DACRunService.startRun(player)
		if not success and err then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = err,
			})
		end
	end)
end

local function wireAllStartZones()
	local worlds = game:GetService("Workspace"):FindFirstChild("Worlds")
	if not worlds then return end
	for _, world in worlds:GetChildren() do
		local startModel = world:FindFirstChild("Start")
		if startModel then
			for _, ch in startModel:GetChildren() do
				if ch:IsA("BasePart") then
					wireStartZone(ch)
				end
			end
		end
	end
end

function DACRunService.init()
	Remotes.getEvent("StartRun").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "StartRun") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "StartRun", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = DACRunService.startRun(player)
		if not success then
			local payload = {
				type = "error",
				message = err or "Failed to start run",
			}
			if err == "No fuel" then
				payload.code = "fuel_empty"
			end
			NotificationDispatchService.notify(player, payload)
		end
	end)

	Remotes.getEvent("EndRun").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "EndRun") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "EndRun", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		DACRunService.endRun(player)
	end)

	Remotes.getEvent("NearMissClaim").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "NearMissClaim") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if not RemoteCooldown.allow(player, "NearMissClaim", Constants.NEAR_MISS_CLAIM_MIN_INTERVAL) then
			return
		end
		DACRunService.claimNearMiss(player)
	end)

	Remotes.getFunction("RequestVehicleReset").OnServerInvoke = function(player: Player)
		if not ValidationService.checkRemoteRate(player, "RequestVehicleReset") then
			return { ok = false, reason = "rate_limited" }
		end
		if not ValidationService.canAct(player) then
			return { ok = false, reason = "cannot_act" }
		end
		if not RemoteCooldown.allow(player, "RequestVehicleReset", 0.12) then
			return { ok = false, reason = "rate_limited" }
		end
		local run = activeRuns[player.UserId]
		if not run then
			return { ok = false, reason = "no_run" }
		end
		local now = os.clock()
		local last = run.lastVehicleResetClock
		if last and (now - last) < Constants.VEHICLE_RESET_COOLDOWN_SEC then
			local rem = Constants.VEHICLE_RESET_COOLDOWN_SEC - (now - last)
			return { ok = false, reason = "cooldown", remainingSec = rem }
		end
		run.lastVehicleResetClock = now
		local char = player.Character
		local car = char and char:FindFirstChild("Car") :: Model?
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if car and car.PrimaryPart then
			local z = car.PrimaryPart.Position.Z
			local y = car.PrimaryPart.Position.Y
			if not isFiniteNumber(z) then
				z = run.laneAnchorZ
			end
			if not isFiniteNumber(y) then
				y = 0
			end
			car:PivotTo(CFrame.new(run.laneCenterX, y, z))
		end
		if hrp then
			local hy = hrp.Position.Y
			local hz = hrp.Position.Z
			if not isFiniteNumber(hy) then
				hy = 0
			end
			if not isFiniteNumber(hz) then
				hz = run.laneAnchorZ
			end
			hrp.CFrame = CFrame.new(run.laneCenterX, hy, hz)
		end
		return { ok = true }
	end

	RobloxRunService.Heartbeat:Connect(function(dt)
		DACRunService.tick(dt)
	end)

	wireAllStartZones()

	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			hookPlayerCharacter(player, character)
		end)
		if player.Character then
			hookPlayerCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			hookPlayerCharacter(player, character)
		end)
	end)
end

return DACRunService
