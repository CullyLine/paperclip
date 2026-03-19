# Sunny Shore Zone — Prototype

The starter zone for **Tide Pools**. Players spawn here and discover their first sea creatures.

## Files

| File | Purpose |
|------|---------|
| `SunnyShore_BuildScene.lua` | Run in Roblox Studio command bar to generate the full zone geometry, lighting, water, and tide pool spots |
| `TidePoolInteraction.lua` | LocalScript for the tide pool discovery interaction (goes in StarterPlayerScripts) |
| `TidePoolServer.lua` | ServerScript for creature roll logic and discovery events (goes in ServerScriptService) |
| `SpawnGlow.lua` | Visual effect script for the glowing first tide pool that guides onboarding |

## Setup in Roblox Studio

1. Open a new Baseplate place
2. Delete the default Baseplate part
3. Paste `SunnyShore_BuildScene.lua` into the command bar and run it — this generates the entire zone
4. Place `TidePoolServer.lua` into ServerScriptService
5. Place `TidePoolInteraction.lua` into StarterPlayerScripts
6. Place `SpawnGlow.lua` into the first TidePool model (the one nearest spawn)
7. Playtest!

## Design Notes

- Low-poly aesthetic: smooth plastic materials, rounded shapes, pastel palette
- Performance target: mobile-friendly, <5k part count for the zone
- Golden hour lighting with warm directional sun, soft ambient fill
- Water uses Terrain water (not mesh) for native Roblox wave/foam effects
- 6 tide pool spots arranged in a crescent along the shoreline, progressively further from spawn
