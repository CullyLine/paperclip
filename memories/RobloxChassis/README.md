# Polaris Chassis — State-of-the-Art ROBLOX Vehicle Chassis

A pure raycast suspension vehicle chassis system for Roblox, built from scratch with no constraints, no springs, no rope — just math, raycasts, and impulse forces.

## Architecture

```
TestVehicle (Model)
├── Body (Model, PrimaryPart = Chassis)
│     ├── Chassis (Part — main rigid body)
│     ├── Hood, Trunk, Roof, Windshield, etc.
│     └── CenterOfMass (invisible weighted part)
├── Wheels (Model)
│     ├── WheelFL (Part, cylinder — visually positioned each frame)
│     ├── WheelFR
│     ├── WheelRL
│     └── WheelRR
├── DriverSeat (VehicleSeat)
├── LiveValues (Configuration — ValueBase objects for hot-tuning)
├── ChassisConfig (ModuleScript — single source of truth)
├── LiveValuesSync (ModuleScript — bridges LiveValues ↔ config)
├── Drivetrain (ModuleScript — gears, RPM, torque curves)
├── ChassisController (Script — server-side physics + seat management)
└── ChassisClient (LocalScript — client-side physics for responsiveness)
    └── DriverHUD (ModuleScript — speedometer, RPM, gear display)
```

## How It Works

### Raycast Suspension

Each wheel casts a ray downward from the chassis. The hit distance determines spring compression. Forces are applied using a spring-damper model:

```
F = (stiffness × compression) + (damping × velocity)
```

- **Asymmetric damping**: compression and rebound have separate coefficients
- **Anti-roll bars**: left/right wheel pairs are coupled to resist body roll
- **Force direction**: always along the chassis up vector (correct on slopes)

### Drivetrain

- 1-8 configurable gear ratios with automatic shifting at RPM thresholds
- RPM derived from wheel angular velocity × gear ratio × final drive
- Torque curve peaks at ~60% of redline, falls off toward the limiter
- Shift cooldown prevents gear hunting
- Reverse gear with separate ratio

### Tire Model

Simplified Pacejka-inspired lateral grip curve:
- Slip angle calculated from lateral/longitudinal wheel velocity
- Grip force follows a sine curve peaking at the configured slip angle
- Separate lateral and longitudinal grip multipliers for tuning

### Client-Authoritative Physics

When a player sits down:
1. Server transfers network ownership to the player
2. Client runs the full physics loop (zero input latency)
3. Drivetrain state is broadcast back for other clients
4. When the player exits, server reclaims ownership

## Configuration

All tuning lives in `ChassisConfig.luau`. Key parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `springStiffness` | 85 | Suspension spring rate |
| `dampingCompression` | 4.5 | Damping on compression stroke |
| `dampingRebound` | 5.5 | Damping on rebound stroke |
| `antiRollStiffness` | 30 | Anti-roll bar stiffness |
| `suspensionRestLength` | 1.8 | Neutral suspension length |
| `maxSteerAngle` | 35° | Maximum wheel turn angle |
| `maxTorque` | 450 | Peak engine torque |
| `brakeTorque` | 600 | Braking force |
| `gearRatios` | [3.636...0.553] | Up to 8 gear ratios |
| `activeGearCount` | 6 | How many gears to use (1-8) |
| `tireFrictionCoefficient` | 1.6 | Grip coefficient |
| `maxSpeedStudsPerSec` | 300 | Speed limiter |
| `downforceCoefficient` | 0.3 | Speed-squared downforce |
| `dragCoefficient` | 0.02 | Aerodynamic drag |

## LiveValues (Real-Time Tuning)

The `LiveValues` Configuration container holds ValueBase objects that map 1:1 to config keys. Change any value and the chassis responds **instantly**:

```lua
-- From any script:
local liveValues = workspace.TestVehicle.LiveValues
liveValues.SpringStiffness.Value = 120  -- stiffer suspension, immediate effect
liveValues.MaxTorque.Value = 600        -- more power, immediate effect
liveValues.ActiveGearCount.Value = 4    -- limit to 4 gears, immediate effect
```

### Drive Modes (via ExternalTuner)

The ExternalTuner module provides preset modes:

```lua
local Tuner = require(path.to.ExternalTuner)
Tuner.setDriveMode("comfort")  -- soft, floaty
Tuner.setDriveMode("sport")    -- stiff, responsive
Tuner.setDriveMode("drift")    -- low grip, high torque
```

## Driver HUD

Appears when the player sits in the DriverSeat, disappears on exit:

- **RPM gauge** — circular with needle, redline zone highlighted
- **Speedometer** — circular with needle, MPH readout
- **Gear display** — current gear number (or "R" for reverse)
- **Speed readout** — numeric MPH value

## Setup in Roblox Studio

### One-File Import (Recommended)

The entire chassis is packaged as a single file: **`PolarisChassis.rbxmx`**

