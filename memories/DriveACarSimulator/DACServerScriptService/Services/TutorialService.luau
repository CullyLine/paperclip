--!strict
--[[
	Guided onboarding: tracks tutorialStep / tutorialComplete in DataManager,
	fires TutorialStep to the client, and advances on gameplay milestones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local TutorialService = {}

local BONUS_COINS = 1000

local function ownedCarCount(data: any): number
	local n = 0
	for _ in data.cars do
		n += 1
	end
	return n
end

function TutorialService.shouldSkipTutorial(data: any): boolean
	if data.tutorialComplete == true then
		return true
	end
	if ownedCarCount(data) > 1 then
		return true
	end
	return false
end

function TutorialService.applySkipForReturningPlayer(data: any)
	data.tutorialComplete = true
	data.tutorialStep = 6
end

local function push(player: Player, data: any)
	if data.tutorialComplete then
		Remotes.getEvent("TutorialStep"):FireClient(player, {
			step = 0,
			title = "",
			body = "",
			targetName = nil :: string?,
			done = true,
		})
		return
	end

	local step = data.tutorialStep or 0
	if step < 1 or step > 5 then
		return
	end

	local payloads: { [number]: { title: string, body: string, targetName: string? } } = {
		[1] = {
			title = MicrocopyConfig.FirstSessionTutorialStep1Title,
			body = MicrocopyConfig.FirstSessionTutorialStep1Body,
			-- No named UI target: first runs start by entering the world's Start zone (see RunService start pads).
			targetName = nil,
		},
		[2] = {
			title = MicrocopyConfig.FirstSessionTutorialStep2Title,
			body = MicrocopyConfig.FirstSessionTutorialStep2Body,
			targetName = nil,
		},
		[3] = {
			title = MicrocopyConfig.FirstSessionTutorialStep3Title,
			body = MicrocopyConfig.FirstSessionTutorialStep3Body,
			targetName = "TutorialUpgradeSpeed",
		},
		-- Egg shop slots are named by egg id (see UIController.wireEggStorePanel); Meadow = basic_egg.
		[4] = {
			title = MicrocopyConfig.FirstSessionTutorialStep4Title,
			body = MicrocopyConfig.FirstSessionTutorialStep4Body,
			targetName = "basic_egg",
		},
		[5] = {
			title = MicrocopyConfig.FirstSessionTutorialStep5Title,
			body = MicrocopyConfig.FirstSessionTutorialStep5Body,
			targetName = "TutorialPetEquipFirst",
		},
	}

	local p = payloads[step]
	if not p then
		return
	end

	Remotes.getEvent("TutorialStep"):FireClient(player, {
		step = step,
		title = p.title,
		body = p.body,
		targetName = p.targetName,
		done = false,
	})
end

function TutorialService.sync(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	push(player, data)
end

function TutorialService.handlePlayerJoin(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end

	if TutorialService.shouldSkipTutorial(data) then
		if not data.tutorialComplete then
			TutorialService.applySkipForReturningPlayer(data)
			Remotes.getEvent("DataUpdate"):FireClient(player, data)
		end
		Remotes.getEvent("TutorialStep"):FireClient(player, {
			step = 0,
			title = "",
			body = "",
			targetName = nil,
			done = true,
		})
		return
	end

	if not data.tutorialStep or data.tutorialStep == 0 then
		data.tutorialStep = 1
	end
	push(player, data)
end

function TutorialService.onStartRun(player: Player)
	local data = DataManager.get(player)
	if not data or data.tutorialComplete then
		return
	end
	if data.tutorialStep ~= 1 then
		return
	end
	data.tutorialStep = 2
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	push(player, data)
end

function TutorialService.onRunEnd(player: Player, coinsEarned: number)
	local data = DataManager.get(player)
	if not data or data.tutorialComplete then
		return
	end
	if data.tutorialStep ~= 2 then
		return
	end
	if coinsEarned <= 0 then
		return
	end
	data.tutorialStep = 3
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	push(player, data)
end

function TutorialService.onUpgrade(player: Player, _stat: string)
	local data = DataManager.get(player)
	if not data or data.tutorialComplete then
		return
	end
	if data.tutorialStep ~= 3 then
		return
	end
	data.tutorialStep = 4
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	push(player, data)
end

function TutorialService.onHatch(player: Player)
	local data = DataManager.get(player)
	if not data or data.tutorialComplete then
		return
	end
	if data.tutorialStep ~= 4 then
		return
	end
	data.tutorialStep = 5
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	push(player, data)
end

function TutorialService.onEquipPet(player: Player)
	local data = DataManager.get(player)
	if not data or data.tutorialComplete then
		return
	end
	if data.tutorialStep ~= 5 then
		return
	end
	data.tutorialStep = 6
	CurrencyService.add(player, "coins", BONUS_COINS, "tutorial")
	data.tutorialComplete = true
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	Remotes.getEvent("TutorialStep"):FireClient(player, {
		step = 6,
		title = "You're ready to grind!",
		body = `Here's {BONUS_COINS} bonus coins to spend! Next goals: keep upgrading, hatch rarer pets, and Rebirth for permanent speed. Check Store & Game Passes anytime for extra boosts — happy driving!`,
		targetName = nil :: string?,
		done = true,
	})
end

function TutorialService.skipTutorial(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end
	data.tutorialComplete = true
	data.tutorialStep = 6
	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	Remotes.getEvent("TutorialStep"):FireClient(player, {
		step = 0,
		title = "",
		body = "",
		targetName = nil,
		done = true,
	})
end

function TutorialService.init()
	Remotes.getEvent("TutorialSkip").OnServerEvent:Connect(function(player)
		if not ValidationService.checkRemoteRate(player, "TutorialSkip") then
			return
		end
		TutorialService.skipTutorial(player)
	end)
end

return TutorialService
