# Vehicle Damage Visuals — Specification

## Overview

Visual damage system that responds to BodyPanel `Health` attributes already present on every vehicle template. Damage is **server-authoritative** (Health values replicated via Attributes); visuals are **client-rendered** by reading those replicated values. No new RemoteEvents required.

---

## 1. Damage Stages

Every BodyPanel passes through three visual stages as its Health drops. Thresholds are expressed as fractions of `MaxHealth` so the system works uniformly across vehicles with different panel health values (e.g., Rhino panels at 200 HP vs Viper panels at 60 HP).

| Stage | Health Range          | Visual State |
|-------|-----------------------|--------------|
| **1 — Clean**   | 100 %–60 % of MaxHealth | Factory-fresh. No visual changes. |
| **2 — Damaged** | 59 %–20 % of MaxHealth  | Dented / cracked. Color shift, deformation, decals. |
| **3 — Destroyed** | 19 %–0 % of MaxHealth | Panel detaches and falls off (or shatters for Windshield). |

Stage transitions are one-way within a single round — panels do not heal mid-race.

---

## 2. Per-Panel Visual Specs

### 2.1 Hood

| Property | Stage 1 | Stage 2 | Stage 3 |
|----------|---------|---------|---------|
| Color | Original `bodyColor` | Darken 30 % (`Color3:Lerp(black, 0.3)`) | N/A (detached) |
| Size | Original | Y +0.15 studs (bulge), Z −0.3 studs (crumple) | Original (falling part) |
| Surface | SmoothPlastic | SmoothPlastic + `SurfaceGui` crack overlay | — |
| Extra | — | — | **Smoke:** `ParticleEmitter` on Chassis at hood offset. White-grey `#C8C8C8 → #606060`, Rate 20, Size 2–5 studs, Lifetime 1.5 s, Speed 3–6, SpreadAngle (25, 25). Emitter persists until round end. |

**Stage 3 detach sequence:**
1. Destroy `WeldConstraint` between Hood and Chassis.
2. Set `CanCollide = true`, `Anchored = false`.
3. Apply upward + random lateral impulse: `Vector3.new(math.random(-30, 30), 60, math.random(-30, 30))`.
4. After 3 seconds, fade part via Transparency tween (0 → 1, 1 s) then Destroy.

### 2.2 Windshield

| Property | Stage 1 | Stage 2 | Stage 3 |
|----------|---------|---------|---------|
| Color | Light blue `#96C8FF` | White-blue `#D0E8FF` (stress whitening) | N/A (shattered) |
| Transparency | 0.5 | 0.35 (more opaque from fractures) | — |
| Surface | Glass | Glass + `SurfaceGui` radial crack texture | — |
| Extra | — | Crack decal: white radial web pattern, opacity 0.7 | **Shatter burst:** 8–12 small glass shards (0.2–0.5 stud Parts, Glass material, light blue) scattered with random velocity. Each shard lives 2 s then fades + destroys. |

**Crack overlay implementation:**
- `SurfaceGui` on Face `Back` (interior-facing) with an `ImageLabel`.
- Image: radial crack pattern (white lines on transparent background).
- ImageTransparency lerps from 1 → 0.3 as Health drops through Stage 2 range.

**Stage 3 shatter sequence:**
1. Destroy `WeldConstraint`.
2. Create 8–12 shard Parts at windshield CFrame ± random offsets.
   - Size: `Vector3.new(rng(0.2,0.5), rng(0.2,0.5), 0.1)`
   - Color: `Color3.fromRGB(150, 200, 255)` (same as windshield)
   - Material: Glass, Transparency: 0.3
   - Apply random velocity in hemisphere forward of the windshield normal.
3. Destroy original Windshield part immediately.
4. Shards: tween Transparency 0.3 → 1 over 2 s, then Destroy.

### 2.3 Doors (LeftDoor / RightDoor)

| Property | Stage 1 | Stage 2 | Stage 3 |
|----------|---------|---------|---------|
| Color | Original `bodyColor` | Darken 25 % + slight hue shift toward brown (rust look) | N/A (detached) |
| Size | Original | X +0.1 studs (outward bulge on thin axis) | Original (falling part) |
| Surface | SmoothPlastic | SmoothPlastic + `SurfaceGui` dent/scratch decal on outer face | — |

**Stage 3 detach sequence:**
1. Destroy `WeldConstraint`.
2. Set `CanCollide = true`.
3. Apply outward impulse away from vehicle center: `doorSide * 40` + `Vector3.new(0, 30, 0)` + slight rearward component.
4. Apply random angular velocity via `BodyAngularVelocity` (spin while falling): `Vector3.new(rng(-3,3), rng(-3,3), rng(-3,3))`, MaxTorque 5000, lifetime 0.5 s.
5. After 3 s, fade + Destroy.

