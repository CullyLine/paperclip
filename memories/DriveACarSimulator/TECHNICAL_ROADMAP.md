# Technical roadmap — Drive a Car Simulator → 1.0

This document is the engineer review of `memories/DriveACarSimulator/` against the **POLA-1** product brief (auto-runner driving, four currencies, pets/eggs/rebirth/worlds, P2W monetization). It inventories what is implemented, calls out gaps and risks, and lists prioritized work to ship 1.0.

**As of 2026-03-23** — truth-sync pass vs `CarConfig` / `PetConfig` / `EggConfig`, `DACStarterGui/GuiBootstrap.local.luau`, `GamePassService`, `BattlePassService`, and `RunService`. Older bullets below that conflict with source files should be treated as **historical** unless this date header is refreshed.

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
- **UIController** + **MenuHub:** server data bridge, toast/overlay wiring, panel registration.
- **Pre-built feature panels** (initialized from `GuiBootstrap.local.luau`, shells under `StarterGui`): **DailyReward**, **World**, **BattlePass**, **Quest**, **PetIndex**, **Inventory**, **Store**, **EggShop**, **Rebirth**, **Settings**, **Codes**, **Payout** (post-run), **PlaytimeGem**, **Event** / **GroupJoin** banners, **FriendBonus** HUD, **Tutorial** overlay, **Leaderboard**, **TrophyCase** (mounted after deferred init), **Admin** (gated). This replaces the earlier snapshot where only HUD + DrivingHUD existed.

### 2.3 Fixes applied during this review

- **`TradeService` was never started:** `TradeService.luau` defines `init()` but `MainServer` did not call it, so `TradeRequest` did nothing. **Resolved:** `MainServer` now `require`s and `TradeService.init()` so the placeholder “Trading coming soon!” path is live.

---

## 3. Gaps vs POLA-1 / 1.0 (prioritized)

### P0 — Blocking a public beta

| Item | Notes |
|------|--------|
| **Full-screen UI modules** | ~~Only HUD + DrivingHUD.~~ **As of 2026-03:** Major panels are **implemented and bootstrapped** (inventory, store, eggs, rebirth, settings, codes, payout, daily, worlds, BP, quests, pets index, leaderboards, trophy case, etc.). Remaining risk is **polish / UX depth** (edge flows, loading states), not absence of screens. |
| **Monetization prompts** | ~~No server handlers.~~ **As of 2026-03:** `GamePassService` handles `PurchaseGamePass` (`OnServerEvent`); `DevProductService` handles `PurchaseDevProduct`; client uses `MarketplaceService` prompts (`Bootstrap` / `StorePanel` patterns). **Live purchase still requires real asset IDs in config** (see row below). |
| **Roblox asset IDs** | `GamePassConfig` / `DevProductConfig` still use **`gamePassId = 0` / `productId = 0`** until Creator Dashboard IDs are applied (**POLA-95**). Pass logic skips ID 0 so dev does not false-own; **production** needs non-zero IDs. |
| **3D & audio** | No `Workspace` content in Rojo tree: cars/pets/worlds are largely data-driven from config. Audio pipeline exists (`SoundFacade` / assets under `Audio/`); **production** still needs final mix and world geometry per art direction (`ConceptArt/`). |

### P1 — Gameplay / economy correctness

| Item | Notes |
|------|--------|
| **Power stat in runs** | ~~Previously thought unused.~~ **Resolved (POLA-55 audit):** `RunService.endRun` applies `powerMultiplier = 1 + effectivePower * 0.01` to coin payout. Power is a meaningful earnings multiplier. |
| **Auto-Collect pass** | ~~Double-gated with `infinite_gas` (POLA-60).~~ **As of 2026-03:** `RunService` ends the run on lap rollover when the player has **`auto_collect`** and **`laps >= AUTO_COLLECT_LAPS_BEFORE_BANK`** (`Constants`, default 3). `infinite_gas` is handled separately in `CarService` (gas drain), not as an AND gate for auto-collect. |
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

1. ~~**UI — Inventory & store**~~ — **Largely shipped** (panels + remotes); iterate on UX.
2. ~~**UI — Economy surfaces**~~ — Egg shop, rebirth, payout panels exist; iterate on juice.
3. ~~**UI — Meta**~~ — Daily, codes, settings in tree; iterate on onboarding.
4. **Monetization** — Paste **live** `gamePassId` / `productId` values (**POLA-95**); smoke-test each prompt path in a published place.
5. **Gameplay** — VIP exclusive skin client wiring; tuning (auto-collect lap count, economy) as design requests.
6. **Trading** — Replace stub with secure flow or keep disabled until post-1.0.
7. **Content** — World geometry, car/pet meshes, VFX, final audio per `ConceptArt/` direction.
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

The codebase is a **coherent vertical slice**: server rules, progression, and monetization hooks align with POLA-1’s simulator loop. **As of 2026-03, the primary beta blockers are live Roblox marketplace asset IDs, production 3D/audio/content pass quality, and polish on VIP / edge flows** — not missing menu panels. Power is applied in payouts; auto-collect is lap-threshold based with the Auto-Collect pass. Keep `TECHNICAL_ROADMAP.md` updated when major UI or economy behavior changes.

---

#### Files on disk

- `memories/DriveACarSimulator/TECHNICAL_ROADMAP.md` — this roadmap (full review + backlog); **2026-03-23** truth sync (POLA-760).
- `memories/DriveACarSimulator/DACStarterGui/GuiBootstrap.local.luau` — panel init order (reference for what ships in client UI).
- `memories/DriveACarSimulator/DACServerScriptService/MainServer.server.luau` — `TradeService` wired so trade placeholder remotes work.
