# Phase 4 — Grasslands launch-world polish

**Goal:** The starter world must read as *premium simulator* within the first 60 seconds — before the player opens any menu. This doc ties **PreLaunchChecklist** (Grasslands fully polished), **POLA-104** (Phase 4 juice), and existing code specs into one Studio-facing checklist.

**Canonical references**

- Visual language: `AGENTS.md` (panel anatomy, colors, chunky rounded shapes).
- Ambient particles (rates, colors, LOD): `DACStarterGui/DrivingVFXDesignSpec.luau` — Section D, Grasslands block.
- World copy / arrival fantasy: `DACReplicatedStorage/Config/WorldUnlockConfig.luau` (`grasslands` flavor).
- Audio registration: `DACStarterPlayerScripts/Controllers/SoundController.luau` — `music_grasslands`, `ambient_grasslands`.
- Trail / screen tint keys: `VFXController.luau` — `WORLD_TRAIL_NEON.grasslands` (neon accent for juice, not biome lighting).

---

## 1. First 60 seconds — player journey

| Moment | What “great” looks like | Verify in Studio |
|--------|-------------------------|-------------------|
| Join / spawn | Bright, readable; no grey default lighting; car silhouette reads against terrain | Play solo, default graphics level |
| First throttle | Engine + music feel upbeat, not library-stock generic | Mute UI SFX temporarily; listen to loop |
| First straight | Highway edges read at speed; no “floating road” silhouette | 80+ studs/s, mobile + desktop |
| Idle 5s (not in run) | Meadow atmosphere: subtle pollen/dandelion; nothing noisy over HUD | Ambient VFX on; LOD 2 and 3 |

---

## 2. Lighting & atmosphere

- **Time of day:** Prefer late-morning / early-afternoon — warm sun, long soft shadows. Avoid flat noon grey.
- **Sky:** Blue with gentle gradient; optional light volumetric haze *if* performance budget allows on target devices.
- **Fog:** Light aerial perspective only — keep distant highway readable; don’t wash out the pastel world identity.
- **Global tint:** Grass and foliage skew **saturated green + warm yellow highlights** (see `WorldPanel` / `InventoryPanel` grasslands accent cues — stay coherent with UI greens).

**Fail if:** Interiors or highway read as Roblox “baseplate grey” or lighting flickers on vehicle camera.

---

## 3. Highway readability (gameplay-critical)

- **Lane contrast:** Asphalt vs shoulder vs grass must remain distinct at motion blur speeds.
- **Edge language:** Consistent guardrail or curb silhouette; periodic props (posts, bushes) for parallax.
- **Horizon:** Clear silhouette — hills or treeline; avoid empty gradient void.
- **Collision clarity:** Barriers and off-road reads *before* the player hits them (silhouette + color).

---

## 4. Ambient VFX — Grasslands (code-aligned)

Per `DrivingVFXDesignSpec.luau`:

| Layer | Status | Polish note |
|-------|--------|-------------|
| L1 Pollen motes | Implemented | Confirm LOD 2 reduction doesn’t kill mood on mid devices |
| L2 Dandelion seeds | Implemented | Wind drift should feel directional (consistent “breeze”) |
| L3 Butterfly accent | Spec’d (LOD 3) | **Phase 4 stretch:** implement if frame budget allows; otherwise document defer |

**Secondary layers** (spec calls out “enhanced secondary layers” as missing across worlds): for Grasslands only, optional **low-rate** grass blade glints or sun-sparkle on distant trees — *subordinate* to pollen; never compete with speed trails.

---

## 5. Audio pairing

| Key | Role | Polish bar |
|-----|------|------------|
| `music_grasslands` | Loop identity | Seamless loop; level-match DrivingHUD intensity |
| `ambient_grasslands` | Space + depth | Audible at idle; ducks appropriately when run SFX stack |

**Fail if:** Music fights engine loop or ambient pops on world entry.

---

## 6. Spawn / lobby “wow” (non-run)

- Reinforce **WorldFlavor** line: *“Green fields, open roads, and your very first lap.”*
- Spawn pad or safe zone: slight elevation, signage, or props that frame the **first car** — players should want to screenshot before driving.
- Keep UI-chrome colors aligned with `AGENTS.md` if any world UI is visible from spawn.

---

## 7. Sign-off checklist (copy to PreLaunch / QA)

- [ ] Grasslands default spawn: lighting + sky + fog approved (art owner).
- [ ] Highway loop: readable at top speed + mobile safe area.
- [ ] Ambient idle particles on; run transition stops ambient (matches `VFXFacade` contract).
- [ ] `music_grasslands` + `ambient_grasslands` balanced vs SFX.
- [ ] No z-fighting or strobing on main highway mesh at day cycle used for launch.

---

## 8. Handoff

- **Engineering / MCP:** Tune emitters in Studio against Section D numbers; wire any new asset IDs through existing `SoundController` / `VFXFacade` patterns — no ad-hoc magic numbers in client entry scripts.
- **CEO / Board:** Grasslands polish is the **thumbnail biome** — marketing captures should be taken from this pass once sign-off is complete.
