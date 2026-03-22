--!strict
--[[
	First-time ceremonies, cumulative Robux spend tiers, and streak milestones.
	Authoritative flags live in player data; clients only render payloads from remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAC = ReplicatedStorage:WaitForChild("DAC")
local Remotes = require(DAC:WaitForChild("Remotes"))
local FirstTimeConfig = require(DAC:WaitForChild("Config"):WaitForChild("FirstTimeConfig"))
local MilestoneCeremonyCopyConfig = require(DAC:WaitForChild("Config"):WaitForChild("MilestoneCeremonyCopyConfig"))
local PetConfig = require(DAC:WaitForChild("Config"):WaitForChild("PetConfig"))
local RebirthMilestoneConfig = require(DAC:WaitForChild("Config"):WaitForChild("RebirthMilestoneConfig"))
local WorldConfig = require(DAC:WaitForChild("Config"):WaitForChild("WorldConfig"))

local MilestoneCeremonyService = {}

-- FIFO batches of SpendMilestone payloads; flushed after PurchaseThankYouAck (per thank-you screen)
local pendingSpendMilestoneBatches: { [Player]: { { any } } } = {}

local CEREMONY_KEYS = {
	"FirstCarPurchased",
	"FirstPetHatched",
	"FirstRebirth",
	"FirstWorldUnlocked",
	"FirstQuestCompleted",
	"FirstGamePassPurchase",
	"FirstLeaderboardEntry",
}

local function ensureCeremonyTables(data: any)
	if type(data.firstTimeCeremony) ~= "table" then
		data.firstTimeCeremony = {}
	end
	local ft = data.firstTimeCeremony :: { [string]: boolean? }
	for _, k in CEREMONY_KEYS do
		if ft[k] == nil then
			ft[k] = false
		end
	end
	if type(data.totalRobuxSpent) ~= "number" then
		data.totalRobuxSpent = 0
	end
	if type(data.spendMilestonesClaimed) ~= "table" then
		data.spendMilestonesClaimed = {}
	end
	if type(data.streakMilestonesClaimed) ~= "table" then
		data.streakMilestonesClaimed = {}
	end
end

local function pickVariant(list: { string }): string
	if #list == 0 then
		return ""
	end
	return list[math.random(1, #list)]
end

local function interpolate(text: string, placeholders: { [string]: string }): string
	local out = text
	for k, v in placeholders do
		out = string.gsub(out, "{" .. k .. "}", v)
	end
	return out
end

local function ensureMilestoneCopyClaimed(data: any)
	if type(data.milestoneCopyClaimed) ~= "table" then
		data.milestoneCopyClaimed = {
			collection = {},
			worldMastery = {},
			totalRuns = {},
		}
	end
	local mc = data.milestoneCopyClaimed :: any
	if type(mc.collection) ~= "table" then
		mc.collection = {}
	end
	if type(mc.worldMastery) ~= "table" then
		mc.worldMastery = {}
	end
	if type(mc.totalRuns) ~= "table" then
		mc.totalRuns = {}
	end
end

local function indexPercent(filled: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.floor((100 * filled) / total)
end

local function fireCopyCeremony(player: Player, ceremonyKey: string, body: string)
	if body == "" then
		return
	end
	Remotes.getEvent("FirstTimeCeremony"):FireClient(player, {
		ceremonyKey = ceremonyKey,
		body = body,
	})
end

function MilestoneCeremonyService.fireRebirthTierCeremony(player: Player, rebirthCount: number, milestoneKey: string)
	local tierLabel = milestoneKey
	for _, row in RebirthMilestoneConfig.MILESTONES do
		if row.key == milestoneKey then
			tierLabel = row.label
			break
		end
	end
	local headline = MilestoneCeremonyCopyConfig.pickVariant(MilestoneCeremonyCopyConfig.RebirthCeremonyHeadlines)
	local rawBody = MilestoneCeremonyCopyConfig.pickVariant(MilestoneCeremonyCopyConfig.RebirthCeremonyBodies)
	local sub = interpolate(rawBody, {
		COUNT = tostring(rebirthCount),
		TIER = tierLabel,
	})
	fireCopyCeremony(player, "RebirthTierMilestone", headline .. "\n" .. sub)
end

function MilestoneCeremonyService.tryPetIndexMilestones(player: Player, data: any, prevDiscovered: number, newDiscovered: number)
	ensureMilestoneCopyClaimed(data)
	local total = PetConfig.getTotalSpeciesCount()
	if total <= 0 then
		return
	end
	local prevP = indexPercent(prevDiscovered, total)
	local newP = indexPercent(newDiscovered, total)
	local claimed = (data.milestoneCopyClaimed :: any).collection :: { [number]: boolean? }
	local thresholds = { 25, 50, 75, 100 }
	for _, th in thresholds do
		if prevP < th and newP >= th and not claimed[th] then
			claimed[th] = true
			local headline = MilestoneCeremonyCopyConfig.pickVariant(MilestoneCeremonyCopyConfig.CollectionCeremonyHeadlines)
			local rawBody = MilestoneCeremonyCopyConfig.pickVariant(MilestoneCeremonyCopyConfig.CollectionCeremonyBodies)
			local sub = interpolate(rawBody, { PERCENT = tostring(newP) })
			fireCopyCeremony(player, "CollectionMilestone", headline .. "\n" .. sub)
		end
	end
end

function MilestoneCeremonyService.tryWorldMasteryForUnlock(player: Player, data: any, worldId: string)
	local sorted = WorldConfig.getWorldsSorted()
	if #sorted == 0 then
		return
	end
	local last = sorted[#sorted]
	if last.id ~= worldId then
		return
	end
	ensureMilestoneCopyClaimed(data)
	local wm = (data.milestoneCopyClaimed :: any).worldMastery :: { [string]: boolean? }
	if wm[worldId] then
		return
	end
	wm[worldId] = true
	local world = WorldConfig.Worlds[worldId]
	local wname = if world and type(world.name) == "string" then world.name else worldId
	local headline = MilestoneCeremonyCopyConfig.pickVariant(MilestoneCeremonyCopyConfig.WorldMasteryCeremonyHeadlines)
	local rawBody = MilestoneCeremonyCopyConfig.pickVariant(MilestoneCeremonyCopyConfig.WorldMasteryCeremonyBodies)
	local sub = interpolate(rawBody, { WORLD = wname })
	fireCopyCeremony(player, "WorldMasteryMilestone", headline .. "\n" .. sub)
end

function MilestoneCeremonyService.tryTotalRunsMilestones(player: Player, data: any, prevRuns: number, newRuns: number)
	ensureMilestoneCopyClaimed(data)
	local claimed = (data.milestoneCopyClaimed :: any).totalRuns :: { [number]: boolean? }
	local thresholds = { 100, 500, 1000, 5000, 10000 }
	for _, th in thresholds do
		if prevRuns < th and newRuns >= th and not claimed[th] then
			claimed[th] = true
			local headline = MilestoneCeremonyCopyConfig.pickVariant(MilestoneCeremonyCopyConfig.TotalRunsCeremonyHeadlines)
			local rawBody = MilestoneCeremonyCopyConfig.pickVariant(MilestoneCeremonyCopyConfig.TotalRunsCeremonyBodies)
			local sub = interpolate(rawBody, { COUNT = tostring(newRuns) })
			local flex = MilestoneCeremonyCopyConfig.TotalRunsFlexText[th]
			local flexLine = if type(flex) == "string" and flex ~= "" then "\n" .. flex else ""
			fireCopyCeremony(player, "TotalRunsMilestone", headline .. "\n" .. sub .. flexLine)
		end
	end
end

function MilestoneCeremonyService.tryFirstTime(
	player: Player,
	data: any,
	key: string,
	placeholders: { [string]: string }?
)
	ensureCeremonyTables(data)
	local ft = data.firstTimeCeremony :: { [string]: boolean? }
	if ft[key] == true then
		return
	end
	local list = (FirstTimeConfig :: any)[key]
	if type(list) ~= "table" then
		return
	end
	local n = #list
	if n == 0 then
		return
	end
	local raw = pickVariant(list)
	local body = if placeholders then interpolate(raw, placeholders) else raw
	if body == "" then
		return
	end
	ft[key] = true
	Remotes.getEvent("FirstTimeCeremony"):FireClient(player, {
		ceremonyKey = key,
		body = body,
	})
end

local function sortedSpendThresholds(): { number }
	local t: { number } = {}
	for threshold, row in pairs(FirstTimeConfig.SpendingMilestones) do
		local n = tonumber(threshold)
		if type(n) == "number" and type(row) == "table" then
			table.insert(t, n)
		end
	end
	table.sort(t)
	return t
end

function MilestoneCeremonyService.queueDeferredSpendMilestones(player: Player, payloads: { any })
	if #payloads == 0 then
		return
	end
	local q = pendingSpendMilestoneBatches[player]
	if not q then
		q = {}
		pendingSpendMilestoneBatches[player] = q
	end
	table.insert(q, payloads)
end

function MilestoneCeremonyService.flushNextSpendMilestoneBatch(player: Player)
	local q = pendingSpendMilestoneBatches[player]
	if not q or #q == 0 then
		return
	end
	local batch = table.remove(q, 1)
	if #batch == 0 then
		MilestoneCeremonyService.flushNextSpendMilestoneBatch(player)
		return
	end
	task.delay(0.5, function()
		if not player.Parent then
			return
		end
		for _, payload in batch do
			Remotes.getEvent("SpendMilestone"):FireClient(player, payload)
		end
	end)
end

function MilestoneCeremonyService.clearPendingSpendMilestones(player: Player)
	pendingSpendMilestoneBatches[player] = nil
end

--[[
	Records lifetime Robux spend and optionally defers SpendMilestone remotes (queued until PurchaseThankYouAck).
	Returns payloads that were deferred (empty if none or if deferSpendMilestoneRemotes is false).
]]
function MilestoneCeremonyService.recordRobuxSpend(
	player: Player,
	data: any,
	robux: number,
	deferSpendMilestoneRemotes: boolean?
): { any }
	local deferred: { any } = {}
	if robux <= 0 then
		return deferred
	end
	ensureCeremonyTables(data)
	local prevTotal = if type(data.totalRobuxSpent) == "number" then data.totalRobuxSpent else 0
	data.totalRobuxSpent = prevTotal + robux
	local total = data.totalRobuxSpent
	local claimed = data.spendMilestonesClaimed :: { [number]: boolean? }

	for _, threshold in sortedSpendThresholds() do
		if prevTotal < threshold and total >= threshold and not claimed[threshold] then
			claimed[threshold] = true
			local row = (FirstTimeConfig.SpendingMilestones :: any)[threshold]
			if type(row) == "table" then
				local tierName = if type(row.tierName) == "string" then row.tierName else ("Tier " .. tostring(threshold))
				local titleList = row.title
				local subList = row.subtitle
				local descList = row.description
				local title = ""
				local subtitle = ""
				local description = ""
				if type(titleList) == "table" and #titleList > 0 then
					title = pickVariant(titleList)
				end
				if type(subList) == "table" and #subList > 0 then
					subtitle = pickVariant(subList)
				end
				if type(descList) == "table" and #descList > 0 then
					description = pickVariant(descList)
				end
				if title == "" and subtitle == "" and description == "" then
					title = "Thanks for your support!"
					subtitle = "Your support unlocks more fun."
					description = "Keep enjoying the ride!"
				end
				local payload = {
					threshold = threshold,
					tierName = tierName,
					title = title,
					subtitle = subtitle,
					description = description,
				}
				if deferSpendMilestoneRemotes == true then
					table.insert(deferred, payload)
				else
					Remotes.getEvent("SpendMilestone"):FireClient(player, payload)
				end
			end
		end
	end
	return deferred
end

function MilestoneCeremonyService.checkStreakMilestones(player: Player, data: any, streak: number)
	if streak <= 0 then
		return
	end
	ensureCeremonyTables(data)
	local claimed = data.streakMilestonesClaimed :: { [number]: boolean? }
	local cfg = FirstTimeConfig.StreakMilestones
	for threshold, variants in pairs(cfg) do
		local t = tonumber(threshold)
		if type(t) == "number" and streak == t and not claimed[t] then
			claimed[t] = true
			local text = ""
			if type(variants) == "table" and #variants > 0 then
				text = pickVariant(variants)
			else
				text = "Streak milestone!"
			end
			Remotes.getEvent("StreakMilestone"):FireClient(player, {
				streak = t,
				body = text,
			})
		end
	end
end

return MilestoneCeremonyService
