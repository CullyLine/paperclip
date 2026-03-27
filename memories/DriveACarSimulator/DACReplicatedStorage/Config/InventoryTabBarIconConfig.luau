--!strict
--[[
	POLA-619: Inventory TabBar silhouette icons (dark tint on white pill — see AGENTS.md).
	Centralizes rbxasset IDs so shop/reward surfaces stay visually consistent; Board may
	replace any ID after uploading a matched set to ReplicatedStorage.Images and wiring
	Constants.CURRENCY_DISPLAY (see LaunchAssets/AssetIdChecklist.md §4).
]]

local InventoryTabBarIconConfig = {}

-- Egg shop (dedicated egg silhouette)
InventoryTabBarIconConfig.eggShop = "rbxassetid://15460672893"
-- Quest scroll / checklist
InventoryTabBarIconConfig.quests = "rbxassetid://15473783825"
-- Battle Pass badge
InventoryTabBarIconConfig.battlePass = "rbxassetid://15475011812"
-- Promo codes (legacy numeric range — consider re-exporting to match 1547… family)
InventoryTabBarIconConfig.codes = "rbxassetid://4871215849"
--[[
	Stats sub-panel: MUST NOT duplicate quests icon (was 15473783825 before POLA-619).
	Widely used Roblox UI “leaderboard / chart” silhouette; verify in Studio and swap
	if your Creator permissions differ.
]]
InventoryTabBarIconConfig.stats = "rbxassetid://7733968421"

return InventoryTabBarIconConfig
