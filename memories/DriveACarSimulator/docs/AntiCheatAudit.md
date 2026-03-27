# Anti-cheat audit — Drive a Car Simulator

Server-side validation sweep (POLA-228). Remotes are defined in `DACReplicatedStorage/Remotes.luau`. Rate limiting uses `ValidationService.checkRemoteRate()` (per-remote timestamps; movement remotes `StartRun` / `EndRun` use a 0.1s bucket; `UpdateSettings` uses 0.08s; others default 0.5s unless noted). Most handlers also use `RemoteCooldown.allow()` for gameplay pacing.

## Remote coverage matrix

| Remote | Service | Rate limit first? | Arg type checks | Currency / value notes |
|--------|---------|-------------------|-----------------|------------------------|
| `GetPlayerData` | `MainServer.server` | Yes | N/A (player only) | Read-only; returns `nil` if throttled |
| `GetLeaderboard` | `LeaderboardService` | Yes | `stat` must be `string` | Empty `{}` if throttled / bad args |
| `GetPassFlags` | `GamePassService` | Yes | N/A | Empty `{}` if throttled |
| `GetQuests` | `QuestService` | Yes | N/A | `nil` if throttled |
| `GetAchievementData` | `AchievementService` | Yes | N/A | `nil` if throttled |
| `AdminAuth` | `AdminService` | Yes | N/A | `false` if throttled |
| `StartRun` | `RunService` | Yes | N/A | Run state server-authoritative; gas/distance in `tick` |
| `EndRun` | `RunService` | Yes | N/A | Payout from server `endRun`; client cannot set coins |
| `NearMissClaim` | `RunService` | Yes | N/A | Coins via `CurrencyService.add(..., "near_miss")`; per-run cap + chain logic server-side |
| `BuyCar` | `CarService` | Yes | `carId` string | Spends via `CurrencyService.spend` |
| `EquipCar` | `CarService` | Yes | `carId` string | |
| `UpgradeStat` | `UpgradeService` | Yes | `carId`, `stat` strings | |
| `BuyEgg` | `EggService` | Yes | `eggId` string | |
| `HatchEgg` | `EggService` | Yes | `eggId` string | |
| `EquipPet` | `PetService` | Yes | `petUid` string | |
| `UnequipPet` | `PetService` | Yes | `petUid` string | |
| `FusePets` | `PetService` | Yes | `petUids` table | Validates contents in `fusePets` |
| `Rebirth` | `RebirthService` | Yes | N/A | |
| `UnlockWorld` | `WorldService` | Yes | `worldId` string | |
| `ChangeWorld` | `WorldService` | Yes | `worldId` string | |
| `ClaimDailyReward` | `DailyRewardService` | Yes | N/A | |
| `ClaimBattlePassTier` | `BattlePassService` | Yes | `tier` number, `track` string | |
| `RedeemCode` | `CodeService` | Yes | `code` string | Rewards only through `CurrencyService.add(..., "code_redemption")`; plus `RemoteCooldown` |
| `PurchaseGamePass` | `GamePassService` | Yes | `passId` string | Prompt only; Robux via Marketplace |
| `PurchaseDevProduct` | `DevProductService` | Yes | `productKey` string | Prompt + `ProcessReceipt` grants |
| `PurchaseThankYouAck` | `DevProductService` | Yes | N/A | Flushes milestone batch; no currency |
| `UpdateSettings` | `SettingsService` | Yes | `patch` table | Clamps numeric settings in `apply` |
| `TradeRequest` | `TradeService` | Yes | Optional `number` target | Placeholder UI |
| `TutorialSkip` | `TutorialService` | Yes | N/A | |
| `MarkAchievementsSeen` | `AchievementService` | Yes | N/A | |
| `AdminCommand` | `AdminService` | Yes | `payload` table | `isAuthorized` gate inside handler |

### Listed but not wired to a server handler

| Remote | Note |
|--------|------|
| `TradeRespond` | Reserved; no `OnServerEvent` yet (see `PostPhase3Audit.md`) |

## Currency integrity

- **Grants:** `DataManager.addCurrency` requires `ValidationService.validateCurrencySource(source)`. Whitelist lives in `ValidationService.luau` (`ALLOWED_CURRENCY_SOURCES`). Server-only code paths (e.g. `run_complete`, `code_redemption`, `near_miss`, `admin`, `admin_global`, …).
- **Spends:** `CurrencyService.spend` → `DataManager.spendCurrency` (no remote; client cannot invoke).
- **Client replication:** `CurrencyUpdate` is server-fired only.

## Speed / movement

- **Run simulation:** Distance and payouts are computed in `RunService` on the server from `run.speed` and delta time, not from client-reported distance for awards.
- **Anti-cheat sample:** `ValidationService` Heartbeat compares `HumanoidRootPart` displacement each second to `getMaxSpeedStudsPerSec` (car stats + passes). Repeated anomalies can kick (non-Studio).

## Code redemption

- `RedeemCode`: `checkRemoteRate` + `RemoteCooldown` limit rapid attempts.
- Validity is O(1) table lookup; no client-controlled amounts.

## Files touched in this audit pass

- `DACServerScriptService/Services/ValidationService.luau` — whitelist `near_miss`, `admin_global` (fixes blocked legitimate grants).
- `DACServerScriptService/MainServer.server.luau` — `GetPlayerData` rate limit.
- `DACServerScriptService/Services/AchievementService.luau` — `GetAchievementData` rate limit.
- `DACServerScriptService/Services/AdminService.luau` — `AdminCommand`, `AdminAuth` rate limits.
- `DACServerScriptService/Services/TradeService.luau` — `TradeRequest` rate limit + optional target type check.
- `DACServerScriptService/Services/DevProductService.luau` — `PurchaseThankYouAck` rate limit.
- Multiple services — `checkRemoteRate` moved to the **first** line before argument type checks where applicable.
