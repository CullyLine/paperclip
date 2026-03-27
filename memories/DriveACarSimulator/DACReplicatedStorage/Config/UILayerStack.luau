--!strict
--[[
	POLA-344 / UIDisplayLayers — single source of truth for ScreenGui.DisplayOrder and
	shared GuiObject.ZIndex bands. Alias module: `Config/UIDisplayLayers.luau` (same table).

	## Global stack (bottom to top, DisplayOrder)
		hudBase(0) -> hudPlaytimeGem(26) -> hudEventBanner(27) -> hudChrome(28) -> hudPromoBanner(32)
		-> runResults(48) -> vfxCelebration(80) -> dailyCelebration(100)
		-> retentionModal(550) -> tutorialOverlay(700) -> purchaseThankYou(999)
		-> adminPanel(2000) -> loadingScreen(100000)

	World travel fade / charge FX: full-screen frames live on the VFX ScreenGui (vfxCelebration).

	## ScreenGui.DisplayOrder (global stacking; higher renders on top)
	Keep gaps between bands so Studio one-offs can slot between without renumbering.
	Rojo `default.project.json` (DACFriendBonusHUD / DACGroupJoinBanner) must match hudChrome / hudPromoBanner.

	| Band              | Value | ScreenGui / usage |
	|-------------------|------|-------------------|
	| hudBase           | 0    | DACMain — driving HUD, menus, in-gui toasts |
	| hudPlaytimeGem    | 26   | DACPlaytimeGem |
	| hudEventBanner    | 27   | DACEventBanner |
	| hudChrome         | 28   | DACFriendBonusHUD |
	| hudPromoBanner    | 32   | DACGroupJoinBanner |
	| runResults        | 48   | DACPayout |
	| vfxCelebration    | 80   | VFXController celebration + world-transition flash parent |
	| dailyCelebration  | 100  | DailyRewardPanel runtime overlay |
	| retentionModal    | 550  | RetentionController modal |
	| tutorialOverlay   | 700  | DACTutorialOverlay (blocking tutorial / highlight) |
	| purchaseThankYou  | 999  | PurchaseThankYouController |
	| adminPanel        | 2000 | AdminPanel (dev) |
	| loadingScreen     | 100000 | ReplicatedFirst loading |

	## ZIndex (within one ScreenGui; use with ZIndexBehavior.Sibling)
	| Band / role        | Typical use |
	|--------------------|-------------|
	| panelBackdrop      | Full-screen dim behind main panels |
	| panelStack         | Inventory, store, settings shells |
	| panelInsetClick    | In-card click targets (inventory slots) |
	| hudNotificationToast | Streak / generic toasts (UIController) |
	| popupStack         | Egg buy / confirm above panels |
	| achievement*       | Achievement progress + unlock toasts |
	| payout*            | Run payout anticipation + flash (DACPayout) |
	| worldFeedServerDrop| World/server drop feed frame (VFX HUD) |
]]

local UILayerStack = {}

UILayerStack.screenGui = {
	hudBase = 0,
	hudPlaytimeGem = 26,
	hudEventBanner = 27,
	hudChrome = 28,
	hudPromoBanner = 32,
	runResults = 48,
	vfxCelebration = 80,
	dailyCelebration = 100,
	retentionModal = 550,
	tutorialOverlay = 700,
	purchaseThankYou = 999,
	adminPanel = 2000,
	loadingScreen = 100_000,
}

UILayerStack.z = {
	panelBackdrop = 1,
	panelStack = 10,
	panelInsetClick = 50,
	eggSlotClickOverlay = 100,
	hudNotificationToast = 500,
	hudNotificationToastShimmer = 501,
	hudNotificationToastAccent = 502,
	popupStack = 1000,
	popupChild = 1001,
	popupDeep = 1002,
	achievementProgressLayer = 880,
	achievementProgressCard = 880,
	achievementProgressInner = 881,
	achievementProgressFill = 882,
	achievementUnlockLayer = 900,
	achievementUnlockCard = 900,
	achievementUnlockInner = 901,
	achievementConfetti = 910,
	achievementFlash = 920,
	payoutAnticipationGlow = 1998,
	payoutAnticipationDim = 1999,
	payoutFlash = 2000,
	payoutTierFlash = 12,
	payoutCoinRain = 5,
	worldFeedServerDrop = 55,
}

UILayerStack.zPurchaseThankYou = {
	backdrop = 950,
	vignette = 951,
	card = 960,
	headline = 965,
	subline = 965,
	glow = 973,
	spot = 975,
	icon = 976,
	iconBurst = 976,
	iconBurstLabel = 977,
	itemName = 965,
	benefitsHolder = 965,
	benefitRow = 965,
	divider = 965,
	enjoy = 965,
	dot = 970,
}

return UILayerStack