### 2.4 TrunkLid

| Property | Stage 1 | Stage 2 | Stage 3 |
|----------|---------|---------|---------|
| Color | Original `bodyColor` | Darken 20 % | N/A (detached) |
| Size | Original | Y +0.2 studs (popped up) | Original (falling part) |
| Extra | — | **Pop open:** Trunk CFrame offset shifts +1.5 studs Y and rotates −30° around X axis (hinged-open look). Achieved by tweening a new weld C1 offset over 0.3 s. | Same detach sequence as Hood (without smoke). |

### 2.5 Roof

| Property | Stage 1 | Stage 2 | Stage 3 |
|----------|---------|---------|---------|
| Color | Original `bodyColor` | Darken 15 % | Darken 40 % |
| Size | Original | Y scale ×0.6 (crush down) | Y scale ×0.3 (severely crushed) |
| Extra | — | CFrame offset shifts −0.2 studs Y (sinks toward cabin) | CFrame offset shifts −0.5 studs Y |

The Roof does **not** detach — it crushes in place. This is the only panel that stays attached at Stage 3. The visual crush is achieved by tweening `Size.Y` and `CFrame` offset simultaneously over 0.4 s.

### 2.6 Vehicle-Specific Panels

**Viper — Spoiler:**
- Follows the same 3-stage pattern as Hood.
- Stage 2: slight upward tilt (+10° X rotation via weld offset).
- Stage 3: detach + fly off rearward. No smoke.

**Rhino — BullBar:**
- Stage 2: color darkens, Size.Z −0.2 studs (pushed in).
- Stage 3: detach + falls forward and down. Impulse: `Vector3.new(0, 20, -50)`.
- BullBar has 300 HP — it should almost never reach Stage 3 in normal play.

---

## 3. Collision Damage Formula

### 3.1 Core Formula

```lua
local function calculateDamage(collisionVelocity: number, massRatio: number, damageResistance: number): number
    local BASE_MULTIPLIER = 0.5
    local rawDamage = collisionVelocity * massRatio * BASE_MULTIPLIER
    return rawDamage / damageResistance
end
```

| Parameter | Description |
|-----------|-------------|
| `collisionVelocity` | Relative velocity magnitude between the two colliding objects (studs/sec) |
| `massRatio` | `otherMass / selfMass` — heavier objects deal more damage to lighter ones |
| `damageResistance` | Per-vehicle multiplier from `DamageConfig` (higher = less damage taken) |

### 3.2 Per-Vehicle Damage Resistance

Derived from the `durability` stat (1–10 scale) already in `VehicleRegistry`:

```lua
local DamageConfig = {
    -- Resistance multiplier: higher = tougher
    -- Formula: 0.5 + (durability / 10) * 1.0
    all_rounder = {
        resistance = 1.1,    -- durability 6
        velocityThreshold = 25, -- ignore gentle bumps (studs/sec)
    },
    speedster = {
        resistance = 0.8,    -- durability 3 — fragile
        velocityThreshold = 15, -- even small hits matter
    },
    tank = {
        resistance = 1.4,    -- durability 9 — shrugs it off
        velocityThreshold = 35, -- needs a real hit to take damage
    },
}
```

### 3.3 Panel Selection

When a collision occurs, the damage system determines which panel takes the hit based on the collision contact normal relative to the vehicle's CFrame:

```lua
local PANEL_ZONES = {
    Hood      = { axis = "Z", direction = -1, priority = 1 }, -- front
    TrunkLid  = { axis = "Z", direction =  1, priority = 1 }, -- rear
    LeftDoor  = { axis = "X", direction = -1, priority = 2 }, -- left side
    RightDoor = { axis = "X", direction =  1, priority = 2 }, -- right side
    Roof      = { axis = "Y", direction =  1, priority = 3 }, -- top (rollovers)
    -- Windshield uses Hood zone — front impacts that overflow Hood go to Windshield
}
```

**Overflow logic:** If the primary panel for a zone is already destroyed (Stage 3 / health ≤ 0), remaining damage overflows to adjacent panels. Front overflow order: Hood → Windshield → Roof. Side overflow: Door → Roof. Rear: TrunkLid → Roof.

### 3.4 Environment Collision Damage

Collisions with static world geometry (barriers, rocks, walls) use a fixed `massRatio` of 2.0 (terrain is infinitely heavy relative to the car). The same velocity threshold and resistance apply.

---

## 4. Visual Feedback Effects

### 4.1 Screen Shake on Impact

Triggered on the **local client** when the player's own vehicle takes damage.

