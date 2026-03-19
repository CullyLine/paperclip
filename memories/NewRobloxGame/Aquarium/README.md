# Aquarium Template — Tide Pools

The player aquarium system for **Tide Pools**. Each player gets a personal aquarium island where they nurture creatures, produce pearls, and manage their collection.

## Files

| File | Type | Purpose |
|------|------|---------|
| `AquariumTemplate_BuildScene.lua` | Command Bar | Run in Roblox Studio to generate the aquarium geometry (island, tank, glass walls, water, lighting, decorations) |
| `AquariumServer.lua` | ServerScript | Creature state management, pearl production logic, growth timers, collection handling |
| `AquariumCreaturePlacement.lua` | LocalScript | Creature placement into tank slots with slot highlighting and visual feedback |
| `PearlVFX.lua` | ModuleScript | Pearl sparkle particles on creatures, collection burst effects, floating text |
| `PearlCounterUI.lua` | LocalScript | Pearl counter HUD (top-right pill) with count, rate display, and collection animation |

## Setup in Roblox Studio

1. Open a place (can be the same as Sunny Shore or a new one)
2. Paste `AquariumTemplate_BuildScene.lua` into the command bar and run it — generates the full aquarium template
3. Place `AquariumServer.lua` into **ServerScriptService**
4. Place `PearlVFX.lua` into **ReplicatedStorage** (as a ModuleScript)
5. Place `AquariumCreaturePlacement.lua` into **StarterPlayerScripts**
6. Place `PearlCounterUI.lua` into **StarterPlayerScripts**
7. Playtest!

## Architecture

### Build Scene
The command bar script creates an `AquariumTemplate` model in ServerStorage and a preview copy in Workspace. The template contains:
- **IslandFloor**: Sandy platform base (80x3x60 studs)
- **StarterTank**: Glass-walled aquarium tank (40x16x30 studs) with water volume, surface shimmer, substrate, decorative rocks and coral
- **CreatureSlots**: 6 invisible anchor points inside the tank for creature placement
- **PearlCollectionPoint**: Interactive pedestal with ProximityPrompt for claiming accumulated pearls
- **AmbientLights**: Overhead blue light + 4 teal accent lights for underwater feel
- **DecorationAnchors**: 6 anchor points around the island for future cosmetic placement
- **Post-processing**: Atmosphere, Bloom, and ColorCorrection effects for calming underwater aesthetic

### Server
- Tracks per-player aquarium state (creatures, pearls, pending fractional pearls)
- Pearl production ticks every 5 seconds; rates scale by rarity and growth stage
- Growth stages: baby (no pearls) → juvenile (30% rate) → adult (full rate)
- Growth times scale with rarity: Common 5min → Mythical 4hr
- Broadcasts full state sync to clients every 30 seconds

### Creature Placement
- Slot highlights pulse green when placement mode is active
- Click near an available slot to place a creature
- Press X to cancel placement
- Cross-script API via `AquariumPlacementTrigger` BindableEvent in ReplicatedStorage

### Pearl VFX
- `PearlVFX.attach(part, rate)` — adds sparkle particle emitter to a creature
- `PearlVFX.burst(position, count)` — collection burst effect
- `PearlVFX.floatingText(position, text)` — animated "+N Pearls" popup

### Pearl Counter UI
- Top-right HUD pill: pearl icon, count, production rate
- Pulses and flashes gold on collection
- Triggers VFX burst at the PearlCollectionPoint

## Design Notes

- Clean, calming aesthetic: soft blues/greens, warm sandy tones, gentle underwater lighting
- Glass tank walls at 70% transparency with 15% reflectance
- Water volume is a tinted glass part (85% transparent) for layered depth
- Neon water surface shimmer at 80% transparency
- Creature visuals are placeholder spheres — will be replaced with proper models
- All creature visuals have idle bobbing animation
- Mobile-friendly: no complex meshes, all standard Part types

## Spec Reference

See M0 design doc section 5.4 at `memories/NewRobloxGame/M0-design-doc.md` for the full aquarium specification.
