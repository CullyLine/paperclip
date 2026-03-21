# Technical roadmap — Drive a Car Simulator → 1.0

This document is the engineer review of `memories/DriveACarSimulator/` against the **POLA-1** product brief (auto-runner driving, four currencies, pets/eggs/rebirth/worlds, P2W monetization). It inventories what is implemented, calls out gaps and risks, and lists prioritized work to ship 1.0.

---

## 1. Architecture snapshot

| Layer | Location | Role |
|--------|-----------|------|
| Shared types & tuning | `DACReplicatedStorage/` (`Types`, `Constants`, `Utils`, `Config/*`) | Single source of truth for stats, economy, content IDs |
| Networking | `Remotes.luau` | Server creates `DACRemotes` folder under `ReplicatedStorage`; events + `GetPlayerData` / `GetLeaderboard` |
| Persistence | `DataManager.luau` | `DACPlayerData_v1` DataStore, reconcile-on-load, 120s autosave, bind-to-close |
| Gameplay (server) | `DACServerScriptService/Services/*.luau` | Currency, cars, runs, upgrades, rebirth, worlds, eggs, pets, passes, dev products, premium, daily rewards, codes, leaderboards, trade stub |
| Client | `DACStarterPlayerScripts/` + `DACStarterGui/` | Bootstrap, driving, pets, UI bridge, HUDs |

**Entry points:** `MainServer.server.luau` (server), `Bootstrap.client.luau` (client).

---

## 2. What is implemented and working

### 2.1 Data & progression

- **Schema** with forward-compatible `reconcile()` merge; currencies, cars (per-car upgrade levels), pets (UID map), eggs inventory, rebirth count + `rebirthStats`, worlds, daily streak, redeemed codes, settings, lifetime stats.
- **Cars:** buy (per-world + currency), equip, effective **gas / power / speed** with upgrades + rebirth bonuses + **2× speed** and **infinite gas** game passes applied in `CarService.getEffectiveStats`.
- **Runs (server-authoritative):** `RunService` Heartbeat loop — gas drain, distance = `speed * dt`, lap rollover when `currentLapDistance >= highwayLength`, payout at gas-out using world coin multiplier × **pet modifier** × **2× coins** pass × **Premium** bonus.
- **Pets:** equip / unequip / equip-best, fuse; pet modifier = `1 + (sum of equipped pet power) / 100` on coin earnings.
- **Eggs:** buy, weighted hatch with **Lucky Eggs** pass doubling non–common/uncommon weights.
- **Rebirth:** coin cost scaling, stat/crystal rewards, configurable reset of coins and per-car upgrade levels.
- **Worlds:** unlock gates (coins/gems/crystals), switch current world.
- **Monetization plumbing:** `UserOwnsGamePassAsync` on join + `PromptGamePassPurchaseFinished`; `ProcessReceipt` for dev products; Premium coin bonus constant.
- **Meta:** 7-day daily rewards, three launch codes (`LAUNCH`, `STYLXUS90K`, `SPEED`), OrderedDataStore leaderboards.

### 2.2 Client

- **DrivingController** + **DrivingHUD:** steering (keyboard + touch), run HUD (gas bar, distance, laps, speed readout).
- **HUD:** four-currency strip with `Utils.formatNumber`.
- **UIController:** caches server `DataUpdate` / `CurrencyUpdate`; notifications and run/hatch results currently **print to output** (no real UI frames).

### 2.3 Fixes applied during this review

- **`TradeService` was never started:** `TradeService.luau` defines `init()` but `MainServer` did not call it, so `TradeRequest` did nothing. **Resolved:** `MainServer` now `require`s and `TradeService.init()` so the placeholder “Trading coming soon!” path is live.

---

## 3. Gaps vs POLA-1 / 1.0 (prioritized)

### P0 — Blocking a public beta

| Item | Notes |
|------|--------|
| **Full-screen UI modules** | Only `HUD` + `DrivingHUD`. Need: **InventoryUI** (cars), **StoreUI**, **EggShopUI**, **RebirthUI**, **SettingsUI**, **CodesUI**, **DailyRewardUI**, plus **post-run summary** (design calls for payout screen). `UIController` is ready as a data bridge; no screens consume it yet. |
| **Monetization prompts** | `Remotes` includes `PurchaseGamePass` and `PurchaseDevProduct`, but **no server `OnServerEvent` handlers** call `MarketplaceService:PromptGamePassPurchase` / `PromptProductPurchase`. Store UI must trigger prompts safely (client can prompt; validate ownership server-side — already pattern in `GamePassService`). |
| **Roblox asset IDs** | `GamePassConfig` / `DevProductConfig` use **`gamePassId = 0` / `productId = 0`**. Live game requires creating assets in Roblox and pasting real IDs. Pass checks skip ID 0 (no false positives, but **no pass works** until IDs are set). |
| **3D & audio** | No `Workspace` content in Rojo tree: cars/pets/worlds are config-only. Sound is placeholder (`SoundController`). Needed for 1.0 feel: lobby, highways, models, SFX, music (see `ConceptArt/` and CEO reference pack). |

