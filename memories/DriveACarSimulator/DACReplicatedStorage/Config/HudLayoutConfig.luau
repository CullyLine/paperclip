--!strict
--[[
	Central offsets for Phase 4 responsive HUD (safe-area, touch targets, narrow widths).
	DisplayOrder / ZIndex bands: see UILayerStack.luau (alias UIDisplayLayers.luau).

	POLA-347 (mobile safe area):
	- GuiInset values come from GuiService:GetGuiInset() via HudSafeArea.getRawInsets().
	- When a ScreenGui has IgnoreGuiInset = false, Roblox applies safe rect automatically;
	  scripts use getManualInsetsForScreenGui (zeros) so we do not double-pad.
	- When IgnoreGuiInset = true, add GuiInset LTRB + edgeMarginPx + optional extras below.
	Default bottom/right padding for notched phones follows engine insets (often ~34px bottom).
]]

local UILayerStack = require(script.Parent:WaitForChild("UILayerStack"))

local HudLayoutConfig = {}

-- ~44pt Apple HIG minimum; Roblox uses pixel offsets in this project.
HudLayoutConfig.minTouchPx = 44

HudLayoutConfig.edgeMarginPx = 8

-- Added on top of top GuiInset inside DACMain.PlayerInfo (IgnoreGuiInset hosts only).
HudLayoutConfig.hudPlayerInfoExtraTopPx = 0

-- Added on top of bottom GuiInset inside DACMain.ActionBar (home indicator clearance).
HudLayoutConfig.hudActionBarExtraBottomPx = 0

-- Right-edge HUD notification toasts: Y of first row = topInset + this (see UIController).
HudLayoutConfig.hudNotificationToastStackBasePx = 10

-- Extra offset from the right edge (in addition to top-right inset) for toast strip.
HudLayoutConfig.hudNotificationToastRightClearancePx = 10

-- Viewport width at or below this uses compact toast / chip widths.
HudLayoutConfig.compactViewportWidth = 520

-- Smallest phones (e.g. ~360 logical px): hub panel Main frames scale down to fit.
HudLayoutConfig.narrowViewportWidthPx = 360
-- Design-time width used when scaling `Main` frames (Inventory, EggStore, popups, etc.).
HudLayoutConfig.hubPanelFitReferenceWidthPx = 400

HudLayoutConfig.friendBonusMaxWidthPx = 300
HudLayoutConfig.friendBonusMaxWidthCompactPx = 260

-- Vertical offset below top safe inset (when ScreenGui uses IgnoreGuiInset).
HudLayoutConfig.friendBonusBelowInsetPx = 6

HudLayoutConfig.serverDropBaseTopPx = 56
HudLayoutConfig.serverDropMaxWidthPx = 460
HudLayoutConfig.serverDropFrameZIndex = UILayerStack.z.worldFeedServerDrop

HudLayoutConfig.eventBannerTopPadPx = 8
HudLayoutConfig.eventBannerMaxWidthPx = 520

HudLayoutConfig.achievementToastWidthDefault = 360
HudLayoutConfig.achievementToastWidthDiamond = 400
HudLayoutConfig.achievementToastWidthNarrow = 300
HudLayoutConfig.achievementToastWidthNarrowDiamond = 340
HudLayoutConfig.achievementToastTopRestPx = 16

HudLayoutConfig.progressToastWidthDefault = 340
HudLayoutConfig.progressToastWidthNarrow = 300

return HudLayoutConfig
