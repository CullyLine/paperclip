local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DMReplicatedStorage = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local ProfileService = require(DMReplicatedStorage:WaitForChild("ProfileService"))

local PROFILE_TEMPLATE = {
	level = 1,
	xp = 0,
	totalXp = 0,
	unlockedVehicles = { "all_rounder" },
	selectedVehicle = "all_rounder",
	racesPlayed = 0,
	racesFinished = 0,
	bestPlacements = {},
	statPoints = 0,
	stats = {
		speed = 0,
		acceleration = 0,
		handling = 0,
		durability = 0,
		recovery = 0,
	},
	cosmetics = {},
	currency = 0,
	settings = {},
}

local STORE_NAME = "DownhillMadness_PlayerData"

local ProfileStore = ProfileService.GetProfileStore(STORE_NAME, PROFILE_TEMPLATE)

local Profiles: { [Player]: any } = {}

----- XP / Level Curve -----

local BASE_XP = 100
local XP_INCREMENT = 50

local function xpForLevel(level: number): number
	return BASE_XP + (level - 1) * XP_INCREMENT
end

----- Signal -----

local ProfileLoaded = Instance.new("BindableEvent")
ProfileLoaded.Name = "ProfileLoaded"
ProfileLoaded.Parent = ReplicatedStorage

----- Module exposed via _G for other server scripts -----

local ProfileManager = {}

function ProfileManager.GetProfile(player: Player)
	return Profiles[player]
end

function ProfileManager.SetValue(player: Player, key: string, value: any)
	local profile = Profiles[player]
	if profile then
		profile.Data[key] = value
	end
end

function ProfileManager.GetValue(player: Player, key: string): any
	local profile = Profiles[player]
	if profile then
		return profile.Data[key]
	end
	return nil
end

function ProfileManager.IncrementValue(player: Player, key: string, amount: number)
	local profile = Profiles[player]
	if profile then
		local current = profile.Data[key]
		if type(current) == "number" then
			profile.Data[key] = current + amount
		end
	end
end

function ProfileManager.AddToList(player: Player, key: string, item: any)
	local profile = Profiles[player]
	if profile then
		local list = profile.Data[key]
		if type(list) == "table" then
			table.insert(list, item)
		end
	end
end

function ProfileManager.RemoveFromList(player: Player, key: string, item: any)
	local profile = Profiles[player]
	if profile then
		local list = profile.Data[key]
		if type(list) == "table" then
			local idx = table.find(list, item)
			if idx then
				table.remove(list, idx)
			end
		end
	end
end

function ProfileManager.GetLevel(player: Player): number
	return ProfileManager.GetValue(player, "level") or 1
end

function ProfileManager.GetXP(player: Player): (number, number)
	local xp = ProfileManager.GetValue(player, "xp") or 0
	local level = ProfileManager.GetLevel(player)
	return xp, xpForLevel(level)
end

function ProfileManager.AwardXP(player: Player, amount: number): { leveledUp: boolean, newLevel: number, xpGained: number }
	local profile = Profiles[player]
	if not profile then
		return { leveledUp = false, newLevel = 1, xpGained = 0 }
	end

	local data = profile.Data
	data.xp = (data.xp or 0) + amount
	data.totalXp = (data.totalXp or 0) + amount

	local leveledUp = false
	local startLevel = data.level or 1

	while data.xp >= xpForLevel(data.level) do
		data.xp = data.xp - xpForLevel(data.level)
		data.level = data.level + 1
		leveledUp = true

		local VehicleRegistry = require(DMReplicatedStorage:WaitForChild("VehicleRegistry"))
		for _, vDef in VehicleRegistry.getAll() do
			if vDef.unlockLevel <= data.level then
				if not table.find(data.unlockedVehicles, vDef.id) then
					table.insert(data.unlockedVehicles, vDef.id)
				end
			end
		end
	end

	return {
		leveledUp = leveledUp,
		newLevel = data.level,
		xpGained = amount,
	}
end

