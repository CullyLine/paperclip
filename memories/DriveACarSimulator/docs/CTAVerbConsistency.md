# CTA verb consistency audit (Phase 4)

**Issue:** POLA-307 — primary action labels across **shop**, **daily reward**, **trophy**, **inventory** (plus related surfaces).

**Goal:** One clear verb per *intent* — **Claim** (earned rewards), **Buy** (spend currency / Robux), **Redeem** (codes), **Equip** / **Unequip** (loadout), **Upgrade** (stats), **Hatch** (eggs).

---

## Summary

| Area | Rows audited | Copy changed in-repo | Deferred (Studio / engineer) |
|------|-------------|----------------------|-------------------------------|
| MicrocopyConfig + DailyRewardPanel | 2 | 2 | — |
| StorePanel | 4 | 1 (Game Pass CTA) | — |
| InventoryPanel | 8 | 0 | Fuse primary label is pre-built (`FuseGo`) |
| TrophyCasePanel | 1 | 0 | Browse-only; no primary CTA |
| Egg UI (inventory + popup) | 2 | 0 | Button text lives in StarterGui pre-builds |

---

## Table: surface → current → recommended → rationale

| Surface | Current label(s) | Recommended | Rationale |
|---------|------------------|-------------|-----------|
| **Store — car (soft currency)** | `Buy` | `Buy` | Keep. Standard purchase verb for coin-priced cars. |
| **Store — stat rows** | `Upgrade` | `Upgrade` | Keep. Distinguishes incremental stat spend from one-shot `Buy`. |
| **Store — Game Pass** | `Robux` | `Buy` | Align with **Dev Products** and **Cars**; row copy already shows `…R` and description. |
| **Store — Dev Product** | `Buy` | `Buy` | Keep. |
| **Daily reward — primary CTA** | `Claim daily reward` | `Claim reward` | Same **Claim** family; panel context makes “daily” redundant. |
| **Daily reward — pressed / pending** | `Claiming...` | `Claiming...` | Keep. Matches progressive pattern (`Redeeming…` on Codes). |
| **Inventory — car** | `Equip` / `Equipped` / `Buy` | (unchanged) | **Equip** for owned; **Buy** for locked — distinct intents, both correct. |
| **Inventory — pet card** | `Equip` / `Equipped` | (unchanged) | Keep. |
| **Inventory — hover panel** | `Equip` / `Unequip` | (unchanged) | Keep. |
| **Inventory — fusion toggle** | `Fusion: On` / `Fusion: Off` | Optional: `Fuse: On` / `Fuse: Off` | Shorter; matches `FusePets` / “fuse” in specs. Low priority. |
| **Inventory — fusion action** | Pre-built `FuseGo` text (Studio) | `Fuse` or `Fuse pets` | Single destructive action — confirm label in Studio matches this doc. |
| **Trophy case** | (cells open tooltip; no cash CTA) | — | No primary commerce/action button; out of scope for verb alignment. |
| **Egg hatch prompt** | Pre-built `Open1` / `Open3` (assumed label “Open…”) | `Hatch` / `Hatch ×3` (or match remote `HatchEgg`) | Tutorial + server use **Hatch**; UI should say **Hatch**, not **Open**, for the same action. |
| **Egg buy popup** | `Buy1` / `Buy3` / `Buy10` wiring | `Buy` on quantity buttons | Keep **Buy** for gem spend. |
| **Battle Pass tier buttons** | `Claim` / `Claimed` / `Locked` / `Premium` | (unchanged) | **Claim** for ready tiers; state labels differ — OK. |
| **Codes** | `Redeem` / `Redeeming…` | (unchanged) | **Redeem** ≠ **Claim** (code entry vs streak reward). |

---

## Files touched (this pass)

| File | Change |
|------|--------|
| `DACReplicatedStorage/Config/MicrocopyConfig.luau` | Added `DailyRewardClaimButtonDefault`, `DailyRewardClaimButtonProgress`. |
| `DACStarterGui/DailyRewardPanel.luau` | Wired claim button copy from MicrocopyConfig. |
| `DACStarterGui/StorePanel.luau` | Game Pass CTA `Robux` → `Buy`. |

**Counts:** 3 files; **2** Microcopy strings added; **1** panel label constant migrated; **1** runtime string updated (Game Pass).

---

## Deferred for Engineer / Studio

1. **StarterGui — EggOpenPrompt:** Set visible button text to **Hatch** (and quantity) instead of **Open** if still present; names can stay `Open1`/`Open3` for code compatibility.
2. **StarterGui — FusionBar.FuseGo:** Ensure visible label matches **Fuse** (or **Fuse pets**) per table above.
3. Optional: rename **Fusion:** toggle copy to **Fuse:** in `InventoryPanel.luau` if product approves.

---

## Verb cheat sheet (canonical)

| Intent | Verb | Example surfaces |
|--------|------|------------------|
| Take an earned streak/daily/BP tier reward | **Claim** | Daily, Battle Pass |
| Spend coins on a car or gem SKU | **Buy** | Store cars, eggs popup, dev products, game passes |
| Enter a promo code | **Redeem** | Codes |
| Put on / take off pet or car | **Equip** / **Unequip** | Inventory, hover |
| Pay coins for a stat level | **Upgrade** | Store upgrade rows |
| Crack eggs after purchase | **Hatch** | Egg prompt (should match tutorial) |
