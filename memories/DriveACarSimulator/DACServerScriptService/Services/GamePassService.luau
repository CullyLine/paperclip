--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local Constants = require(DAC:WaitForChild("Constants"))
local GamePassConfig = require(DAC:WaitForChild("Config"):WaitForChild("GamePassConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local GamePassService = {}

local playerPasses: { [number]: { [string]: boolean } } = {}

-- nil = use real ownership; true/false = admin testing override (VIP only)
local vipAdminOverride: { [number]: boolean? } = {}

function GamePassService.hasPass(player: Player, passId: string): boolean
	if passId == "vip" then
		local o = vipAdminOverride[player.UserId]
		if o ~= nil then
			return o
		end
	end
	local passes = playerPasses[player.UserId]
	return passes ~= nil and passes[passId] == true
end

function GamePassService.getPassFlagsTable(player: Player): { [string]: boolean }
	local t: { [string]: boolean } = {}
	for passId in GamePassConfig.Passes do
		t[passId] = GamePassService.hasPass(player, passId)
	end
	return t
end

local function syncVipAttribute(player: Player)
	player:SetAttribute("DAC_VipPass", GamePassService.hasPass(player, "vip"))
end

--[[
	Cycle VIP override for admin testing: nil → forced on → forced off → nil (live ownership).
	Returns a short status string for chat feedback.
]]
function GamePassService.adminCycleVipTesting(player: Player): string
	local uid = player.UserId
	local o = vipAdminOverride[uid]
	if o == nil then
		vipAdminOverride[uid] = true
	elseif o == true then
		vipAdminOverride[uid] = false
	else
		vipAdminOverride[uid] = nil
	end
	syncVipAttribute(player)
	local n = vipAdminOverride[uid]
	if n == nil then
		return "VIP: live ownership (Marketplace)"
	elseif n == true then
		return "VIP: testing ON"
	else
		return "VIP: testing OFF"
	end
end

function GamePassService.checkAllPasses(player: Player)
	playerPasses[player.UserId] = {}

	for passId, passDef in GamePassConfig.Passes do
		if passDef.gamePassId > 0 then
			local success, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passDef.gamePassId)
			end)
			if success and owns then
				playerPasses[player.UserId][passId] = true
			end
		end
	end

	syncVipAttribute(player)

	-- Apply extra pet slots if owned
	if GamePassService.hasPass(player, "extra_pet_slots") then
		local data = DataManager.get(player)
		if data then
			data.maxPetSlots = Constants.MAX_PET_SLOTS_GAMEPASS
		end
	end
end

function GamePassService.onGamePassPurchased(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then return end

	for passId, passDef in GamePassConfig.Passes do
		if passDef.gamePassId == gamePassId then
			if not playerPasses[player.UserId] then
				playerPasses[player.UserId] = {}
			end
			playerPasses[player.UserId][passId] = true

			-- Apply immediate effects
			if passId == "extra_pet_slots" then
				local data = DataManager.get(player)
				if data then
					data.maxPetSlots = Constants.MAX_PET_SLOTS_GAMEPASS
					Remotes.getEvent("DataUpdate"):FireClient(player, data)
				end
			end

			syncVipAttribute(player)

			local pdata = DataManager.get(player)
			if pdata then
				MilestoneCeremonyService.tryFirstTime(player, pdata, "FirstGamePassPurchase")
			end

			Remotes.getEvent("Notification"):FireClient(player, {
				type = "success",
				message = `Purchased {passDef.name}!`,
			})

			local pdataMoney = DataManager.get(player)
			if pdataMoney then
				local robuxSpent = math.max(0, math.floor(tonumber(passDef.robuxPrice) or 0))
				local deferred = MilestoneCeremonyService.recordRobuxSpend(player, pdataMoney, robuxSpent, true)
				MilestoneCeremonyService.queueDeferredSpendMilestones(player, deferred)
				local iconId = if type(passDef.iconId) == "string" and passDef.iconId ~= "" then passDef.iconId else "rbxassetid://0"
				local benefits: { string } = {}
				if type(passDef.description) == "string" and passDef.description ~= "" then
					table.insert(benefits, passDef.description)
				else
					table.insert(benefits, "Permanent unlock")
				end
				Remotes.getEvent("PurchaseComplete"):FireClient(player, {
					productType = "gamepass",
					productKey = passId,
					displayName = tostring(passDef.name),
					iconId = iconId,
					benefits = benefits,
					robuxSpent = robuxSpent,
					totalRobuxSpent = if type(pdataMoney.totalRobuxSpent) == "number" then pdataMoney.totalRobuxSpent else 0,
				})
				DataManager.save(player)
			end
			break
		end
	end
end

function GamePassService.init()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(GamePassService.onGamePassPurchased)

	Remotes.getFunction("GetPassFlags").OnServerInvoke = function(player)
		if not ValidationService.checkRemoteRate(player, "GetPassFlags") then
			return {}
		end
		return GamePassService.getPassFlagsTable(player)
	end

	Remotes.getEvent("PurchaseGamePass").OnServerEvent:Connect(function(player, passId)
		if type(passId) ~= "string" then
			return
		end
		if not ValidationService.checkRemoteRate(player, "PurchaseGamePass") then
			return
		end
		if not RemoteCooldown.allow(player, "PurchaseGamePass", 2) then
			return
		end
		local passDef = GamePassConfig.Passes[passId]
		if not passDef then
			return
		end
		if passDef.gamePassId == 0 then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = "Game pass not linked in Studio yet (ID 0).",
			})
			return
		end
		Remotes.getEvent("ClientPromptGamePass"):FireClient(player, passDef.gamePassId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerPasses[player.UserId] = nil
	end)
end

return GamePassService