```lua
local ScreenShakeConfig = {
    minDamageForShake = 10,       -- damage units
    maxShakeIntensity = 1.5,      -- studs of camera offset
    shakeDuration = 0.3,          -- seconds
    shakeFrequency = 20,          -- oscillations per second
    -- Intensity scales linearly: intensity = clamp(damage / 50, 0.2, 1.0) * maxShakeIntensity
}
```

Implementation: Offset `Camera.CFrame` by a random XY vector each RenderStep for `shakeDuration` seconds. Magnitude decays linearly to zero. Restore original CFrame offset when done.

### 4.2 Panel Flash on Hit

Brief red tint on the damaged panel to give instant feedback on *which* panel was hit.

```lua
local PanelFlashConfig = {
    flashColor = Color3.fromRGB(255, 60, 60),
    flashDuration = 0.15,         -- seconds
    -- Sequence: instantly set panel Color to flashColor, tween back to current damage color over flashDuration
}
```

### 4.3 Smoke / Fire at Low Health

Engine smoke and fire particles tied to **total vehicle health** (sum of all panel Health / sum of all MaxHealth).

| Total Health % | Effect |
|----------------|--------|
| 40 %–20 % | Light grey smoke from Hood area. Rate 10, Size 1.5–3, Lifetime 1 s. |
| 19 %–1 % | Dense dark smoke + orange fire sparks. Smoke: Rate 25, Size 2–5, Color `#404040`. Fire: Rate 8, Size 0.3–0.8, Color `#FF6A00 → #FF2200`, Lifetime 0.4 s. |
| 0 % (all panels destroyed) | Heavy black smoke, no additional fire (vehicle is a wreck). Smoke: Rate 35, Color `#1A1A1A`, Size 3–7. |

Emitter parent: invisible Part welded to Chassis at Hood offset (same attachment used for Hood Stage 3 smoke).

### 4.4 Impact Sparks (Reuse from VFX Spec)

Metal-on-metal collisions already have spark VFX defined in `vfx-spec.md` Section 3. The damage system should trigger sparks alongside damage calculation — no separate implementation needed. The spark burst intensity should scale with damage dealt:

| Damage | Spark Count |
|--------|-------------|
| < 15 | 8–12 sparks (light scrape) |
| 15–40 | 15–25 sparks (solid hit) |
| > 40 | 25–35 sparks + brief PointLight flash |

---

## 5. Client-Side Damage Renderer

The entire visual system runs on the client by listening to Attribute changes on BodyPanel parts.

### 5.1 Architecture

```
Server                              Client
──────                              ──────
CollisionHandler                    DamageRenderer (per-vehicle)
  ├─ calculates damage              ├─ GetAttributeChangedSignal("Health")
  ├─ updates Health attribute       ├─ determines stage from Health/MaxHealth
  └─ (replicates via Attributes)    ├─ applies visual changes (color, size, decals)
                                    ├─ triggers detach/shatter sequences
                                    └─ manages smoke/fire emitters
```

### 5.2 Module Structure

```lua
-- DamageRenderer.luau (client module, ReplicatedStorage)
-- One instance created per spawned vehicle

local DamageRenderer = {}
DamageRenderer.__index = DamageRenderer

function DamageRenderer.new(vehicleModel: Model)
    local self = setmetatable({}, DamageRenderer)
    self.vehicle = vehicleModel
    self.vehicleId = vehicleModel:GetAttribute("VehicleId")
    self.panels = {} -- { [panelName] = { part, maxHealth, currentStage, connections } }
    self.smokeEmitter = nil
    self.fireEmitter = nil
    self:_init()
    return self
end

function DamageRenderer:_init()
    local bodyPanels = self.vehicle:FindFirstChild("BodyPanels")
    if not bodyPanels then return end

    for _, panel in bodyPanels:GetChildren() do
        if panel:IsA("BasePart") and panel:GetAttribute("MaxHealth") then
            local entry = {
                part = panel,
                maxHealth = panel:GetAttribute("MaxHealth"),
                currentStage = 1,
                originalColor = panel.Color,
                originalSize = panel.Size,
                originalCFrame = panel.CFrame,
                connections = {},
            }
            self.panels[panel.Name] = entry

            entry.connections.health = panel:GetAttributeChangedSignal("Health"):Connect(function()
                self:_onHealthChanged(panel.Name)
            end)
        end
    end
end

function DamageRenderer:_getStage(health: number, maxHealth: number): number
    local pct = health / maxHealth
    if pct > 0.6 then return 1 end
    if pct > 0.2 then return 2 end
    return 3
end

function DamageRenderer:_onHealthChanged(panelName: string)
    local entry = self.panels[panelName]
    if not entry then return end

    local health = entry.part:GetAttribute("Health")
    local newStage = self:_getStage(health, entry.maxHealth)
    if newStage == entry.currentStage then return end

    local oldStage = entry.currentStage
    entry.currentStage = newStage

    if newStage == 2 then
        self:_applyDamaged(panelName, entry)
    elseif newStage == 3 then
        self:_applyDestroyed(panelName, entry)
    end

    self:_updateVehicleSmoke()
end

function DamageRenderer:destroy()
    for _, entry in self.panels do
        for _, conn in entry.connections do
            conn:Disconnect()
        end
    end
    if self.smokeEmitter then self.smokeEmitter:Destroy() end
    if self.fireEmitter then self.fireEmitter:Destroy() end
end
```

