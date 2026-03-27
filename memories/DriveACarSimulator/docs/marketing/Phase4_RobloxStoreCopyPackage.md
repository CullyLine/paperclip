# Phase 4 — Roblox store copy package (SKU alignment)

**Purpose:** Single place to reconcile **Creator Dashboard** listing text with **in-game** store strings before **POLA-95** (live `gamePassId` / `productId`).  
**Status:** Copy-only; IDs remain `0` in config until Dashboard + wiring complete.  
**Ticket:** POLA-602 (cross-check vs `IAPAndGamePassCopyPack_Phase4.md`, `PreLaunchChecklist.md` §1).

---

## 1. Scope

| Surface | Canonical player-visible strings |
|--------|----------------------------------|
| In-experience Store (`StorePanel.luau`) | `GamePassConfig.Passes[*].name`, `description`, `robuxPrice`; `DevProductConfig.Products[*].name`, `description`, `robuxPrice` |
| Roblox Creator Dashboard (passes / products) | Must match **`name`** and **price** above when pasting titles; descriptions should not contradict config **benefit** claims |
| Launch QA tables | `PreLaunchChecklist.md` §1 — SKU ↔ config-key map for humans |

---

## 2. Related docs

| File | Role |
|------|------|
| [`IAPAndGamePassCopyPack_Phase4.md`](IAPAndGamePassCopyPack_Phase4.md) | Marketing-friendly paraphrases of config; use for tone, not as a second source of truth for numeric prices or legal benefit text |
| [`../StorePageCopy_Phase4.md`](../StorePageCopy_Phase4.md) | Experience page bullets / short description |
| [`../../PreLaunchChecklist.md`](../../PreLaunchChecklist.md) | §1 name/price tables; launch verification |
| `DACReplicatedStorage/Config/GamePassConfig.luau`, `DevProductConfig.luau` | **Authoritative** display names and Robux prices |

---

## 3. POLA-95 guardrail

Do not mark Dashboard “created” or config IDs “wired” until **POLA-95** completes. This package only prevents **copy drift** between docs and Luau.

---

## 4. Config keys — completeness

- **13** game passes — keys match `GamePassConfig.Passes` (see §6 matrix).
- **16** developer products — keys match `DevProductConfig.Products` (see §6 matrix).

---

## 5. Where engineers must mirror config

When creating Marketplace items:

| Dashboard field | Mirror from |
|-----------------|-------------|
| Pass / product **title** | Luau `name` (exact string players see in `StorePanel`) |
| **Price (Robux)** | Luau `robuxPrice` |
| **Long description** (optional) | Start from Luau `description`; shorten for Dashboard caps without changing numeric claims (%, counts, slot numbers) |

Server toasts and thank-you flows use the same `name` / reward lines — see `GamePassService.luau`, `DevProductService.luau`, `PurchaseThankYouController.luau`.

---

## 6. Appendix — full SKU matrix (config = truth)

Robux and keys verified against repo **2026-03-22**.

### 6.1 Game passes

| Config key | `name` (in-game) | Robux |
|------------|-------------------|-------|
| `double_coins` | 2x Coins | 399 |
| `double_speed` | 2x Speed | 499 |
| `auto_collect` | Auto-Collect | 299 |
| `vip` | VIP | 799 |
| `extra_pet_slots` | Extra Pet Slots | 499 |
| `lucky_eggs` | Lucky Eggs | 599 |
| `infinite_gas` | Infinite Gas | 999 |
| `ultra_lucky` | Ultra Lucky | 1299 |
| `auto_drive` | Auto-Drive | 699 |
| `gas_3x` | 3x Gas | 799 |
| `pet_magnet` | Pet Magnet | 399 |
| `rebirth_rush` | Rebirth Rush | 599 |
| `coin_boost` | Coin Boost | 349 |

### 6.2 Developer products

| Config key | `name` (in-game) | Robux |
|------------|------------------|-------|
| `coins_1k` | 1,000 Coins | 49 |
| `coins_10k` | 10,000 Coins | 149 |
| `coins_100k` | 100,000 Coins | 399 |
| `coins_1m` | 1,000,000 Coins | 999 |
| `gems_100` | 100 Gems | 99 |
| `gems_1k` | 1,000 Gems | 399 |
| `gems_pack_m` | 3,000 Gems | 599 |
| `crystals_50` | 50 Crystals | 199 |
| `crystals_500` | 500 Crystals | 799 |
| `instant_rebirth` | Instant Rebirth | 299 |
| `auto_hatch_3` | Auto-Hatch 3 Eggs | 99 |
| `skip_world` | Skip World Unlock | 499 |
| `gems_pack_l` | 10,000 Gems | 999 |
| `crystals_pack_l` | 5,000 Crystals | 1999 |
| `starter_pack` | Starter Pack | 199 |
| `battle_pass_premium` | Battle Pass Premium Track | 749 |

---

## 7. Compliance cross-check (PreLaunch §1 × IAP pack × config)

**Rule:** `PreLaunchChecklist.md` §1 and `IAPAndGamePassCopyPack_Phase4.md` **display name** columns must match **`GamePassConfig` / `DevProductConfig` `name`** for every SKU. Robux columns must match `robuxPrice`.

| Area | Result | Notes |
|------|--------|--------|
| All 13 game passes | **Aligned** | §1 table, IAP §1 table, and config names/prices match (POLA-602 refresh). |
| 13 dev products (coins → skip_world) | **Aligned** | Same. |
| `gems_pack_l`, `crystals_pack_l` | **Was:** PreLaunch used shorthand labels (“Gem Pack L (10K)”, “Crystal Pack L (5K)”) vs config **10,000 Gems** / **5,000 Crystals**. **Now:** §1 uses exact config names. |
| `battle_pass_premium` | **Was:** PreLaunch + IAP used **Battle Pass Premium** vs config **Battle Pass Premium Track**. **Now:** docs use the config `name` everywhere so Dashboard paste = in-game title. |
| IAP marketing paraphrases (`description`) | **OK by design** | IAP pack shortens tone vs Luau `description`; engineers keep **Luau** as the benefit source for Dashboard long text. No conflicting **numbers** (slots, %, currency amounts). |

**Engineer action for POLA-95:** Create Marketplace listings with titles exactly as **`name`** in §6 tables; paste descriptions from Luau or faithful trims.

---

#### Files on disk

- `memories/DriveACarSimulator/docs/marketing/Phase4_RobloxStoreCopyPackage.md` (this file)
- `memories/DriveACarSimulator/docs/marketing/IAPAndGamePassCopyPack_Phase4.md` (display column aligned POLA-602)
- `memories/DriveACarSimulator/PreLaunchChecklist.md` (§1 product labels aligned POLA-602)
