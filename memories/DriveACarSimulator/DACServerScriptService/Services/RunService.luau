--!strict
--[[
	Manages driving runs: start, distance tracking, laps, gas depletion, payout.
	Car spawning/despawning, physical start zones, anti-cheat, quest/BP integration.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RobloxRunService = game:GetService("RunService")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))
local CarConfig = require(DAC:WaitForChild("Config"):WaitForChild("CarConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CarService = require(script.Parent:WaitForChild("CarService"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local GamePassService = require(script.Parent:WaitForChild("GamePassService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local BattlePassService = require(script.Parent:WaitForChild("BattlePassService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local DACRunService = {}

local function utcDateString(): string
	local t = os.date("!*t", os.time())
	return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
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
	speed: number,
	power: number,
	highwayLength: number,
}

local activeRuns: { [number]: ActiveRun } = {}

-- Car model spawning/despawning

local function prepareDrivingCarModel(car: Model)
	if not car.PrimaryPart then
		local p = car:FindFirstChildWhichIsA("BasePart", true)
		if p and p:IsA("BasePart") then
			car.PrimaryPart = p
		end
	end
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
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
			if activeRuns[player.UserId] == run then
				spawnCarForPlayer(player, run.carId)
			end
		end)
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

	local world = WorldConfig.Worlds[data.currentWorld]
	if not world then return false, "Invalid world" end

	activeRuns[player.UserId] = {
		player = player,
		carId = carId,
		worldId = data.currentWorld,
		startTime = os.clock(),
		totalDistance = 0,
		currentLapDistance = 0,
		laps = 0,
		gasRemaining = stats.gas,
		speed = stats.speed,
		power = stats.power,
		highwayLength = world.highwayLength,
	}

	if not spawnCarForPlayer(player, carId) then
		activeRuns[player.UserId] = nil
		local tmpl = CarConfig.getCarTemplateName(carId) or carId
		return false, "No car model '" .. tostring(tmpl) .. "' in ServerStorage.CarModels"
	end

	Remotes.getEvent("StartRun"):FireClient(player, {
		carId = carId,
		stats = stats,
		worldId = data.currentWorld,
		highwayLength = world.highwayLength,
	})

	TutorialService.onStartRun(player)

	return true, nil
end

function DACRunService.tick(dt: number)
	for userId, run in activeRuns do
		if not run.player.Parent then
			activeRuns[userId] = nil
			continue
		end

		local safeDt = math.min(dt, 0.25)
		local gasConsumed = Constants.GAS_DRAIN_RATE * safeDt
		run.gasRemaining -= gasConsumed

		if run.gasRemaining <= 0 then
			DACRunService.endRun(run.player)
			continue
		end

		local distanceTraveled = run.speed * safeDt
		local maxStep = run.speed * safeDt * 1.25
		distanceTraveled = math.min(distanceTraveled, maxStep)
		run.totalDistance += distanceTraveled
		run.currentLapDistance += distanceTraveled

		if run.currentLapDistance >= run.highwayLength then
			run.laps += 1
			run.currentLapDistance = run.currentLapDistance - run.highwayLength

			Remotes.getEvent("RunUpdate"):FireClient(run.player, {
				type = "lap",
				laps = run.laps,
				totalDistance = run.totalDistance,
				gasRemaining = run.gasRemaining,
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

	activeRuns[player.UserId] = nil

	local data = DataManager.get(player)
	if not data then return end

	local world = WorldConfig.Worlds[run.worldId]
	local coinMultiplier = world and world.coinMultiplier or 1

	local baseCoins = run.totalDistance * Constants.DISTANCE_TO_COINS_RATE
	local worldCoins = baseCoins * coinMultiplier

	local equippedPets = {}
	for _, pet in data.pets do
		if pet.equipped then
			table.insert(equippedPets, pet)
		end
	end
	local petModifier = PetService.getEffectivePetCoinModifier(player, equippedPets)
	local petCoins = worldCoins * petModifier

	local statsForPayout = CarService.getEffectiveStats(player, run.carId)
	local effectivePower = if statsForPayout then statsForPayout.power else 0
	local powerMultiplier = 1 + effectivePower * 0.01
	local afterPower = petCoins * powerMultiplier

	local today = utcDateString()
	local runOfDayMult = 1
	local isFirstRunOfDay = data.lastRunOfDayDate ~= today
	if isFirstRunOfDay then
		runOfDayMult = 3
		data.lastRunOfDayDate = today
	end

	local passMultiplier = 1
	if GamePassService.hasPass(player, "double_coins") then
		passMultiplier = 2
	end

	local PremiumService = require(script.Parent:WaitForChild("PremiumService"))
	local premiumMultiplier = 1
	if PremiumService.isPremium(player) then
		premiumMultiplier = 1 + Constants.PREMIUM_COIN_BONUS
	end

	local totalCoins = math.floor(afterPower * passMultiplier * premiumMultiplier * runOfDayMult)
	if GamePassService.hasPass(player, "coin_boost") then
		totalCoins = math.floor(totalCoins * 1.1)
	end

	local founderMult = EventService.getFounderCoinMultiplier()
	local awardedCoins = CurrencyService.add(player, "coins", totalCoins, "run_complete")

	TutorialService.onRunEnd(player, awardedCoins)

	BattlePassService.addXP(player, run.totalDistance)
	QuestService.onRunEnd(player, {
		distance = run.totalDistance,
		laps = run.laps,
		coinsEarned = awardedCoins,
		worldId = run.worldId,
	})

	local skullDrops = math.min(10, math.floor(run.totalDistance / 50_000))
	if skullDrops > 0 then
		CurrencyService.add(player, "skulls", skullDrops, "run_complete")
	end

	data.stats.totalDistance += run.totalDistance
	data.stats.totalLaps += run.laps

	destroyCarForPlayer(player)

	Remotes.getEvent("EndRun"):FireClient(player, {
		totalDistance = run.totalDistance,
		laps = run.laps,
		coinsEarned = awardedCoins,
		skullsEarned = skullDrops,
		runOfDayMultiplier = runOfDayMult,
		runOfDayCelebration = runOfDayMult == 3,
		founderMultiplier = founderMult,
		breakdown = {
			base = math.floor(baseCoins),
			worldMultiplier = coinMultiplier,
			petModifier = petModifier,
			powerMultiplier = powerMultiplier,
			passMultiplier = passMultiplier,
			premiumMultiplier = premiumMultiplier,
			runOfDayMultiplier = runOfDayMult,
			founderMultiplier = founderMult,
		},
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

-- Physical start zones

local startZoneCooldowns: { [number]: number } = {}
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
			Remotes.getEvent("Notification"):FireClient(player, {
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
		if not RemoteCooldown.allow(player, "StartRun", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local success, err = DACRunService.startRun(player)
		if not success then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Failed to start run",
			})
		end
	end)

	Remotes.getEvent("EndRun").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "EndRun") then
			return
		end
		if not RemoteCooldown.allow(player, "EndRun", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		DACRunService.endRun(player)
	end)

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
