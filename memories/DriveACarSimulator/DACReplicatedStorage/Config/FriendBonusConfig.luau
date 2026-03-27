--!strict
--[[
	Friend play bonus: coins when Roblox friends are in the same server.

	Authoritative formula (server-only; FriendBonusService):
	  - Count = number of *other* players in this server who appear in your
	    Roblox friends-online list (GetFriendsOnline), then clamped to the
	    number of other players physically present (cannot exceed lobby size).
	  - Multiplier is exactly one of: 1.0, tierOneMultiplier, tierTwoMultiplier.
	  - Final multiplier is clamped to maxFriendBonusMultiplier (anti-exploit
	    cap even if config is mis-edited).

	Payout uses a fresh recompute each run end; HUD/cache updates on join/leave
	and on serverRefreshIntervalSec ticks.
]]

local FriendBonusConfig = {}

-- 1–2 friends in-server (among your online friends): +10%
FriendBonusConfig.tierOneMinFriends = 1
FriendBonusConfig.tierOneMultiplier = 1.1

-- 3+ friends in-server: +20%
FriendBonusConfig.tierTwoMinFriends = 3
FriendBonusConfig.tierTwoMultiplier = 1.2

-- Hard ceiling for the friend bonus factor (must be >= tierTwoMultiplier).
FriendBonusConfig.maxFriendBonusMultiplier = 1.2

-- Throttled full-lobby friend graph refresh (seconds). Mitigates HUD/cache drift;
-- run payouts still call GetFriendsOnline at end-of-run.
FriendBonusConfig.serverRefreshIntervalSec = 4

-- Throttle server-wide social feed lines per player (seconds)
FriendBonusConfig.socialFeedCooldownSec = 90

return FriendBonusConfig
