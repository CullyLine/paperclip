--!strict
--[[
	Guided onboarding: tracks tutorialStep / tutorialComplete in DataManager,
	fires TutorialStep to the client, and advances on gameplay milestones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))

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
			title = "Welcome",
			body = "Welcome! Tap Drive to take your car on the highway.",
			targetName = "StartDriveButton",
		},
		[2] = {
			title = "First Drive",
			body = "Keep driving until your gas runs out to bank coins from your run.",
			targetName = nil,
		},
		[3] = {
			title = "First Upgrade",
			body = "Open the menu → Store, then upgrade Speed on your car.",
			targetName = "TutorialUpgradeSpeed",
		},
		[4] = {
			title = "First Egg",
			body = "Open Eggs, buy a Meadow Egg if needed, then tap Hatch.",
			targetName = "TutorialEggHatchBasic",
		},
		[5] = {
			title = "Equip your pet",
			body = "Open Garage and tap Equip on your new pet.",
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
		title = "Tutorial complete!",
		body = `You earned {BONUS_COINS} bonus coins. Have fun!`,
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
