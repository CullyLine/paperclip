--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local DevProductConfig = require(DAC:WaitForChild("Config"):WaitForChild("DevProductConfig"))

local DataManager = require(script.Parent.Parent:WaitForChild("DataManager"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))
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
		return { "+25,000 coins", "+500 gems", "+3 Meadow Eggs" }
	end
	if reward.type == "battle_pass_premium" then
		return { "Premium battle pass track unlocked" }
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

	Remotes.getEvent("PurchaseComplete"):FireClient(player, payload)
end

local function findProductById(productId: number): (string?, any?)
	for id, product in DevProductConfig.Products do
		if product.productId == productId then
			return id, product
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
	if data.processedReceiptIds[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId, productDef = findProductById(receiptInfo.ProductId)
	if not productId or not productDef then
		warn(`[DevProductService] Unknown product ID: {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local reward = productDef.reward

	if reward.type == "starter_pack" then
		if data.starterPackPurchased then
			data.processedReceiptIds[receiptKey] = true
			DataManager.save(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		data.starterPackPurchased = true
		CurrencyService.add(player, "coins", 25_000, "dev_product")
		CurrencyService.add(player, "gems", 500, "dev_product")
		data.eggs["basic_egg"] = (data.eggs["basic_egg"] or 0) + 3
		data.processedReceiptIds[receiptKey] = true
		DataManager.save(player)
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
		Remotes.getEvent("Notification"):FireClient(player, {
			type = "success",
			message = "Starter Pack claimed! +25K coins, +500 gems, +3 Meadow Eggs",
		})
		finalizePurchase(player, data, receiptInfo, productId, productDef, reward)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if reward.type == "battle_pass_premium" then
		local BattlePassService = require(script.Parent:WaitForChild("BattlePassService"))
		BattlePassService.ensureSeason(player)
		if not data.battlePass then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if data.battlePass.premium then
			data.processedReceiptIds[receiptKey] = true
			DataManager.save(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		data.battlePass.premium = true
		data.processedReceiptIds[receiptKey] = true
		DataManager.save(player)
		Remotes.getEvent("DataUpdate"):FireClient(player, data)
		Remotes.getEvent("Notification"):FireClient(player, {
			type = "success",
			message = "Premium battle pass unlocked!",
		})
		finalizePurchase(player, data, receiptInfo, productId, productDef, reward)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if reward.currency then
		CurrencyService.add(player, reward.currency, reward.amount, "dev_product")
		Remotes.getEvent("Notification"):FireClient(player, {
			type = "success",
			message = `+{reward.amount} {reward.currency}!`,
		})
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

	data.processedReceiptIds[receiptKey] = true
	finalizePurchase(player, data, receiptInfo, productId, productDef, reward)
	DataManager.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function DevProductService.init()
	MarketplaceService.ProcessReceipt = DevProductService.processReceipt

	Remotes.getEvent("PurchaseThankYouAck").OnServerEvent:Connect(function(player: Player)
		MilestoneCeremonyService.flushNextSpendMilestoneBatch(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		MilestoneCeremonyService.clearPendingSpendMilestones(player)
	end)

	Remotes.getEvent("PurchaseDevProduct").OnServerEvent:Connect(function(player, productKey)
		if type(productKey) ~= "string" then
			return
		end
		if not ValidationService.checkRemoteRate(player, "PurchaseDevProduct") then
			return
		end
		if not RemoteCooldown.allow(player, "PurchaseDevProduct", 2) then
			return
		end
		local def = DevProductConfig.Products[productKey]
		if not def then
			return
		end
		if def.productId == 0 then
			Remotes.getEvent("Notification"):FireClient(player, {
				type = "error",
				message = "Developer product not linked in Studio yet (ID 0).",
			})
			return
		end
		if def.id == "starter_pack" then
			local pdata = DataManager.get(player)
			if pdata and pdata.starterPackPurchased then
				Remotes.getEvent("Notification"):FireClient(player, {
					type = "error",
					message = "Starter Pack already purchased.",
				})
				return
			end
		end
		if def.id == "battle_pass_premium" then
			local pdata = DataManager.get(player)
			if pdata and pdata.battlePass and pdata.battlePass.premium then
				Remotes.getEvent("Notification"):FireClient(player, {
					type = "error",
					message = "You already have Premium for this season.",
				})
				return
			end
		end
		Remotes.getEvent("ClientPromptDevProduct"):FireClient(player, def.productId)
	end)
end

return DevProductService
