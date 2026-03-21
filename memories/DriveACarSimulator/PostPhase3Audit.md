# Post-Phase 3 Require-Path & Init-Order Audit

**Scope:** All `.luau` files under `memories/DriveACarSimulator/`  
**Date:** 2026-03-20  
**Method:** Static review (Rojo `default.project.json` tree), full-text search for `require()`, `Remotes.get*`, `data.` usage, and cross-check against `MainServer.server.luau`, `Remotes.luau`, `DataManager.luau`, `Constants.luau`, `GuiBootstrap.client.luau`, `Bootstrap.client.luau`.

---

## 1. Require paths

**Result: PASS** — Every `require()` observed uses `WaitForChild` chains that resolve under the Rojo layout:

| Root | Maps to |
|------|---------|
| `ReplicatedStorage.DAC` | `DACReplicatedStorage/` |
| `ServerScriptService.DAC` | `DACServerScriptService/` |
| `StarterPlayer.StarterPlayerScripts.DAC` | `DACStarterPlayerScripts/` |
| `StarterGui.DAC` | `DACStarterGui/` |

**Checked modules:** `Remotes`, `Constants`, `Types`, `Utils`, `VFXFacade`, `SoundFacade`, all `Config/*` modules referenced by services and UI, every `Services/*.luau` (including `RemoteCooldown`), `DataManager`, and all `Controllers/*.luau`.

**Note:** Dynamic requires inside functions (e.g. `ValidationService` returning `DataManager`, `DevProductService` requiring sibling services) still target paths that exist on disk.

No broken `require()` targets were found.

---

## 2. MainServer init order

**Result: PASS (with documented intent)**

From `DACServerScriptService/MainServer.server.luau`:

1. `Remotes.init()` — creates `DACRemotes` under `ReplicatedStorage`.
2. `DataManager.init()` — DataStore session + autosave before any service touches player data.
3. Service `init()` order:

`EventService` → `CurrencyService` → `CarService` → `RunService` → `UpgradeService` → `RebirthService` → `WorldService` → `EggService` → `PetService` → `GamePassService` → `ValidationService` → `VipEffectsService` → `DevProductService` → `PremiumService` → `DailyRewardService` → `CodeService` → `LeaderboardService` → `TradeService` → `PlaytimeService` → `SettingsService` → `BattlePassService` → `QuestService` → `AdminService` → `TutorialService`

**Verification:** Each `require(Services:WaitForChild("…"))` in `MainServer.server.luau` has a matching `Services/<Name>.luau` file on disk (25 service modules including `PremiumService`).

**Dependency sanity:** `DataManager` is initialized before all services; `GetPlayerData` is wired after service inits (uses `ValidationService` + `DataManager`). `TutorialService.init()` runs last among services, after `AdminService.init(DataManager)` — consistent with tutorial depending on loaded systems.

---

## 3. Remotes.luau consistency

**Registry:** `REMOTE_EVENTS` + `REMOTE_FUNCTIONS` in `DACReplicatedStorage/Remotes.luau`.

### Referenced in server or client code (used)

All remotes that appear in `Remotes.getEvent` / `Remotes.getFunction` calls are present in the registry.

### Server-only / not yet used from client UI

The following remotes have **server `OnServerEvent` / `OnServerInvoke` handlers** but **no `FireServer` / `InvokeServer` from any client script** in this tree (future UI or CLI):

| Remote | Server file |
|--------|-------------|
| `UnlockWorld` | `WorldService.luau` |
| `ChangeWorld` | `WorldService.luau` |
| `FusePets` | `PetService.luau` |

### Defined but minimal / placeholder

| Remote | Notes |
|--------|--------|
| `TradeRequest` | `TradeService.luau` — placeholder (“Trading coming soon!”). |
| `TradeRespond` | Listed in `Remotes.luau` but **no** `OnServerEvent` and **no** client usage yet. |

### `GetLeaderboard`

- **Server:** `LeaderboardService.luau` registers `GetLeaderboard` `OnServerInvoke`.
- **Client:** No `InvokeServer("GetLeaderboard")` in this repo — leaderboard UI not wired yet.

**Conclusion:** Registry is internally consistent (no references to undefined remote names). Several remotes are intentionally ahead of UI (world change, fuse, trade, leaderboard).

---

## 4. DataManager `DEFAULT_DATA` vs service usage

**Result: PASS**

Top-level profile fields used across `DACServerScriptService` (`data.*` / `pdata.*`) align with `getDefaultData()` in `DataManager.luau`, including:

- `tutorialStep`, `tutorialComplete`
- `joinedDuringLaunch`, `lastRunOfDayDate`, `founderBonusNotified`
- `starterPackPurchased`, `processedReceiptIds`
- Nested `quests`, `battlePass`, `dailyReward`, `settings`, `stats`, etc.

Services that extend missing nested tables at runtime (e.g. `QuestService` ensuring `data.quests`, `BattlePassService` patching `titles` / `cosmetics` / `consumables`) are defensive against older saves; `reconcile()` in `DataManager` still merges against the full template for new keys.

---

## 5. Constants.luau vs imports

**Result: PASS**

Every `Constants.<name>` reference found under `memories/DriveACarSimulator` resolves to a field defined in `DACReplicatedStorage/Constants.luau`.

**Unused exports (not a defect):** `REBIRTH_BASE_COST`, `REBIRTH_COST_MULTIPLIER`, `REBIRTH_STAT_REWARD` are defined for rebirth economy documentation / future use; rebirth costs are driven by `RebirthConfig` in code paths reviewed.

---

## 6. GuiBootstrap.client.luau completeness

**Result: PASS**

`DACStarterGui/GuiBootstrap.client.luau` requires and initializes every major GUI module in that folder **except:**

- **`UIHelpers.luau`** — shared helpers; pulled in by panels, not an entry module.
- **`LoadingScreen.client.luau`** — lives under `ReplicatedFirst` per `default.project.json`, not started from `GuiBootstrap`.

All other `DACStarterGui/*.luau` modules that expose `init()` are listed in `GuiBootstrap`.

---

## 7. Bootstrap.client.luau completeness

**Result: PASS**

`DACStarterPlayerScripts/Bootstrap.client.luau` requires and initializes:

- `Controllers`: `DrivingController`, `PetController`, `UIController`, `SoundController`, `VFXController`
- `TitleNametag` (+ `init()`)
- `VFXFacade` bound to `VFXController`

**Related scripts not in Bootstrap (by design):**

- **`VipNametag.client.luau`** — standalone `LocalScript` for VIP billboard; runs automatically.
- **`TitleNametag.client.luau`** — loaded from Bootstrap via `require`, not duplicated.

---

## 8. Summary

| Check | Status |
|-------|--------|
| Require paths | PASS |
| MainServer init order & service files | PASS |
| Remotes registry vs usage | PASS (see unused/placeholder remotes above) |
| DataManager defaults | PASS |
| Constants | PASS |
| GuiBootstrap | PASS |
| Bootstrap.client | PASS |

No blocking defects found. Follow-ups (optional): wire client UI to `ChangeWorld` / `UnlockWorld` / `FusePets`, implement `TradeRespond` + trade flow, add leaderboard UI calling `GetLeaderboard`, or remove/comment unused remote names if the API surface should stay minimal.

#### Files on disk

- `memories/DriveACarSimulator/PostPhase3Audit.md` (this file)
