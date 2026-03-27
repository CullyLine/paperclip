--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
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

function GamePassService.hasPass(player: Player, passKey: string): boolean
	if passKey == "vip" then
		local o = vipAdminOverride[player.UserId]
		if o ~= nil then
			return o
		end
	end
	local passes = playerPasses[player.UserId]
	return passes ~= nil and passes[passKey] == true
end

function GamePassService.getPassFlagsTable(player: Player): { [string]: boolean }
	local t: { [string]: boolean } = {}
	for passKey in GamePassConfig.Passes do
		t[passKey] = GamePassService.hasPass(player, passKey)
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

	for passKey, passDef in GamePassConfig.Passes do
		if passDef.gamePassId > 0 then
			local success, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passDef.gamePassId)
			end)
			if success and owns then
				playerPasses[player.UserId][passKey] = true
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

	for passKey, passDef in GamePassConfig.Passes do
		if passDef.gamePassId == gamePassId then
			if not playerPasses[player.UserId] then
				playerPasses[player.UserId] = {}
			end
			-- Idempotent: duplicate PromptGamePassPurchaseFinished must not re-notify / re-save / re-fire PurchaseComplete.
			if playerPasses[player.UserId][passKey] == true then
				return
			end
			playerPasses[player.UserId][passKey] = true

			-- Apply immediate effects
			if passKey == "extra_pet_slots" then
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

			NotificationDispatchService.notify(player, {
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
				if DataManager.saveImmediate(player) then
					Remotes.getEvent("PurchaseComplete"):FireClient(player, {
						productType = "gamepass",
						productKey = passKey,
						displayName = tostring(passDef.name),
						iconId = iconId,
						benefits = benefits,
						robuxSpent = robuxSpent,
						totalRobuxSpent = if type(pdataMoney.totalRobuxSpent) == "number" then pdataMoney.totalRobuxSpent else 0,
					})
				end
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

	Remotes.getEvent("PurchaseGamePass").OnServerEvent:Connect(function(player, passKey)
		if not ValidationService.checkRemoteRate(player, "PurchaseGamePass") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if type(passKey) ~= "string" then
			ValidationService.logAnomalyOncePerSession(player, "gamepass_bad_id_type", "")
			return
		end
		if passKey == "" or #passKey > ValidationService.MAX_REMOTE_STRING_ID_LEN then
			ValidationService.logAnomalyOncePerSession(player, "gamepass_bad_id_len", "")
			return
		end
		-- Shared with DevProductService: one throttle for all Robux prompt requests (POLA-655).
		if not RemoteCooldown.allow(player, "IapMarketplacePrompt", 2) then
			local msg = MicrocopyConfig.pickVariant(MicrocopyConfig.SoftFailCooldownActive):gsub("{ACTION}", "Robux checkout")
			NotificationDispatchService.notify(player, {
				type = "info",
				message = msg,
			})
			return
		end
		local passDef = GamePassConfig.Passes[passKey]
		if not passDef then
			ValidationService.logAnomalyOncePerSession(player, "gamepass_unknown_id", passKey)
			return
		end
		if passDef.gamePassId == 0 then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = "That pass isn’t hooked up in this build yet — check back after the next update!",
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
