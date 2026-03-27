# DAC — template models (Studio)

Names must match **config helpers** (defaults to the data `id` unless `modelName` is set on that entry).

| Location | Lookup | Config |
|----------|--------|--------|
| `ReplicatedStorage.PetModels` | `PetConfig.getPetTemplateName(petId)` | `PetConfig.luau` — `listPetIds()` |
| `ReplicatedStorage.EggModels` | `EggConfig.getEggTemplateName(eggId)` | `EggConfig.luau` — `listEggIds()` |
| `ServerStorage.CarModels` | `CarConfig.getCarTemplateName(carId)` | `CarConfig.luau` — `listCarIds()` |

| `ReplicatedStorage.Images` | Browse by child name; each is a Decal or ImageLabel with `rbxassetid://` set | `Images/MANIFEST.md` |

**Runtime wiring**

- **Pets:** `PetController` clones equipped pets into `Workspace.ActivePets` (synced from `DataUpdate`).
- **Cars:** `RunService` clones the equipped car into `Player.Character` as **`Car`** when a run starts (anchored, non-colliding for client `PivotTo`).
- **Eggs:** `EggViewController` clones egg + pet models briefly on hatch (uses `eggId` in hatch result).

Optional override: set **`modelName`** on any pet / egg / car definition in config if the Model in Studio must differ from the id.

## Workspace — worlds folder (POLA-628 / POLA-631)

Under **`Workspace.Worlds`**, each child should match a **`WorldConfig` id** or numeric order (`"1"`, `"2"`, …). **`WorldSpawnUtil`** picks lobby / travel CFrames in this order:

| Instance | Use |
|----------|-----|
| **`LobbySpawn`** | `BasePart`, **or** a **Model/Folder** whose first usable part is the stand point (feet offset applied upward). |
| **`Spawn`** | Same as LobbySpawn if LobbySpawn is missing. |
| **`Start`** (folder) | First **`BasePart`** child — physical start strips for `RunService` touch-to-start. |

Place lobby/spawn parts **above** the drivable surface so menu world travel does not bury the character.

## Driving HUD — optional headlights toggle (POLA-420)

`DACMain` is authored in Studio (not Rojo). To ship the headlight / high-beam control:

1. Under **`DACMain` → `PlayerInfo` → `DrivingUI`**, add a **`Frame`** named **`LightsToggle`** (chunky corner radius, ~56×56, anchor e.g. lower-right of the driving cluster).
2. Children (all pre-built, not script-generated):
   - **`Btn`** — `ImageButton` (transparent hit target filling the frame; or use a visible chrome image).
   - **`Off`**, **`Low`**, **`High`** — `ImageLabel` icons for lights off, low beam, high beam (only one visible at a time).
   - Optional **`ActiveGlow`** — `UIStroke` on the frame; script sets transparency (off = hidden, on = ~0.35).
3. `DrivingHUD` wires the control on init: click cycles **off → low → high → off**, plays `lights_toggle_on` / `lights_toggle_off`, tweens a **`UIScale`** punch (created at runtime if missing), and `DrivingController` adds a client **`SpotLight`** on the car’s **`PrimaryPart`** for low vs high intensity.

If **`LightsToggle`** is absent, the feature is inert — no errors.

## Driving HUD — optional mobile steer pedals (POLA-432)

The car **auto-accelerates**; there are no throttle/brake *gameplay* inputs. On touch, steering is **horizontal drag** with analog magnitude (`DrivingController`). Optional UI mirrors that as **left/right “pedals”** (lateral intensity), not gas/brake.

1. Under **`DACMain` → `PlayerInfo` → `DrivingUI`**, add a **`Frame`** named **`MobileSteerPedals`** (e.g. full-width bar at the bottom, ~18–24% height, `BackgroundTransparency = 1`).
2. Children:
   - **`Left`** — `Frame` (anchor bottom-left half of parent), optional **`UIStroke`** (`Rim`) for glow.
     - **`Fill`** — `ImageLabel` or `Frame` (script pins anchor bottom, scales height with steer-left amount). Script adds **`UIGradient`** if missing (green depth).
   - **`Right`** — same for steer-right (red gradient).
3. `DrivingHUD` shows this only when the steer hint mode is **touch**; fill height + gradient + stroke follow `|steer|`; **release** runs a short snap-back **UIScale** punch; light **haptic** when supported (`HapticService` + touch).

If **`MobileSteerPedals`** is absent, behavior is unchanged.

## Driving HUD — optional handbrake / drift indicator (POLA-457)

There is **no** handbrake or drift torque in vehicle physics — arcade forward drive + lateral steer only. **Cosmetic** “drift” juice: hold **Left/Right Shift** or gamepad **R1** (`ButtonR1`) during a run; `handbrake_on` / `handbrake_off` SFX + optional HUD.

1. Under **`DACMain` → `PlayerInfo` → `DrivingUI`**, add a **`Frame`** named **`HandbrakeHud`** (chunky rounded square, ~56×56; place near other driving chrome e.g. horn/lights).
2. Pre-built children (not script-generated shells except runtime **`UIScale`** punch if missing):
   - **`Icon`** — `ImageLabel` (white silhouette / tire-smoke glyph; script shifts tint magenta-pink while engaged).
   - **`Btn`** — `ImageButton` (optional; full-frame hit target for **touch hold** — mirrors `Horn` pattern).
   - **`Rim`** — optional `UIStroke` on the frame (script lowers transparency while engaged).

If **`HandbrakeHud`** is absent (or has no **`Icon`**), keyboard/gamepad engage still plays **`SoundController`** one-shots; there is simply no icon pulse.

**Audit note:** `rg -i handbrake` / vehicle drift input in `DACStarterPlayerScripts/**/*.luau` before POLA-457 showed **no** gameplay handbrake — this feature is HUD/SFX-only.

## Driving HUD — optional lane snap / “unstick” (POLA-468)

No flip physics — the car is **lane-steered** and **upright** every frame. **Lane snap** resets **lateral offset** to center (same as keyboard **R** / gamepad **Y** twice: two-step confirm + **8s** server cooldown via `RequestVehicleReset`).

1. Under **`DACMain` → `PlayerInfo` → `DrivingUI`**, add a **`Frame`** named **`VehicleReset`** (large touch target: **≥72×72** recommended; place near `Horn` / `HandbrakeHud`).
2. Pre-built children (scripts only wire them):
   - **`Btn`** — `ImageButton` (full-frame hit target; **big** for mobile).
   - Optional **`CooldownFill`** — `Frame` (anchor left, **Y** scale 1; script sets **X** width 0→1 for cooldown progress).
   - Optional **`TimerLabel`** or **`Timer`** — `TextLabel` (shows remaining seconds when on cooldown).
   - Optional **`Status`** — `TextLabel` (script shows **AGAIN!** / **WAIT** during confirm arm / cooldown).

If **`VehicleReset`** is absent, **R** / **Y** still work; there is no HUD chrome.