1. Open **Roblox Studio** and create or open a place
2. Make sure you have a **Baseplate** or some ground for the car to sit on
3. Go to **File → Insert from File** (or drag-and-drop the file into the viewport)
4. Select `PolarisChassis.rbxmx`
5. The `PolarisVehicle` model appears in **Workspace** — that's it

**Where things end up after import:**

```
Workspace
└── PolarisVehicle          ← The imported model (goes directly into Workspace)
    ├── Body                ← Car body geometry (welded together at runtime)
    ├── Wheels              ← 4 wheel parts (positioned by physics each frame)
    ├── DriverSeat          ← Sit here to drive (WASD / arrow keys)
    ├── ChassisConfig       ← ModuleScript: all tuning values
    ├── Drivetrain          ← ModuleScript: gears & RPM
    ├── LiveValuesSync      ← ModuleScript: hot-tuning bridge
    ├── ChassisController   ← Script: runs on server, manages physics & seat
    ├── ExternalTuner       ← ModuleScript: drive mode API (comfort/sport/drift)
    └── ChassisClient       ← LocalScript: client-side physics (runs on driver)
        └── DriverHUD       ← ModuleScript: speedometer, RPM gauge, gear display
```

6. Move the `ChassisClient` LocalScript to **StarterPlayerScripts** (drag it there in Explorer)
   - This is required so the client script runs on every player who joins
   - The DriverHUD module goes with it (it's a child of ChassisClient)
7. Press **Play** — walk up to the car and sit in the DriverSeat

**Important:** The `ChassisClient` LocalScript must be in `StarterPlayerScripts` (or `StarterGui` / `ReplicatedFirst`), NOT inside the vehicle model. Everything else stays in the model.

### Where Each Script Type Must Live

| Script | Type | Location | Why |
|--------|------|----------|-----|
| ChassisController | Script (Server) | Inside PolarisVehicle model | Runs on server, manages the vehicle |
| ChassisConfig | ModuleScript | Inside PolarisVehicle model | Required by both server and client scripts |
| Drivetrain | ModuleScript | Inside PolarisVehicle model | Required by both server and client scripts |
| LiveValuesSync | ModuleScript | Inside PolarisVehicle model | Required by both server and client scripts |
| ExternalTuner | ModuleScript | Inside PolarisVehicle model | Optional API for drive modes |
| **ChassisClient** | **LocalScript** | **StarterPlayerScripts** | **Must run on the client** |
| DriverHUD | ModuleScript | Child of ChassisClient | Loaded by ChassisClient via require() |

### Manual Setup (from individual .luau files)

If you prefer to set things up from the raw source files in `src/`:

1. Create a **Model** in Workspace with the vehicle structure (Body, Wheels, DriverSeat)
2. Add `ChassisConfig`, `Drivetrain`, `LiveValuesSync`, and `ExternalTuner` as **ModuleScripts** inside the model
3. Add `ChassisController` as a **Script** inside the model
4. Add `ChassisClient` as a **LocalScript** in **StarterPlayerScripts**
5. Add `DriverHUD` as a **ModuleScript** child of ChassisClient
6. Ensure wheel Part names match the `wheels` table in ChassisConfig (WheelFL, WheelFR, WheelRL, WheelRR)

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Car falls through the ground | Make sure there's a Baseplate or ground part under the vehicle |
| Car doesn't move when pressing W | Check that `ChassisClient` is in StarterPlayerScripts, not inside the model |
| No HUD appears | DriverHUD must be a child of ChassisClient |
| Wheels don't appear | Wheel parts must be named exactly WheelFL, WheelFR, WheelRL, WheelRR |
| Car flips over immediately | The Body model needs a PrimaryPart set (should be the Chassis part) |

## Design Decisions

### Why raycast instead of constraints?

- **Full control**: every force is calculated and applied explicitly
- **No fighting the engine**: constraint-based systems often fight Roblox's solver
- **Predictable tuning**: spring-damper math is well-understood and deterministic
- **Performance**: raycasts are cheaper than constraint evaluation chains
- **Flexibility**: same system works for cars, trucks, hovercrafts, motorcycles

### Why client-authoritative?

- **Zero input latency**: the player's inputs affect physics on the same frame
- **Smooth feel**: no network round-trip between pressing W and the car moving
- **Standard practice**: every major Roblox driving game does this

### Why asymmetric damping?

Real suspension has different compression and rebound rates. Stiffer rebound prevents the car from bouncing after hitting bumps. Softer compression absorbs impacts smoothly.

### Research References

- **A-Chassis / AG-Chassis**: industry-standard Roblox chassis, constraint-based. Good for simplicity but limited tunability and prone to solver instability at high speeds.
- **MotorVehicle by Lain**: lightweight library approach, evolving toward raycast. Inspired our modular config-driven architecture.
- **BeamNG.drive**: node-beam soft-body physics, spring+damper values on every structural member. Inspired our asymmetric damping and torque curve modeling.
- **Gaffer on Games (Spring Physics)**: canonical reference for stable spring-damper integration in game loops.
- **Pacejka tire model**: simplified sine-curve lateral grip replaces the full Magic Formula while keeping the characteristic slip-angle behavior.
