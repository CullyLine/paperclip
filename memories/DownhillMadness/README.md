# Downhill Madness — Setup Guide

## Prerequisites

- Roblox Studio with built-in file sync enabled

## Folder Structure

```
DMServerScriptService/      → sync to ServerScriptService
DMStarterPlayerScripts/     → sync to StarterPlayerScripts
DMReplicatedStorage/        → sync to ReplicatedStorage
DMStarterGui/               → sync to StarterGui
```

## Setup Steps

1. **Open Roblox Studio** and create a new Baseplate place (or open your existing place).

2. **Enable file sync** in Studio (Beta Features → Sync from File System).

3. **Sync each folder** to its corresponding service:
   - Point `DMServerScriptService/` → `ServerScriptService`
   - Point `DMStarterPlayerScripts/` → `StarterPlayerScripts`
   - Point `DMReplicatedStorage/` → `ReplicatedStorage`
   - Point `DMStarterGui/` → `StarterGui`

4. **Create TemplateVehicle** in `ReplicatedStorage`:
   - Add a Model named `TemplateVehicle`
   - Inside it, add a `Body` Model with a primary Part named `Chassis`
   - Add 4 wheel Parts named `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR`
   - Add a `VehicleSeat`
   - Or run `TemplateVehicleBuilder.server.luau` once from the command bar — it will create a placeholder vehicle for you

5. **Set gravity**: In Workspace properties, set `Gravity` to `120` (below the default 196.2) for the floaty low-gravity feel.

6. **Playtest**: Hit Play. You should see the Hub UI (skybox + menu). Click **Play** to queue for a round. The map builds automatically when the round starts and cleans up when it ends.

## Architecture

The game uses a **same-place, deferred-map** architecture:

- **Hub** = UI-only state. No character, no map. Just a skybox and the menu. Players see a fixed camera and the Hub buttons.
- **Map** = Built on-demand by `MapBuilder.build()` when a round starts, destroyed by `MapBuilder.cleanup()` when it ends.
- **Server = Lobby**: Every Roblox server is its own lobby. Players join via the normal Roblox server browser. No TeleportService needed for Quick Play.

### Game Loop

1. Player joins server → Hub UI appears (no character, skybox camera)
2. Player clicks **Play** → queued for next round
3. After short delay → `MapBuilder.build()` generates the hill
4. Pre-Round selection (10s) → pick vehicle
5. Race (120s max) → 3-2-1-GO, drive downhill
6. Results (30s) → Ready Up for next round or Return to Hub
7. Loop: map rebuilds for next round, or cleans up if no one queued

## File Reference

### DMServerScriptService (ServerScriptService)

| File | Purpose |
|------|---------|
| `MapBuilder.luau` | ModuleScript — `build()` generates the hill map, `cleanup()` destroys it and restores Hub lighting |
| `MatchManager.server.luau` | Server-local queue system, game loop state machine (idle → pre_round → racing → results) |
| `RoundController.server.luau` | 3-2-1-GO countdown, 120s race timer, progress tracking, finish detection |
| `PreRoundServer.server.luau` | Server-side vehicle selection (exclusivity, random assignment) |
| `VehicleSpawner.luau` | Clones TemplateVehicle from ReplicatedStorage, places at start positions |
| `ProfileManager.server.luau` | ProfileService wrapper — handles player data (load/save/get/set) |
| `TemplateVehicleBuilder.server.luau` | One-time script to create the placeholder vehicle model |

### DMStarterPlayerScripts (StarterPlayerScripts)

| File | Purpose |
|------|---------|
| `init.client.luau` | Entry point LocalScript — requires all client modules |
| `ChassisClient.luau` | Simplified Polaris physics loop (suspension, drive force, steering) |
| `InputManager.luau` | Input abstraction (keyboard, gamepad stub, mobile stub) |
| `HubController.luau` | Hub UI management, Play queue toggle, camera control |
| `PreRoundController.luau` | Vehicle selection UI logic, countdown display |
| `DriverHUD.luau` | In-race HUD updates (placement, timer, leaderboard) |
| `EndRoundController.luau` | End-of-round leaderboard, Ready Up / Return to Hub |

### DMReplicatedStorage (ReplicatedStorage)

| File | Purpose |
|------|---------|
| `ChassisConfig.luau` | Simplified tuning values (spring, damping, grip, mass, gravity) |
| `ProfileService/` | MadStudios ProfileService module (DataStore abstraction) |

### DMStarterGui (StarterGui)

| File | Purpose |
|------|---------|
| `HubScreen.luau` | Hub menu UI (Play, Party Mode, Garage, Shop, Settings) + player list panel |
| `PreRoundScreen.luau` | Vehicle selection grid, 3D preview, Confirm button, countdown |
| `DriverHUDScreen.luau` | Placement, timer, leaderboard, power-up slot, ability hotbar |
| `EndRoundScreen.luau` | End-of-round leaderboard, Ready Up / Return to Hub buttons |

## Manual Requirements

- **TemplateVehicle** must exist in `ReplicatedStorage` (run `TemplateVehicleBuilder` or build manually)
- **Workspace.Gravity** should be set to `120`
