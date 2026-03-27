# IAP & Game Pass copy pack (Phase 4)

**Status:** Canonical reference for **Drive a Car Simulator** monetization copy.  
**IDs:** `gamePassId` / `productId` stay at **0** until Board issue **POLA-95** publishes live Marketplace IDs — copy-only changes do not require ID updates.

**Wiring:**

| Source of truth (player-visible product text) | `DACReplicatedStorage/Config/GamePassConfig.luau`, `DevProductConfig.luau` |
| Server notifications (success / error / duplicate) | `DACServerScriptService/Services/GamePassService.luau`, `DevProductService.luau` |
| Post-purchase celebration overlay | `DACStarterPlayerScripts/Controllers/PurchaseThankYouController.luau` |
| Soft-currency “can’t afford” / button fail feedback | `MicrocopyConfig.PurchaseFail` via `FailureFeedback` (`DACReplicatedStorage/FailureFeedback.luau`) |
| Store listing layout | `DACStarterGui/StorePanel.luau` (rows from configs; FOMO badges from `FomoBadgeLabelConfig`) |

**Related:** Purchase cancel / Roblox native prompt behavior is documented in `docs/PlayerFacingErrorCopy.md` (no fake cancel toast). Optional dismiss toast (**POLA-302**) is not implemented.

---

## 1. Game Pass catalog

Display pattern in Store: `{name} — {robuxPrice}R` plus description on second line; secondary line uses `SocialFeedConfig` **PremiumUpsell** pool.

| Config key | Display name | Robux | Player-facing description (config `description`) |
|------------|--------------|-------|---------------------------------------------------|
| `double_coins` | 2x Coins | 399 | Double every coin you earn. Permanent. Stack this first if you want the biggest account on the server. |
| `double_speed` | 2x Speed | 499 | Double base speed on every car. Same gas, double distance — more coins, more drops, faster prestige. |
| `auto_collect` | Auto-Collect | 299 | Bank distance earnings automatically. No stopping to cash out — pure momentum. |
| `vip` | VIP | 799 | VIP chat tag, exclusive car skin, name glow. Flex status without saying a word. |
| `extra_pet_slots` | Extra Pet Slots | 499 | Run 16 pets at once (up from 8). More modifiers, rarer combos, higher ceiling. |
| `lucky_eggs` | Lucky Eggs | 599 | 2x odds for rare through mythic pets from every egg. Hatch faster, flex harder. |
| `infinite_gas` | Infinite Gas | 999 | Gas never depletes. Infinite runs, infinite greed. The whale flex pass. |
| `ultra_lucky` | Ultra Lucky | 1299 | Cranked rare+ odds from eggs. Stacks with Lucky Eggs — go for the god-roll inventory. |
| `auto_drive` | Auto-Drive | 699 | Silky auto-steering assist. Easier PBs on phone, cleaner lines on PC — grind without the sweat. |
| `gas_3x` | 3x Gas | 799 | Triple gas tank on every car. Longer runs before refill — pairs with Infinite Gas for the ultimate route. |
| `pet_magnet` | Pet Magnet | 399 | +10% effective pet coin power from your team. Small pass, big multiplier on a stacked roster. |
| `rebirth_rush` | Rebirth Rush | 599 | Rebirths cost 25% less coins. Hit the next multiplier tier faster than everyone else. |
| `coin_boost` | Coin Boost | 349 | +10% coins every time you finish a run. Pure drip — stacks with 2x Coins. |

### Game pass — success path (server)

After a successful purchase, `GamePassService` fires a **success** notification:

- Message: `Purchased {passDef.name}!` (e.g. `Purchased 2x Coins!`)

`PurchaseComplete` payload (thank-you queue): `productType = "gamepass"`, `displayName` = pass `name`, `benefits` = single line from pass `description` or fallback `"Permanent unlock"`.

### Game pass — error / dev (ID 0)

- `Game pass not linked in Studio yet (ID 0).` — **error** notification when `gamePassId == 0`.

---

## 2. Developer products catalog

Store row pattern: `{name} — {robuxPrice}R` (description is not shown on the row; see `description` in config for catalog reference and thank-you benefits).

