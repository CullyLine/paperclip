# Drive a Car Simulator — Client/Server Performance Audit

**Date:** 2026-03-22  
**Scope:** Luau client controllers, GUI scripts, and `MainServer` remotes. Focus: memory leaks, connection churn, hot-path `require`, RunService loops, and network payload shape.

---

## Summary

| Severity | Count | Action |
|----------|-------|--------|
| P0 (fixed) | 2 | PetConfig hot-path require; tutorial highlight tween cleanup |
| P1 (documented) | 3 | Event banner per-frame tick; DataUpdate full snapshots; confetti tween volume |
| P2 | several | Micro-optimizations and optional refactors |

---

## 1. Connection cleanup

### `DACStarterPlayerScripts/Controllers/DrivingController.luau`

- **RenderStepped:** One permanent `RunService.RenderStepped:Connect(updateDriving)` in `init()`. Does not multiply per run; `updateDriving` no-ops when `isRunning` is false. **OK.**
- **Collision:** `hookCollisionSfx` replaces `collisionConn` via `disconnectCollisionSfx()` before rebinding; `endRun()` disconnects. **OK.**
- **Touch:** Three permanent `UserInputService` connections. **OK.**

### `DACStarterPlayerScripts/Controllers/VFXController.luau`

- Ephemeral `RenderStepped` usages (e.g. VIP rainbow border ~956, stat level-up counter ~1402, egg wobble ~2555) disconnect when the target instance is destroyed or when animation completes. **OK** for typical patterns reviewed.
- **Heartbeat:** Single permanent `RunService.Heartbeat` in `init()` for FPS LOD sampling. **OK** (long-lived client singleton).

### `DACStarterGui/EventBanner.luau`

- **Shimmer / urgent pulse:** `startShimmer` / `startUrgentPulse` guard with `stopShimmer` / `stopUrgentPulse` and disconnect stored connections. **OK.**
- **Global RenderStepped:** `RunService.RenderStepped:Connect` runs every frame; body only does work when `gui.Enabled and endsAtUnix`. **P1:** Could switch to `Heartbeat` + throttling or a `RunService` connection that disconnects when the banner is hidden to reduce scheduler wakeups on idle clients (low impact if banner is rare).

### `DACStarterGui/TutorialOverlay.luau`

- **P0 fixed:** `applyHighlight` ran an infinite ping-pong tween on `UIStroke` without cancelling when the step changed. `clearHighlight()` now cancels `highlightStrokeTween` before destroying the stroke.

### Bootstrap / remotes

- `Bootstrap.local.luau` wires one-shot remote listeners (`OnClientEvent:Connect` per event). **OK** — no reconnection loops.

---

## 2. Require deduplication

### `DACStarterPlayerScripts/Bootstrap.local.luau`

- **P0 fixed:** `PetConfig` was `require()`d inside `syncEquippedPets` for every equipped pet on every `DataUpdate`. Now required once at module scope; loop uses `PetConfig.Pets[pet.id]`.

### `DACStarterPlayerScripts/Controllers/UIController.luau`

- Config modules (`PetConfig`, `EggConfig`, etc.) already at module scope. **OK.**

---

## 3. Tween / instance lifecycle

### `DACStarterGui/TutorialOverlay.luau` — confetti

- Spawns 40 `Frame` pieces + delayed tweens; container destroyed after 3s. **P1:** Under rapid retests, many simultaneous tweens could stack; acceptable for a rare “tutorial complete” moment. Optional: object pool or fewer pieces on low memory.

### `DACStarterPlayerScripts/Controllers/VFXController.luau`

- Celebration paths generally `Destroy()` labels/frames after tween completion or use self-disconnecting `RenderStepped`. **OK** on sampled paths; file is large — spot-check when adding new effects.

---

## 4. RunService efficiency

### DrivingController

- Single `RenderStepped` binding; no accumulation across runs. **OK.**

### VFXController

- FPS-driven LOD uses `Heartbeat` once. **OK.**

### EventBanner

- **P1:** Extra `RenderStepped` for countdown refresh while banner enabled; consider event-driven or 1 Hz timer if profiling shows cost.

---

## 5. DataUpdate payload size

### `DACServerScriptService/MainServer.server.luau`

- `Remotes.getEvent("DataUpdate"):FireClient(player, data)` sends full `DataManager.get(player)` snapshot on join and whenever the server chooses to fire updates (see data layer for all call sites).

- **P1 / design:** For players with large `pets` and `achievements` tables, full-table replication increases bandwidth and client decode cost. **Future:** channel-specific updates (e.g. `InventoryDelta`, `SettingsPatch`), or compress keys / send hashes for unchanged sections — requires server and client contract work.

---

## 6. Fixes applied (this pass)

| Item | File | Change |
|------|------|--------|
| Hot-path `require` | `Bootstrap.local.luau` | Module-scope `PetConfig` |
| Orphan tween risk | `TutorialOverlay.luau` | Cancel `highlightStrokeTween` in `clearHighlight` |
| Connection accumulation | `EventBanner.luau` | `slideIn` uses `Tween.Completed:Once` instead of `Connect` |

---

## 7. Follow-up (not done)

- Profile `EventBanner` global `RenderStepped` vs timer-based refresh.
- Design delta or scoped `DataUpdate` payloads with versioning.
- Optional: audit remaining `VFXController.luau` for any new `Connect` without matching `Disconnect` when adding features.
