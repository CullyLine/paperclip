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
  VisualWheels (Folder) ........ server-created, replicated to all clients
    WheelFL_Visual (Part) ..... Anchored, positioned by owning client + server relay
    WheelFR_Visual (Part)
    WheelRL_Visual (Part)
    WheelRR_Visual (Part)
  DriverSeat (Seat) ........... plain Seat (not VehicleSeat — avoids built-in forces)
```

### Chassis System

- **Raycast suspension** — no spring constraints. Rays fire downward from each wheel mount point; spring-damper forces computed in `DownhillPhysics.suspension()`.
- **Client-driven physics** — all forces applied on the client via `Heartbeat`. Server only spawns/anchors/teleports.
- **AWD flat drive model** — no gears, no RPM, no drivetrain. Simple force applied to all 4 wheels.
- **Visual wheels** — `Anchored=true` parts created by the server inside a `VisualWheels` folder in the vehicle model (replicated to all clients). The owning client positions them locally every Heartbeat for zero-lag feel and sends CFrame updates at ~10 Hz via the `WheelReplication` RemoteEvent. The server relays positions to all other clients via standard Roblox replication. No welds, no constraints, no physics fighting = zero jitter for the driver, smooth interpolated wheels for spectators.
- **Anti-roll bars** — front and rear axle anti-roll to reduce body roll in corners.
- **Surface friction** — per-material friction multipliers (ice=0.08, grass=0.5, asphalt=1.0, etc).
- **Airborne control** — yaw/pitch torques when all wheels are off ground.
- **Downforce + drag** — speed-dependent aerodynamic forces.
- **Counter-steer assist** — automatic slide correction for controllable drifting.
- **Vehicle destruction watcher** — auto-cleanup via `AncestryChanged` when the server destroys the vehicle between rounds.
- **Collision damage system** — detects impacts via Touched on CollisionShell + velocity-delta detection. Calculates damage based on impact speed, applies to nearest BodyPanel(s). Panels darken as health decreases, detach at 0 HP (unanchor + impulse + fade-destroy). Windshield shatters into glass fragments. Losing panels increases drag and reduces max speed; below 20% total health = "wrecked" state with heavy penalties. Owning client drives damage calculation; server validates and broadcasts to others.
- **Custom chase camera** — smooth follow behind vehicle with velocity look-ahead, speed-dependent FOV (70→85), impact shake on deceleration, rear-view (hold C / mobile button), and right-click free-look orbit. Activates automatically when driving starts, deactivates on stop.

### Design Decisions

| Decision | Rationale |
|----------|-----------|
| Plain `Seat` instead of `VehicleSeat` | VehicleSeat applies its own driving forces that conflict with custom physics |
| `Chassis.CanCollide = false` | CollisionShell handles collisions; chassis is physics root only |
| Invisible template wheels + server-replicated visual wheels | Avoids wheel jitter; owning client drives locally, server relays to others via WheelReplication RemoteEvent |
| Flat drive force (no gears/RPM) | Simpler, more predictable, less to break |
| `CenterOfMass` part with high density | Lowers effective center of mass for stability without changing chassis size |
| Damage-ready `BodyPanels` with Health attributes | Destruction system detaches/destroys individual panels based on collision damage |

## File Reference

### DMServerScriptService (ServerScriptService)

| File | Purpose |
|------|---------|
| `MapBuilder.luau` | ModuleScript — `build()` generates the hill map, `cleanup()` destroys it and restores Hub lighting |
| `MatchManager.server.luau` | Server-local queue system, game loop state machine (idle → pre_round → racing → results) |
| `RoundController.server.luau` | 3-2-1-GO countdown, 120s race timer, progress tracking, finish detection. Calls VehicleSpawner |
| `PreRoundServer.server.luau` | Server-side vehicle selection (exclusivity, random assignment) |
| `VehicleSpawner.luau` | Clones TemplateVehicle, places at spawn points, manages vehicle lifecycle. API: `spawnVehicles`, `lockAll`, `unlockAll`, `cleanup`, `teleportVehicle`, `anchorVehicle`, `resetVehicle`, `getVehicleForPlayer`, `getActiveVehicles` |
| `ProfileManager.server.luau` | ProfileService wrapper — handles player data (load/save/get/set), input settings persistence via GetInputSettings/SetInputSettings RemoteFunctions |
| `TemplateVehicleBuilder.server.luau` | Runs once at server start — builds the modular damage-ready TemplateVehicle in ReplicatedStorage (see Vehicle Hierarchy above) |
| `WheelReplication.server.luau` | Receives visual-wheel CFrame updates from owning clients (~10 Hz) and writes them to replicated VisualWheels parts inside the vehicle model. Rate-limited server-side at ~12 Hz per player |
| `DamageReplication.server.luau` | Receives damage reports from owning clients, validates them, applies health to authoritative model, broadcasts to other clients. Handles panel detach (unanchor + impulse + fade destroy) and windshield shatter (glass shard particles). Rate-limited at ~15 Hz per player |

### DMStarterPlayerScripts (StarterPlayerScripts)

| File | Purpose |
|------|---------|
| `Bootstrap.client.luau` | Entry point LocalScript — requires all client modules |
| `ChassisClient.luau` | Client-side raycast chassis. Detects seat entry, runs suspension + drive physics on Heartbeat, creates/positions visual wheels, auto-cleans up on vehicle destruction or unseat. Exports driving state API for CameraController. Uses `DownhillConfig` + `DownhillPhysics` |
| `CameraController.luau` | Custom chase camera — smooth follow with velocity look-ahead, speed-dependent FOV (70→85), impact shake, rear-view (C key / mobile button), right-click free-look orbit. Auto-activates/deactivates with driving state |
| `InputManager.luau` | Input abstraction — keyboard, mobile touch controls (auto-detected), gamepad (sticks + triggers). Mobile supports 3 steering modes (buttons/joystick/tilt), adjustable sensitivity/opacity/scale, auto-gas toggle. Settings loaded from ProfileManager on drive start |
| `HubController.luau` | Hub UI management, Play queue toggle, camera control |
| `PreRoundController.luau` | Vehicle selection UI logic, countdown display |
| `DriverHUD.luau` | In-race HUD updates (placement, timer, leaderboard) |
| `EndRoundController.luau` | End-of-round leaderboard, Ready Up / Return to Hub |

### DMReplicatedStorage (ReplicatedStorage)

| File | Status | Purpose |
|------|--------|---------|
| `DownhillConfig.luau` | **Active** | Flat tuning table for the chassis — suspension, steering, drive force, traction, surface friction, aero, air control, gravity, damage thresholds |
| `DownhillPhysics.luau` | **Active** | Pure computation functions — suspension spring-damper, anti-roll, lateral grip (tire model), steering, airborne torques, downforce, drag, angular damping |
| `DamageSystem.luau` | **Active** | Shared damage calculations — impact damage from velocity, nearest-panel lookup, health tracking, damage tint, wrecked state detection, handling penalty computation, server-side validation |
| `ProgressionSystem.luau` | **Active** | XP calculation (placement, distance, destruction, clean driving, style points), Scrap earning tables, level-up rewards, daily login rewards, vehicle unlock checks, trick detection thresholds |
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

## Mobile Input Settings

The `InputManager` supports configurable mobile controls via the `settings` table (persisted in ProfileManager):

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `steerMode` | string | `"buttons"` | `"buttons"` (L/R arrows), `"joystick"` (virtual analog stick), or `"tilt"` (accelerometer) |
| `steerSensitivity` | number | `1.0` | Steering responsiveness multiplier (0.5–2.0) |
| `buttonOpacity` | number | `0.7` | Touch button visibility (0.0–1.0) |
| `buttonScale` | number | `1.0` | Touch button size multiplier (0.5–2.0) |
| `autoGas` | boolean | `false` | Always-on throttle (hides GAS button, shows AUTO indicator) |
| `tiltDeadzone` | number | `0.08` | Ignore accelerometer tilt below this threshold |

Settings are loaded from the server via `GetInputSettings` RemoteFunction when driving starts, and saved via `SetInputSettings`.

## Progression System

### XP Earning (per race)

| Source | Amount |
|--------|--------|
| Race Finish | 50 XP base |
| 1st Place | +100 XP |
| 2nd Place | +60 XP |
| 3rd Place | +30 XP |
| Distance Traveled | 1 XP per 100 studs |
| Destruction (panels) | 5 XP per panel knocked off opponents |
| Clean Driving | +25 XP (no panel damage taken) |
| Style Points | 5 XP per trick (airtime >1.5s, drift >2s, near-miss <5 studs) |

### XP-to-Level Curve

`XP_required(level) = 100 + (level - 1) * 50`

Level-up grants Scrap bonus: `50 + (newLevel - 1) * 25` Scrap.

### Scrap (Currency)

Earned per race by placement:
- 1st: 100, 2nd: 75, 3rd: 50, 4th-6th: 30, DNF: 15

### Vehicle Unlock Gating

Vehicles require BOTH level AND Scrap cost:
- **Nomad** (all_rounder): Level 0, 0 Scrap (free starter)
- **Viper** (speedster): Level 5, 500 Scrap
- **Rhino** (tank): Level 10, 1,200 Scrap

Players can purchase during PreRound vehicle selection once they meet the level requirement.

### Daily Login Rewards

7-day cycle (Scrap): 25, 50, 50, 75, 100, 100, 200. Wraps after Day 7. Processed on PlayerAdded via `ProfileManager.ProcessDailyLogin()`.

### Profile Data Fields

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `scrap` | number | 0 | Earned currency |
| `xp` | number | 0 | Current XP within level |
| `level` | number | 1 | Player level |
| `totalXp` | number | 0 | Lifetime XP earned |
| `unlockedVehicles` | { string } | { "all_rounder" } | Purchased/unlocked vehicle IDs |
| `equippedCosmetics` | table | {} | Paint, wheels, trail, plate, horn, wrap |
| `activeBoosts` | array | {} | { type, racesRemaining } |
| `dailyLoginDay` | number | 0 | Current day in 7-day cycle |
| `lastLoginDate` | string | "" | ISO date string for dedup |
| `gamePasses` | table | {} | Purchased game passes |

### Key Modules

| Module | Location | Purpose |
|--------|----------|---------|
| `ProgressionSystem.luau` | DMReplicatedStorage | XP calc, scrap calc, level-up rewards, daily login tables, vehicle unlock checks, trick thresholds |
| `ProfileManager.server.luau` | DMServerScriptService | Profile persistence, AwardXP, AwardScrap, PurchaseVehicle, ProcessDailyLogin |

### RemoteEvents / RemoteFunctions

| Name | Type | Direction | Purpose |
|------|------|-----------|---------|
| `GetProgression` | RemoteFunction | Client→Server | Returns level, xp, xpNeeded, scrap |
| `PurchaseVehicle` | RemoteFunction | Client→Server | Purchase a vehicle (validates level+scrap) |
| `XPAward` | RemoteEvent | Server→Client | Post-race XP+Scrap breakdown |
| `DailyLoginReward` | RemoteEvent | Server→Client | Daily login reward notification |

## Known Limitations / Future Work

- **Settings UI** — mobile input settings need an in-game settings panel (currently only settable via code/API)
- **Damage VFX** — particle effects for sparks/smoke on impact not yet implemented
- **Damage HUD** — no on-screen damage indicator or vehicle health bar yet
- **Style Points** — airtime/drift/near-miss trick detection runs client-side but is not yet wired to RoundController (tracked as 0 for now; needs client→server reporting)
- **Boost system** — `activeBoosts` field is stored but boost activation/consumption not yet implemented
- **Cosmetics** — `equippedCosmetics` field is stored but cosmetic application not yet implemented
- **Game Passes** — `gamePasses` field is stored but no passes are defined yet