| Config key | Display name | Robux | Description (config) |
|------------|--------------|-------|----------------------|
| `coins_1k` | 1,000 Coins | 49 | Fast coin top-up. Grab upgrades and keep your run streak alive. |
| `coins_10k` | 10,000 Coins | 149 | Meaningful stack — cars, eggs, and rebirth fuel without the wait. |
| `coins_100k` | 100,000 Coins | 399 | Skip the slow climb. Jump tiers and buy the toys everyone else is still saving for. |
| `coins_1m` | 1,000,000 Coins | 999 | Million-coin flex. Instantly compete with the biggest wallets in the server. |
| `gems_100` | 100 Gems | 99 | A clean gem bump for eggs, skips, and clutch moments. |
| `gems_1k` | 1,000 Gems | 399 | Serious gem line — enough to chase high-tier eggs and speedruns. |
| `gems_pack_m` | 3,000 Gems | 599 | Whale-friendly gem stack. Best value per Robux before the mega vault. |
| `crystals_50` | 50 Crystals | 199 | Premium currency for premium unlocks. Skip the line on the stuff that matters. |
| `crystals_500` | 500 Crystals | 799 | Big crystal bundle — unlock endgame shop and world gates in one swipe. |
| `instant_rebirth` | Instant Rebirth | 299 | Rebirth immediately — no coin gate. Hit the next multiplier while others are still grinding. |
| `auto_hatch_3` | Auto-Hatch 3 Eggs | 99 | Pop three eggs from inventory instantly. More rolls, faster god pets. |
| `skip_world` | Skip World Unlock | 499 | Unlock the next world instantly — skip the currency gate and race the leaderboard. |
| `gems_pack_l` | 10,000 Gems | 999 | Mega gem vault. For players who want every egg and every skip on tap. |
| `crystals_pack_l` | 5,000 Crystals | 1999 | Max crystal line — completionist fuel for the rarest unlocks. |
| `starter_pack` | Starter Pack | 199 | One-time: 25K coins, 500 gems, 3 Meadow Eggs. Jump the queue on day one. |
| `battle_pass_premium` | Battle Pass Premium Track | 749 | Unlock the premium track — Season 1: Midnight Velocity. Exclusive cosmetics, boosts, and bragging rights. |

**FOMO (event badge):** `battle_pass_premium` may show `eventBadgeLabel` **LAUNCH DRIVER** (with `eventBadgeExpiresAt`) until expired — see `DevProductConfig` / `FomoBadgeLabelConfig`.

### Developer products — success notifications (server)

| Flow | Notification type | Message |
|------|-------------------|---------|
| Starter Pack | success | `Starter Pack claimed! +25K coins, +500 gems, +3 Meadow Eggs` |
| Battle Pass Premium | success | `Premium battle pass unlocked!` |
| Currency bundles | success | `+{amount} {currency}!` (e.g. `+10000 gems!`) |

### Developer products — duplicate / guardrails (server)

| Condition | Notification type | Message |
|-----------|-------------------|---------|
| `productId == 0` | error | `Developer product not linked in Studio yet (ID 0).` |
| Starter Pack already owned | error | `Starter Pack already purchased.` |
| Battle Pass Premium already owned | error | `You already have Premium for this season.` |

### Thank-you overlay — benefit lines (`DevProductService.benefitLinesForReward`)

| Reward type | Lines shown under checkmarks |
|-------------|------------------------------|
| `starter_pack` | `+25,000 coins`, `+500 gems`, `+3 Meadow Eggs` |
| `battle_pass_premium` | `Premium battle pass track unlocked` |
| `{ currency, amount }` | `+{amount} {currency}` |
| `instant_rebirth` | `Instant rebirth completed` |
| `auto_hatch` | `Auto-hatched up to {count} eggs` |
| `skip_world` | `Next world unlocked` |
| fallback | product `description` or `Thank you for your purchase!` |

---

## 3. Purchase thank-you overlay (client)

`PurchaseThankYouController` — headline / subline by product type:

| `productType` | Headline | Subline |
|---------------|----------|---------|
| `gamepass` | `GAMEPASS UNLOCKED!` | `This power is yours FOREVER!` |
| `devproduct` (default) | `THANK YOU FOR YOUR PURCHASE!` | `Your items have been delivered!` |

- Item title: `displayName` from payload (from config `name`).
- Game pass ribbon on icon: `PERMANENT`.
- Primary button: `ENJOY!` (then `ENJOY! (1)` countdown; auto-dismiss ~5s).

---

## 4. MicrocopyConfig pools (purchase-adjacent)

| Pool | Purpose | Module |
|------|---------|--------|
| `PurchaseFail` | Soft-currency denial / afford fail on store & garage actions (not Robux) | `MicrocopyConfig.luau` |
| `RemoteLoadError` | Failed remote sync toasts | same |

**§9 mapping (POLA-310):** IAP-specific Robux strings live **outside** `MicrocopyConfig` (server `Notification` events + thank-you overlay). Only soft-currency **PurchaseFail** is in the pool table above.

---

## 5. Changelog

| Date | Change |
|------|--------|
| 2026-03-22 | Initial land in `docs/marketing/`; aligned with `GamePassConfig`, `DevProductConfig`, `GamePassService`, `DevProductService`, `PurchaseThankYouController`, `MicrocopyConfig`. POLA-602: `battle_pass_premium` display name = `Battle Pass Premium Track` (see `Phase4_RobloxStoreCopyPackage.md` §7). |
