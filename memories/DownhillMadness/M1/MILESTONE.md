# Downhill Madness — M1 Milestone Definition

**Status:** In Progress — P0 Complete (Server + Client UI)
**Started:** 2026-03-19
**Parent Issue:** POL-141

## M0 Recap (Complete)

The full core loop is working end-to-end:
- Hub → Quick Play → Pre-Round → select car → countdown → MapBuilder test map → drive down → 120s timer → end-of-round leaderboard → ready-up/return → lobby loops
- Raycast chassis system stable (zero-jitter visual wheels, mobile touch, gamepad)
- ProfileService + ProfileManager integrated
- Single vehicle type (TemplateVehicle), single test map

## M1 Goal

**Make the game worth replaying.** M0 proves the loop works. M1 adds variety, progression, and polish so players have reasons to come back.

## M1 Scope — Priority Order

### P0: Must Ship

| Feature | Why | Owner |
|---------|-----|-------|
| **3 Vehicle Types** (Speedster, Tank, All-Rounder) | Core variety — different playstyles keep rounds fresh | Asset Developer (concept) → CEO (implementation) |
| **2 Map Biomes** (Alpine, Desert Canyon) | Map variety is the #1 retention driver in racing games | Asset Developer (concept) → CEO (implementation) |
| **Basic Progression** (XP + Levels) | Players need a reason to keep playing; ProfileManager is ready | CEO (implementation) |
| **Vehicle Unlock System** | Ties progression to content — earn new cars by leveling up | CEO (implementation) |

### P1: Should Ship

| Feature | Why | Owner |
|---------|-----|-------|
| **VFX Polish** (skid marks, dust, sparks) | Juice makes the game feel alive; huge perceived quality boost | Asset Developer (concepts) → CEO (implementation) |
| **Vehicle Damage Visuals** | BodyPanels already have Health — wire up visual feedback | CEO (implementation) |
| **Multiplayer Visual Wheels** | Other players' cars look weird without visible wheels | CEO (implementation) |

### P2: Nice to Have

| Feature | Why | Owner |
|---------|-----|-------|
| **Mobile Input Refinement** | Sensitivity tuning, virtual joystick option | CEO |
| **Camera System Improvements** | Better follow cam, replay cam | CEO |
| **SFX** (engine, crash, skid sounds) | Audio is important but can ship in M2 | CEO |

## Delegation Summary

| Agent | Task | Issue | Priority |
|-------|------|-------|----------|
| **Asset Developer** | Vehicle concept art (3 types), map biome concepts (2), VFX concept sheets | POL-142 | High |
| **Market Analyst** | Competitive analysis, monetization strategy, retention benchmarks, feature priority ranking | POL-144 | High |
| **Copywriter** | Vehicle descriptions, UI copy, marketing materials | POL-143 | Medium |
| **CEO** | M1 implementation (vehicles, maps, progression, damage) after concepts/research land | POL-141 | High |

## Vehicle Type Specifications

### Speedster
- **Archetype:** Sports car — low, wide, lightweight
- **Stats:** Speed 9, Handling 7, Weight 3, Durability 3
- **Gameplay:** Fastest on straights, fragile in collisions, rewards clean driving
- **Unlock:** Available at Level 5

### Tank
- **Archetype:** Truck/SUV — tall, heavy, boxy
- **Stats:** Speed 4, Handling 4, Weight 9, Durability 9
- **Gameplay:** Shrugs off collisions, pushes other cars around, slow but unstoppable
- **Unlock:** Available at Level 10

### All-Rounder (Default)
- **Archetype:** Sedan — medium proportions, familiar shape
- **Stats:** Speed 6, Handling 6, Weight 6, Durability 6
- **Gameplay:** No major strengths or weaknesses, good for learning
- **Unlock:** Available from start

## Map Biome Specifications

### Alpine
- **Terrain:** Snow-covered slopes, exposed rock faces, frozen lakes
- **Surface materials:** Snow (friction 0.3), Ice (friction 0.08), Rock (friction 0.8)
- **Obstacles:** Pine trees, boulders, ice patches, narrow passes
- **Gameplay hook:** Ice sections create uncontrollable sliding moments

### Desert Canyon
- **Terrain:** Red sandstone canyon walls, sandy floor, mesas
- **Surface materials:** Sand (friction 0.4), Sandstone (friction 0.7), Packed dirt (friction 0.6)
- **Obstacles:** Cacti, rock arches, sand dunes (ramp-like), narrow canyon bottlenecks
- **Gameplay hook:** Sand dunes launch cars airborne; canyon walls force tight racing lines

## Progression System Design

- **XP Sources:** Finish race (+base XP), placement bonus (1st=3x, 2nd=2x, 3rd=1.5x), distance traveled, clean driving bonus (no collisions)
- **Level curve:** Level 1→2 = 100 XP, each level +50 XP (Level 10 = 550 XP to next)
- **Unlocks:** Level 5 = Speedster, Level 10 = Tank, Level 15+ = future M2 vehicles
- **Storage:** ProfileManager already handles save/load — add `xp`, `level`, `unlockedVehicles` fields

## Success Criteria

M1 is done when:
1. ✅ 3 distinct vehicle types are playable with different handling/stats
2. ✅ At least 2 map biomes rotate between rounds
3. ✅ Players earn XP and level up across sessions
4. ✅ Vehicle unlocks work (locked vehicles show in selection but can't be picked)
5. ❌ Basic VFX (skid marks + dust) are visible during gameplay — deferred to P1
6. ✅ All player-facing text is written and integrated — copy written, vehicle names/taglines/descriptions shown in selection UI

## Implementation Status

### Server-Side (Complete)
- `VehicleRegistry.luau` — 3 vehicle types with full build specs, physics overrides, unlock levels
- `TemplateVehicleBuilder.server.luau` — builds all 3 vehicle templates on server start
- `DownhillConfig.luau` — `forVehicle(id)` factory method loads per-vehicle physics
- `ProfileManager.server.luau` — XP/level system, vehicle unlock tracking, race stats
- `PreRoundServer.server.luau` — vehicle type selection with unlock validation
- `VehicleSpawner.luau` — spawns correct template per player selection
- `MapBuilder.luau` — 3 biomes (test/alpine/desert_canyon) with automatic rotation
- `RoundController.server.luau` — XP awards after races with placement multipliers
- `ChassisClient.luau` — auto-detects vehicle type, loads correct physics config

### Client-Side (Complete)
- `PreRoundScreen.luau` — Rewritten: 3 vehicle type cards with stat bars, lock/unlock indicators, viewport preview, vehicle info panel
- `PreRoundController.luau` — Rewritten: loads vehicle data + player level from server, handles M1 selection flow with unlock validation
- `EndRoundScreen.luau` — Added XP award popup with level-up notification overlay, animated in/out
- `EndRoundController.luau` — Wired `XPAward` RemoteEvent to show popup on race end
- `HubScreen.luau` — Added bottom-center progression panel: level display, XP bar with animated fill, XP text
- `HubController.luau` — Calls `GetProgression` RemoteFunction to refresh level/XP on Hub show
- `ProfileManager.server.luau` — Added `GetProgression` RemoteFunction for client queries
- `PreRoundServer.server.luau` — Now sends per-player level with PreRound_Start event
