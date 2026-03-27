--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local MicrocopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MicrocopyConfig"))
local Utils = require(DAC:WaitForChild("Utils"))
local Remotes = require(DAC:WaitForChild("Remotes"))
local NotificationDispatchService = require(script.Parent:WaitForChild("NotificationDispatchService"))
local DevProductConfig = require(DAC:WaitForChild("Config"):WaitForChild("DevProductConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
local EconomyLogService = require(script.Parent:WaitForChild("EconomyLogService"))
local MilestoneCeremonyService = require(script.Parent:WaitForChild("MilestoneCeremonyService"))
local RemoteCooldown = require(script.Parent:WaitForChild("RemoteCooldown"))
local ValidationService = require(script.Parent:WaitForChild("ValidationService"))

local DevProductService = {}

local function robuxFromReceipt(productDef: any, receiptInfo: any): number
	local spent = tonumber(receiptInfo.CurrencySpent) or 0
	if spent > 0 then
		return spent
	end
	return math.max(0, math.floor(tonumber(productDef.robuxPrice) or 0))
end

local function benefitLinesForReward(productDef: any, reward: any): { string }
	if reward.type == "starter_pack" then
		return { "+50,000 coins", "+3 Meadow Eggs" }
	end
	if reward.type == "battle_pass_premium" then
		return { "Premium track unlocked — claim the bonus column each tier" }
	end
	if reward.currency then
		return { `+{reward.amount} {reward.currency}` }
	end
	if reward.type == "instant_rebirth" then
		return { "Instant rebirth completed" }
	end
	if reward.type == "auto_hatch" then
		return { `Auto-hatched up to {reward.count} eggs` }
	end
	if reward.type == "skip_world" then
		return { "Next world unlocked" }
	end
	if type(productDef.description) == "string" and productDef.description ~= "" then
		return { productDef.description }
	end
	return { "Thank you for your purchase!" }
end

local function finalizePurchase(
	player: Player,
	data: any,
	receiptInfo: any,
	productKey: string,
	productDef: any,
	reward: any
)
	local robuxSpent = robuxFromReceipt(productDef, receiptInfo)
	local deferred = MilestoneCeremonyService.recordRobuxSpend(player, data, robuxSpent, true)
	MilestoneCeremonyService.queueDeferredSpendMilestones(player, deferred)

	local benefits = benefitLinesForReward(productDef, reward)
	local iconId = if type(productDef.iconId) == "string" and productDef.iconId ~= "" then productDef.iconId else "rbxassetid://0"

	local payload: any = {
		productType = "devproduct",
		productKey = productKey,
		displayName = tostring(productDef.name or "Purchase"),
		iconId = iconId,
		benefits = benefits,
		robuxSpent = robuxSpent,
		totalRobuxSpent = if type(data.totalRobuxSpent) == "number" then data.totalRobuxSpent else 0,
	}

	if reward.currency then
		payload.currencyGrant = {
			currency = reward.currency,
			amount = tonumber(reward.amount) or 0,
		}
	end

	local pid = tonumber(receiptInfo.ProductId) or 0
	EconomyLogService.logDevProductPurchase(player, productKey, pid, robuxSpent)

	Remotes.getEvent("PurchaseComplete"):FireClient(player, payload)
end

local function findProductById(productId: number): (string?, any?)
	for productKey, product in DevProductConfig.Products do
		if product.productId == productId then
			return productKey, product
		end
	end
	return nil, nil
end

function DevProductService.processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataManager.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = if type(receiptInfo.Id) == "string"
		then receiptInfo.Id
		elseif receiptInfo.PurchaseId ~= nil
		then tostring(receiptInfo.PurchaseId)
		else `{receiptInfo.PlayerId}_{receiptInfo.ProductId}_{receiptInfo.CurrencySpent or 0}`

	if not data.processedReceiptIds then
		data.processedReceiptIds = {}
	end
	-- Idempotency: same receipt id replays return Granted without re-granting (duplicate ProcessReceipt / retries).
	if data.processedReceiptIds[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productKey, productDef = findProductById(receiptInfo.ProductId)
	if not productKey or not productDef then
		warn(`[DevProductService] Unknown product ID: {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local reward = productDef.reward

	local function syncAfterProfileRevert()
		local d = DataManager.get(player)
		if d then
			Remotes.getEvent("DataUpdate"):FireClient(player, d)
		end
	end

	-- Mark receipt processed + persist; on failure revert to snapshot so ProcessReceipt can retry safely.
	local function saveReceiptGrantOrRevert(snap: any): boolean
		data.processedReceiptIds[receiptKey] = true
		if not DataManager.saveImmediate(player) then
			DataManager.revertProfile(player, snap)
			syncAfterProfileRevert()
			warn(`[DevProductService] DataStore save failed for receipt {receiptKey}; reverted and will retry`)
			return false
		end
		return true
	end

	if reward.type == "starter_pack" then
		local snap = Utils.deepCopy(data)
		if data.starterPackPurchased then
			if not saveReceiptGrantOrRevert(snap) then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		data.starterPackPurchased = true
		CurrencyService.add(player, "coins", 50_000, "dev_product")
		data.eggs["basic_egg"] = (data.eggs["basic_egg"] or 0) + 3
		if not saveReceiptGrantOrRevert(snap) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
		NotificationDispatchService.notify(player, {
			type = "success",
			message = "Starter Pack claimed! +50K coins, +3 Meadow Eggs",
		})
		finalizePurchase(player, data, receiptInfo, productKey, productDef, reward)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if reward.type == "battle_pass_premium" then
		-- v1.0: BattlePass disabled — refund by not granting
		warn("[DevProductService] battle_pass_premium purchase attempted but BattlePass is disabled in v1.0")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local snap = Utils.deepCopy(data)
	-- Apply rewards before persisting; success toasts only after durable save.
	if reward.currency then
		CurrencyService.add(player, reward.currency, reward.amount, "dev_product")
	elseif reward.type == "instant_rebirth" then
		local RebirthService = require(script.Parent:WaitForChild("RebirthService"))
		RebirthService.rebirth(player, true)
	elseif reward.type == "auto_hatch" then
		local EggService = require(script.Parent:WaitForChild("EggService"))
		local bestEgg, bestCount = nil, 0
		for eggId, count in data.eggs do
			if count > bestCount then
				bestEgg = eggId
				bestCount = count
			end
		end
		if bestEgg then
			for _ = 1, math.min(reward.count, bestCount) do
				EggService.hatchEgg(player, bestEgg)
			end
		end
	elseif reward.type == "skip_world" then
		local WorldService = require(script.Parent:WaitForChild("WorldService"))
		WorldService.skipWorldUnlock(player)
	end

	if not saveReceiptGrantOrRevert(snap) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if reward.currency then
		NotificationDispatchService.notify(player, {
			type = "success",
			message = `+{reward.amount} {reward.currency}!`,
		})
	end
	finalizePurchase(player, data, receiptInfo, productKey, productDef, reward)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function DevProductService.init()
	MarketplaceService.ProcessReceipt = DevProductService.processReceipt

	Remotes.getEvent("PurchaseThankYouAck").OnServerEvent:Connect(function(player: Player)
		if not ValidationService.checkRemoteRate(player, "PurchaseThankYouAck") then
			return
		end
		MilestoneCeremonyService.flushNextSpendMilestoneBatch(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		MilestoneCeremonyService.clearPendingSpendMilestones(player)
	end)

	Remotes.getEvent("PurchaseDevProduct").OnServerEvent:Connect(function(player, productKey)
		if not ValidationService.checkRemoteRate(player, "PurchaseDevProduct") then
			return
		end
		if not ValidationService.canAct(player) then
			return
		end
		if type(productKey) ~= "string" then
			ValidationService.logAnomalyOncePerSession(player, "devproduct_bad_key_type", "")
			return
		end
		if productKey == "" or #productKey > ValidationService.MAX_REMOTE_STRING_ID_LEN then
			ValidationService.logAnomalyOncePerSession(player, "devproduct_bad_key_len", "")
			return
		end
		if not RemoteCooldown.allow(player, "IapMarketplacePrompt", 2) then
			local msg = MicrocopyConfig.pickVariant(MicrocopyConfig.SoftFailCooldownActive):gsub("{ACTION}", "Robux checkout")
			NotificationDispatchService.notify(player, {
				type = "info",
				message = msg,
			})
			return
		end
		local def = DevProductConfig.Products[productKey]
		if not def then
			ValidationService.logAnomalyOncePerSession(player, "devproduct_unknown_key", productKey)
			return
		end
		if def.productId == 0 then
			NotificationDispatchService.notify(player, {
				type = "error",
				message = "That offer isn’t hooked up in this build yet — check back after the next update!",
			})
			return
		end
		if def.id == "starter_pack" then
			local pdata = DataManager.get(player)
			if pdata and pdata.starterPackPurchased then
				NotificationDispatchService.notify(player, {
					type = "error",
					message = "Starter Pack already purchased.",
				})
				return
			end
		end
		if def.id == "battle_pass_premium" then
			local pdata = DataManager.get(player)
			if pdata and pdata.battlePass and pdata.battlePass.premium then
				NotificationDispatchService.notify(player, {
					type = "error",
					message = "You already have the Premium track for this season.",
				})
				return
			end
		end
		Remotes.getEvent("ClientPromptDevProduct"):FireClient(player, def.productId)
	end)
end

return DevProductService
