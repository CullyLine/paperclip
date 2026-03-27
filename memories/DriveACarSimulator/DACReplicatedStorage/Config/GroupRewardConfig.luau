--!strict
--[[
	Roblox group rewards: join bonus, run coin bonus, UI URLs.
	Set groupId to your game's official Roblox group (numeric id). Use 0 to disable.
]]

local GroupRewardConfig = {}

-- Replace with your game's group id from https://www.roblox.com/groups/123456789/...
GroupRewardConfig.groupId = 0

-- Shown on join prompt button; must match groupId's public page
GroupRewardConfig.groupPageUrl = "https://www.roblox.com/search/groups"

GroupRewardConfig.joinRewardCoins = 10000

-- Extra multiplier on run coin payout for group members (5% => 0.05)
GroupRewardConfig.coinBonusMultiplier = 0.05

-- Show "join group" banner after this many completed runs (if not in group)
GroupRewardConfig.runsBeforePrompt = 3

-- Copy must match GroupRewardService: ongoing +5% run coins; one-time coins + gems + Group Pup pet (no cooldown — one claim per account).
GroupRewardConfig.bannerHeadline = "Join our group: +5% run bonus + a one-time welcome bundle!"
GroupRewardConfig.bannerSub = "Tap Join, join on Roblox, then rejoin this game once — we drop 10K coins & a bonus pet (one time per account)."

-- Server: TTL for caching Player:IsInGroup in GroupRewardService (default 120s if unset/invalid).
GroupRewardConfig.membershipCacheTtlSeconds = 120

return GroupRewardConfig
