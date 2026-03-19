# Downhill Madness — M0 Design Doc & Setup Guide

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

4. **TemplateVehicle** is auto-created in `ReplicatedStorage` by `TemplateVehicleBuilder.server.luau` on server start. No manual setup needed.

5. **Gravity** is set to `120` at runtime by `ChassisClient.luau` when a player enters a vehicle (restored on exit).

6. **Playtest**: Hit Play. Hub UI appears (skybox + menu). Click **Play** to queue for a round. The map builds automatically when the round starts and cleans up when it ends.

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

## Vehicle Architecture

The vehicle uses a **modular, damage-ready** structure with client-driven raycast suspension.

### Vehicle Hierarchy (TemplateVehicle)

```
TemplateVehicle (Model, PrimaryPart = Chassis)
  Body (Model, PrimaryPart = Chassis)
    Chassis (Part) ............ physics root, low density, CanCollide=false
    CenterOfMass (Part) ....... dense invisible mass anchor, lowers effective CoM
    CollisionShell (Part) ..... invisible collision box, massless, CanCollide=true
  BodyPanels (Model) .......... modular parts for future damage/destruction
    Hood (Part)               — Health attribute (100)
    TrunkLid (Part)           — Health attribute (100)
    LeftDoor (Part)           — Health attribute (100)
    RightDoor (Part)          — Health attribute (100)
    Roof (Part)               — Health attribute (100)
    Windshield (Part, Glass)  — Health attribute (50)
  Wheels (Model)
    WheelFL (Part, Cylinder) .. invisible physics marker, welded to Chassis
    WheelFR (Part, Cylinder) .. invisible physics marker, welded to Chassis
    WheelRL (Part, Cylinder) .. invisible physics marker, welded to Chassis
    WheelRR (Part, Cylinder) .. invisible physics marker, welded to Chassis
  DriverSeat (Seat) ........... plain Seat (not VehicleSeat — avoids built-in forces)
```

### Chassis System

- **Raycast suspension** — no spring constraints. Rays fire downward from each wheel mount point; spring-damper forces computed in `DownhillPhysics.suspension()`.
- **Client-driven physics** — all forces applied on the client via `Heartbeat`. Server only spawns/anchors/teleports.
- **AWD flat drive model** — no gears, no RPM, no drivetrain. Simple force applied to all 4 wheels.
- **Visual wheels** — separate `Anchored=true` parts created by the client, living outside the vehicle assembly in a workspace Folder. Positioned at end of each Heartbeat frame using a fresh `root.CFrame` read. No welds, no constraints, no physics fighting = zero jitter, zero lag.
- **Anti-roll bars** — front and rear axle anti-roll to reduce body roll in corners.
- **Surface friction** — per-material friction multipliers (ice=0.08, grass=0.5, asphalt=1.0, etc).
- **Airborne control** — yaw/pitch torques when all wheels are off ground.
- **Downforce + drag** — speed-dependent aerodynamic forces.
- **Counter-steer assist** — automatic slide correction for controllable drifting.
- **Vehicle destruction watcher** — auto-cleanup via `AncestryChanged` when the server destroys the vehicle between rounds.

### Design Decisions

| Decision | Rationale |
|----------|-----------|
| Plain `Seat` instead of `VehicleSeat` | VehicleSeat applies its own driving forces that conflict with custom physics |
| `Chassis.CanCollide = false` | CollisionShell handles collisions; chassis is physics root only |
| Invisible template wheels + client visual wheels | Avoids the classic "wheel jitter" from setting CFrame on welded parts |
| Flat drive force (no gears/RPM) | Simpler, more predictable, less to break |
| `CenterOfMass` part with high density | Lowers effective center of mass for stability without changing chassis size |
| Damage-ready `BodyPanels` with Health attributes | Future destruction system can detach/destroy individual panels |

## File Reference

### DMServerScriptService (ServerScriptService)