function ProfileManager.IsVehicleUnlocked(player: Player, vehicleId: string): boolean
	local profile = Profiles[player]
	if not profile then return false end
	local unlocked = profile.Data.unlockedVehicles
	if not unlocked then return vehicleId == "all_rounder" end
	return table.find(unlocked, vehicleId) ~= nil
end

function ProfileManager.GetUnlockedVehicles(player: Player): { string }
	local profile = Profiles[player]
	if not profile then return { "all_rounder" } end
	return profile.Data.unlockedVehicles or { "all_rounder" }
end

function ProfileManager.GetSelectedVehicle(player: Player): string
	return ProfileManager.GetValue(player, "selectedVehicle") or "all_rounder"
end

function ProfileManager.SetSelectedVehicle(player: Player, vehicleId: string)
	if ProfileManager.IsVehicleUnlocked(player, vehicleId) then
		ProfileManager.SetValue(player, "selectedVehicle", vehicleId)
	end
end

function ProfileManager.RecordRace(player: Player, placement: number, finished: boolean)
	local profile = Profiles[player]
	if not profile then return end
	local data = profile.Data
	data.racesPlayed = (data.racesPlayed or 0) + 1
	if finished then
		data.racesFinished = (data.racesFinished or 0) + 1
	end
end

function ProfileManager.XpForLevel(level: number): number
	return xpForLevel(level)
end

----- Player lifecycle -----

local function onPlayerAdded(player: Player)
	local profileKey = "Player_" .. player.UserId
	local profile = ProfileStore:LoadProfileAsync(profileKey)

	if profile == nil then
		player:Kick("Failed to load save data. Please rejoin.")
		return
	end

	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	-- Ensure all_rounder is always unlocked
	if not profile.Data.unlockedVehicles or #profile.Data.unlockedVehicles == 0 then
		profile.Data.unlockedVehicles = { "all_rounder" }
	elseif not table.find(profile.Data.unlockedVehicles, "all_rounder") then
		table.insert(profile.Data.unlockedVehicles, 1, "all_rounder")
	end

	if not profile.Data.selectedVehicle then
		profile.Data.selectedVehicle = "all_rounder"
	end

	profile:ListenToRelease(function()
		Profiles[player] = nil
		player:Kick("Your profile was loaded on another server. Please rejoin.")
	end)

	Profiles[player] = profile

	ProfileLoaded:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile then
		profile:Release()
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

_G.ProfileManager = ProfileManager

-- RemoteFunction for clients to query their own progression
local getProgressionRemote = Instance.new("RemoteFunction")
getProgressionRemote.Name = "GetProgression"
getProgressionRemote.Parent = ReplicatedStorage

getProgressionRemote.OnServerInvoke = function(player: Player)
	local xp, xpNeeded = ProfileManager.GetXP(player)
	local level = ProfileManager.GetLevel(player)
	return {
		level = level,
		xp = xp,
		xpNeeded = xpNeeded,
	}
end

-- RemoteFunction for clients to get/set input settings
local getInputSettingsRemote = Instance.new("RemoteFunction")
getInputSettingsRemote.Name = "GetInputSettings"
getInputSettingsRemote.Parent = ReplicatedStorage

getInputSettingsRemote.OnServerInvoke = function(player: Player)
	local profile = Profiles[player]
	if not profile then return {} end
	return profile.Data.settings or {}
end

local setInputSettingsRemote = Instance.new("RemoteFunction")
setInputSettingsRemote.Name = "SetInputSettings"
setInputSettingsRemote.Parent = ReplicatedStorage

local VALID_SETTINGS = {
	steerMode = "string",
	steerSensitivity = "number",
	buttonOpacity = "number",
	buttonScale = "number",
	autoGas = "boolean",
	tiltDeadzone = "number",
}

setInputSettingsRemote.OnServerInvoke = function(player: Player, newSettings: { [string]: any })
	local profile = Profiles[player]
	if not profile then return false end

	if type(newSettings) ~= "table" then return false end

	local settings = profile.Data.settings or {}
	for key, expectedType in VALID_SETTINGS do
		if newSettings[key] ~= nil and type(newSettings[key]) == expectedType then
			settings[key] = newSettings[key]
		end
	end
	profile.Data.settings = settings
	return true
end
