local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DMReplicatedStorage = ReplicatedStorage:WaitForChild("DMReplicatedStorage")
local ProfileService = require(DMReplicatedStorage:WaitForChild("ProfileService"))

local PROFILE_TEMPLATE = {
	level = 1,
	xp = 0,
	statPoints = 0,
	stats = {
		speed = 0,
		acceleration = 0,
		handling = 0,
		durability = 0,
		recovery = 0,
	},
	vehicles = {},
	cosmetics = {},
	currency = 0,
	settings = {},
}

local BASE_VEHICLE_IDS = {
	"sedan_01", "sedan_02", "sedan_03", "sedan_04",
	"suv_01", "suv_02", "suv_03", "suv_04",
	"truck_01", "truck_02", "truck_03", "truck_04",
	"hatchback_01", "hatchback_02", "hatchback_03", "hatchback_04",
	"van_01", "van_02", "van_03", "van_04",
}

local STORE_NAME = "DownhillMadness_PlayerData"

local ProfileStore = ProfileService.GetProfileStore(STORE_NAME, PROFILE_TEMPLATE)

local Profiles: { [Player]: any } = {}

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

	-- Populate base vehicles on first join
	if #profile.Data.vehicles == 0 then
		for _, vehicleId in ipairs(BASE_VEHICLE_IDS) do
			table.insert(profile.Data.vehicles, vehicleId)
		end
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

-- Handle players already in game (Studio edge case)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Expose via shared module table for other server scripts
_G.ProfileManager = ProfileManager