| File | Purpose |
|------|---------|
| `MapBuilder.luau` | ModuleScript — `build()` generates the hill map, `cleanup()` destroys it and restores Hub lighting |
| `MatchManager.server.luau` | Server-local queue system, game loop state machine (idle → pre_round → racing → results) |
| `RoundController.server.luau` | 3-2-1-GO countdown, 120s race timer, progress tracking, finish detection. Calls VehicleSpawner |
| `PreRoundServer.server.luau` | Server-side vehicle selection (exclusivity, random assignment) |
| `VehicleSpawner.luau` | Clones TemplateVehicle, places at spawn points, manages vehicle lifecycle. API: `spawnVehicles`, `lockAll`, `unlockAll`, `cleanup`, `teleportVehicle`, `anchorVehicle`, `resetVehicle`, `getVehicleForPlayer`, `getActiveVehicles` |
| `ProfileManager.server.luau` | ProfileService wrapper — handles player data (load/save/get/set) |
| `TemplateVehicleBuilder.server.luau` | Runs once at server start — builds the modular damage-ready TemplateVehicle in ReplicatedStorage (see Vehicle Hierarchy above) |

### DMStarterPlayerScripts (StarterPlayerScripts)

| File | Purpose |
|------|---------|
| `Bootstrap.client.luau` | Entry point LocalScript — requires all client modules |
| `ChassisClient.luau` | Client-side raycast chassis. Detects seat entry, runs suspension + drive physics on Heartbeat, creates/positions visual wheels, auto-cleans up on vehicle destruction or unseat. Uses `DownhillConfig` + `DownhillPhysics` |
| `InputManager.luau` | Input abstraction — keyboard, mobile touch controls (auto-detected), gamepad (sticks + triggers). Touch controls appear only while driving and are destroyed on exit |
| `HubController.luau` | Hub UI management, Play queue toggle, camera control |
| `PreRoundController.luau` | Vehicle selection UI logic, countdown display |
| `DriverHUD.luau` | In-race HUD updates (placement, timer, leaderboard) |
| `EndRoundController.luau` | End-of-round leaderboard, Ready Up / Return to Hub |

### DMReplicatedStorage (ReplicatedStorage)

| File | Status | Purpose |
|------|--------|---------|
| `DownhillConfig.luau` | **Active** | Flat tuning table for the chassis — suspension, steering, drive force, traction, surface friction, aero, air control, gravity |
| `DownhillPhysics.luau` | **Active** | Pure computation functions — suspension spring-damper, anti-roll, lateral grip (tire model), steering, airborne torques, downforce, drag, angular damping |
| `ChassisConfig.luau` | ⚠️ Deprecated | Original Polaris-based tuning config. Not used — kept as reference |
| `ChassisPhysics.luau` | ⚠️ Deprecated | Original Polaris physics functions. Not used — kept as reference |
| `Drivetrain.luau` | ⚠️ Deprecated | Original gear shifting / RPM simulation. Not used — flat force model replaced it |
| `LiveValuesSync.luau` | ⚠️ Deprecated | Original live-tuning bridge for ValueBase instances. Not used — flat config table replaced it |
| `ProfileService/` | **Active** | MadStudios ProfileService module (DataStore abstraction) |

### DMStarterGui (StarterGui)

| File | Purpose |
|------|---------|
| `HubScreen.luau` | Hub menu UI (Play, Party Mode, Garage, Shop, Settings) + player list panel |
| `PreRoundScreen.luau` | Vehicle selection grid, 3D preview, Confirm button, countdown |
| `DriverHUDScreen.luau` | Placement, timer, leaderboard, power-up slot, ability hotbar |
| `EndRoundScreen.luau` | End-of-round leaderboard, Ready Up / Return to Hub buttons |

## Debug

`ChassisClient.luau` has a built-in debug mode (`DEBUG_ENABLED = true` near the top). When active it prints to Output every 0.5s:

- Root position, velocity, speed, mass, gravity, steer angle
- Per-wheel: grounded state, hit distance, spring length, suspension force
- Per-wheel: mount point (world), logical position, visual position, delta between them
- Grounded count

Set `DEBUG_ENABLED = false` to silence.

## Known Limitations / Future Work

- **Destruction system** — BodyPanels have Health attributes but no damage/detachment logic yet
- **Multiple vehicle types** — only one TemplateVehicle; future: different body shapes with different stats
- **Multiplayer visual wheels** — visual wheels are local to each client; other players' wheel visuals need a replication solution
- **Mobile input refinement** — touch controls work but could benefit from sensitivity tuning, opacity settings, or a virtual joystick option
