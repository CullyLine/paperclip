--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local SettingsService = {}

local function clamp01(n: number): number
	return math.clamp(n, 0, 1)
end

function SettingsService.apply(player: Player, patch: { [string]: any }): (boolean, string?)
	local data = DataManager.get(player)
	if not data then
		return false, "No data"
	end
	local s = data.settings
	if type(patch.autoCenter) == "boolean" then
		s.autoCenter = patch.autoCenter
	end
	if type(patch.otherPets) == "boolean" then
		s.otherPets = patch.otherPets
	end
	if type(patch.tradeRequests) == "boolean" then
		s.tradeRequests = patch.tradeRequests
	end
	if type(patch.particles) == "boolean" then
		s.particles = patch.particles
	end
	if type(patch.sound) == "boolean" then
		s.sound = patch.sound
	end
	if type(patch.musicVolume) == "number" then
		s.musicVolume = clamp01(patch.musicVolume)
	end
	if type(patch.sfxVolume) == "number" then
		s.sfxVolume = clamp01(patch.sfxVolume)
	end
	if type(patch.graphicsQuality) == "number" then
		s.graphicsQuality = math.clamp(math.floor(patch.graphicsQuality), 0, 2)
	end
	if type(patch.steeringSensitivity) == "number" then
		s.steeringSensitivity = math.clamp(patch.steeringSensitivity, 0.5, 2)
	end

	Remotes.getEvent("DataUpdate"):FireClient(player, data)
	return true, nil
end

function SettingsService.init()
	Remotes.getEvent("UpdateSettings").OnServerEvent:Connect(function(player, patch)
		if type(patch) ~= "table" then
			return
		end
		if not ValidationService.checkRemoteRate(player, "UpdateSettings") then
			return
		end
		if not RemoteCooldown.allow(player, "UpdateSettings", Constants.REMOTE_COOLDOWN_DEFAULT) then
			return
		end
		local ok, err = SettingsService.apply(player, patch)
		if not ok then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = err or "Settings failed",
			})
		end
	end)
end

return SettingsService