### 5.3 Server-Side Damage Handler (Skeleton)

```lua
-- CollisionDamageHandler.server.luau (ServerScriptService)

local function onVehicleCollision(vehicle: Model, otherPart: BasePart, contactPoint: Vector3, relativeVelocity: Vector3)
    local vehicleId = vehicle:GetAttribute("VehicleId")
    local config = DamageConfig[vehicleId]
    if not config then return end

    local speed = relativeVelocity.Magnitude
    if speed < config.velocityThreshold then return end

    local selfMass = vehicle.Body.Chassis:GetMass()
    local otherMass
    if otherPart:IsA("Terrain") or otherPart.Anchored then
        otherMass = selfMass * 2 -- environment collision
    else
        otherMass = otherPart.AssemblyMass
    end

    local massRatio = otherMass / selfMass
    local damage = calculateDamage(speed, massRatio, config.resistance)

    local panelName = getPanelFromContactNormal(vehicle, contactPoint, relativeVelocity)
    local panel = vehicle.BodyPanels:FindFirstChild(panelName)
    if not panel then return end

    local currentHealth = panel:GetAttribute("Health")
    local newHealth = math.max(0, currentHealth - damage)
    panel:SetAttribute("Health", newHealth)

    -- Overflow: if panel destroyed and leftover damage, apply to next panel
    if newHealth == 0 then
        local overflow = damage - currentHealth
        if overflow > 0 then
            applyOverflowDamage(vehicle, panelName, overflow)
        end
    end
end
```

---

## 6. Tween & Timing Reference

All visual transitions use `TweenService` for smooth interpolation.

| Transition | Duration | EasingStyle | EasingDirection |
|------------|----------|-------------|-----------------|
| Color darken (Stage 1→2) | 0.3 s | Quad | Out |
| Size deform (Stage 1→2) | 0.4 s | Back | Out |
| Trunk pop open (Stage 2) | 0.3 s | Bounce | Out |
| Roof crush (Stage 2) | 0.4 s | Quad | InOut |
| Roof crush (Stage 3) | 0.3 s | Quad | In |
| Panel flash (hit feedback) | 0.15 s | Linear | — |
| Detached panel fade-out | 1.0 s | Linear | — |
| Windshield shatter shard fade | 2.0 s | Quad | In |
| Screen shake decay | 0.3 s | Quad | Out |
| Smoke ramp-up | 0.5 s (rate tween) | Linear | — |

---

## 7. Performance Budget

| Constraint | Limit | Rationale |
|------------|-------|-----------|
| Max active particle emitters per vehicle | 3 (smoke, fire, hood smoke) | ParticleEmitters are one of the heavier client-side systems |
| Max detached panels in world | 12 (across all vehicles) | Old panels Destroyed before new ones spawn if at limit |
| Windshield shard count | 8–12 per shatter | Small count keeps Part creation bounded |
| SurfaceGui crack decals | 1 per panel max | Minimal overhead |
| Screen shake: max concurrent | 1 (newest replaces oldest) | Prevents stacking jitter |
| Damage check cooldown per vehicle | 0.1 s | Prevents collision spam from multiple Touched events per frame |

---

## 8. Integration Checklist

1. **Server:** Create `CollisionDamageHandler.server.luau` in `ServerScriptService`
   - Listen for `Touched` events on each vehicle's `CollisionShell`
   - Apply damage formula, update `Health` attributes
   - 0.1 s cooldown per vehicle to debounce rapid collisions

2. **Client:** Create `DamageRenderer.luau` in `ReplicatedStorage`
   - Instantiate per spawned vehicle in `ChassisClient` or a dedicated `DamageClient`
   - Listen to `GetAttributeChangedSignal("Health")` on all BodyPanel parts
   - Apply visual stage transitions

3. **Assets needed:** None — all visuals use programmatic color shifts, size tweens, and built-in `ParticleEmitter` / `SurfaceGui`. Crack textures can use Roblox's built-in decal library or a simple procedurally-generated `EditableImage` pattern.

4. **VehicleRegistry changes:** None — `durability` stat and panel `health` values are already defined.

5. **DownhillConfig changes:** None — damage system is independent of chassis physics.