### P1 — Gameplay / economy correctness

| Item | Notes |
|------|--------|
| **Power stat in runs** | ~~Previously thought unused.~~ **Resolved (POLA-55 audit):** `RunService.endRun` applies `powerMultiplier = 1 + effectivePower * 0.01` to coin payout. Power is a meaningful earnings multiplier. |
| **Auto-Collect pass** | **Partially implemented** but double-gated: requires both `auto_collect` AND `infinite_gas` passes plus lap threshold. Fix tracked in POLA-60. |
| **VIP pass perks** | `VipEffectsService` and `VipNametag` implement chat prefix + glow. Exclusive car skin config exposed but **not wired on client**. |
| **Receipt idempotency** | ~~Previously thought missing.~~ **Resolved (POLA-55 audit):** `DevProductService.processReceipt` tracks `processedReceiptIds` in player data. Dedup is implemented. |

### P2 — Security & scale

| Item | Notes |
|------|--------|
| **Remote spam** | Many `OnServerEvent` handlers have minimal rate limits. Add per-player cooldowns or lightweight quotas on high-frequency actions once UI drives more traffic. |
| **Run integrity** | Distance and payout are server-side (good). Client prediction in `DrivingController` should stay cosmetic-only; avoid trusting client-reported distance for rewards. |
| **Trading** | `TradeService` is still a stub; full system needs inventory locks, two-party confirmation, and exploit review before enable. |

### P3 — Polish & ops

- **Constants:** currency icons use `rbxassetid://0` placeholders.
- **Performance:** profile Heartbeat cost with many concurrent runs; batch `FireClient` where needed.
- **DataStore session lock:** `SESSION_LOCK_EXPIRE` is defined in `DataManager` but not used for true session locking — document or implement if concurrent-place joins become an issue.

---

## 4. Suggested sub-task breakdown (for ticketing)

1. **UI — Inventory & store** — Grids for cars/pets, equip flows, bind to `BuyCar` / `EquipCar` / pet remotes.
2. **UI — Economy surfaces** — Egg shop + hatch reveal UX; rebirth panel with live cost from `Utils.calculateRebirthCost`.
3. **UI — Meta** — Daily reward calendar; code entry; settings bound to `UpdateSettings`.
4. **Monetization** — Create Roblox passes/products; fill config IDs; wire `PurchaseGamePass` / `PurchaseDevProduct` handlers + client prompts.
5. **Gameplay** — Auto-Collect double-gate fix (POLA-60); VIP exclusive skin client wiring.
6. **Trading** — Replace stub with secure flow or keep disabled until post-1.0.
7. **Content** — World geometry, car/pet meshes, VFX, audio per `ConceptArt/` direction.
8. **Hardening** — Remote throttles, optional anti-tamper on run state. (Receipt dedupe already done.)

---

## 5. File map (quick reference)

```
memories/DriveACarSimulator/
  default.project.json
  README.md
  TECHNICAL_ROADMAP.md          ← this file
  CompetitiveAnalysis_EconomyDesign.md
  ConceptArt/
  DACReplicatedStorage/         → ReplicatedStorage.DAC
  DACServerScriptService/       → ServerScriptService.DAC
  DACStarterPlayerScripts/      → StarterPlayer.StarterPlayerScripts.DAC
  DACStarterGui/                → StarterGui.DAC
```

---

## 6. Verdict

The codebase is a **coherent vertical slice**: server rules, progression, and monetization hooks align with POLA-1’s simulator loop. **1.0 is blocked primarily on UI surface area, Roblox marketplace IDs, 3D/audio content, and a few incomplete pass behaviors (auto-collect, VIP cosmetics, power meaning).** The items above are ordered so design and engineering can parallelize without rewriting core systems.

---

#### Files on disk

- `memories/DriveACarSimulator/TECHNICAL_ROADMAP.md` — this roadmap (full review + backlog).
- `memories/DriveACarSimulator/DACServerScriptService/MainServer.server.luau` — `TradeService` wired so trade placeholder remotes work.
