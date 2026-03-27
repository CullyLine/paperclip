# Drive a Car Simulator — Sound design & sourcing guide

**Source of truth:** `DACStarterPlayerScripts/Controllers/SoundController.luau` (`registerDefaults`, ~L385–510).  
**Hydration:** At init, `hydrateFromReplicatedStorageAudio()` loads `ReplicatedStorage.Audio` and **overwrites** any registry entry when a matching `Sound` or `StringValue` has a non-empty, non-zero `rbxassetid`. See `Audio/MANIFEST.md` for file ↔ key mapping.  
**Manifest / workflow:** `Audio/MANIFEST.md`, `ConceptArt/sound-design-guide.md` (if present).

**Snapshot (2026-03-22):** Every **registered** key in code uses a non-zero `rbxassetid://…`. The main **gap** is **volcano**: there are **no** `music_volcano` or `ambient_volcano` registrations.

**Engineering note (`setWorld`):** If `ambient_{worldId}` is missing **or** still `rbxassetid://0`, `SoundController.setWorld` **returns immediately after the music block** and does not fade the previous ambient. If `music_{worldId}` is also missing, **both** prior music and prior ambient can **keep playing** in the new world until another `setWorld` with valid beds runs. Filling **P0** volcano keys (or a small code fix to fade/clear when absent) resolves this for the volcano biome.

---

## Priority ranking (Board sourcing)

| Tier | Meaning | Action |
|------|---------|--------|
| **P0** | Wrong or silent world audio for a shipped world | Add `music_volcano` + `ambient_volcano` (and register in `SoundController` + optional `ReplicatedStorage.Audio` names) |
| **P1** | Immersion / clarity | Replace duplicate SFX IDs where the same asset is reused across unrelated UX (see *Duplicate IDs*); optional dedicated **world transition** stinger (not a registry key today — `world_travel` covers UI travel) |
| **P2** | Polish / variety | Alternate music beds per world, extra engine layer for highest tier, longer ambient variety |

---

## World atmosphere design

Crossfade time for music: **0.85s** (`CROSSFADE_TIME`). Ambient swaps with a short tween (**~0.45s**). Master tuning: music default **0.35**, SFX **0.25**, ambient scaled off SFX with **0.5** multiplier (`ambientMul`).

### Grasslands

| Layer | Current registry | Creative direction |
|--------|------------------|-------------------|
| Music | `music_grasslands` | Uplifting, daytime, casual driving energy; mid-tempo; avoid heavy bass — keep headroom for SFX. |
| Ambient | `ambient_grasslands` | Gentle outdoor bed: breeze, distant birds, soft water or meadow air; loop-friendly, no sharp transients. |
| **Roblox Audio Library search terms** | | `nature ambient loop`, `meadow wind`, `lake calm`, `acoustic happy loop`, `bright casual game music` |

### Desert

| Layer | Current registry | Creative direction |
|--------|------------------|-------------------|
| Music | `music_desert` | Dry heat, wider stereo; slightly slower or hypnotic; hint of adventure without combat intensity. |
| Ambient | `ambient_desert` | Wind, sand hiss, occasional distant metal creak or heat shimmer; very subtle low rumble OK. |
| **Search terms** | | `desert wind loop`, `middle eastern ambient`, `arid atmosphere`, `hot sun desert` |

### Frozen

| Layer | Current registry | Creative direction |
|--------|------------------|-------------------|
| Music | `music_frozen` | Cold, airy pads; light percussive sparkle; avoid harsh highs — ice reads as “crisp,” not “painful.” |
| Ambient | `ambient_frozen` | Wind through snow, crystalline gusts, faint ice crackle; keep level under tire/engine loops. |
| **Search terms** | | `winter wind loop`, `snow ambient`, `ice cave atmosphere`, `cold pad music` |

### Neon

| Layer | Current registry | Creative direction |
|--------|------------------|-------------------|
| Music | `music_neon` | Night city energy: synth bass, sidechain-friendly; tempo aligned with boost/combo juice. |
| Ambient | `ambient_neon` | Distant traffic, neon buzz, rain or wet street optional; urban hum — no dialogue or sirens unless stylized. |
| **Search terms** | | `cyberpunk city night`, `neon synthwave loop`, `urban ambience loop`, `synthwave driving` |

### Volcano (missing registry keys — **P0**)

**Required keys (to add in code after upload):** `music_volcano`, `ambient_volcano`.

| Layer | Creative brief | Notes |
|--------|----------------|-------|
| Music | Heavy low-end under midrange “heat”; tribal or industrial optional; tempo ~90–115 BPM; tension without constant dissonance. | Should feel **dangerous but playable** — not horror. |
| Ambient | Lava bubble/plop, distant rumble, occasional steam hiss, low crackle; **no** continuous explosion. | Loop must be seamless; duck under SFX. |
| **Search terms** | | `volcano ambient loop`, `lava bubble`, `molten cave`, `dramatic volcanic`, `inferno atmosphere game` |

### World transition (design — optional **P1**)

Today, **`world_travel`** (one-shot, SFX) fires from the world UI when moving. There is **no** dedicated “zone changed” sting separate from that. If the Board wants a clearer **transition hook**:

- **Brief:** 0.4–0.9s whoosh + tonal “land” hit; same energy across worlds, different optional high-frequency color per biome (or one neutral sting for all).
- **Implementation note:** Would need a new registry key (e.g. `world_transition`) and a call site in the same path as `setWorld` / travel success — not present in current `SoundController` API alone.

---

## Full sound inventory

**Legend:** **Status** = whether the key exists in `registerDefaults` with a non-zero ID. **Source note** = inline comment in `SoundController` (human label for the upload).

### Music & ambient (world)

| Key | Category | Current asset ID | Status | Source note / brief |
|-----|----------|------------------|--------|----------------------|
| `music_grasslands` | music | `rbxassetid://1841647093` | OK | Life in an Elevator |
| `music_desert` | music | `rbxassetid://122720386196973` | OK | Dealership (60s) |
| `music_frozen` | music | `rbxassetid://7640700658` | OK | Witches' Brew (133s) |
| `music_neon` | music | `rbxassetid://97844915150974` | OK | Rhythm Junkie (103s) |
| `music_volcano` | music | — | **MISSING** | Register + upload; see *Volcano* |
| `ambient_grasslands` | ambient | `rbxassetid://73798751154555` | OK | Lake |
| `ambient_desert` | ambient | `rbxassetid://9059618023` | OK | Defiance_Ambiance03 |
| `ambient_frozen` | ambient | `rbxassetid://11876250716` | OK | snow |
| `ambient_neon` | ambient | `rbxassetid://2843658663` | OK | City Sounds |
| `ambient_volcano` | ambient | — | **MISSING** | Register + upload; see *Volcano* |

### Engine & road (`sfx`)

| Key | Current asset ID | Source note |
|-----|------------------|-------------|
| `engine_buggy` | `rbxassetid://12843280490` | idle (generic) |
| `engine_sedan` | `rbxassetid://8836845570` | Audi R8 Idle |
| `engine_racer` | `rbxassetid://130983335056535` | V10 |
| `engine_supercar` | `rbxassetid://7136339316` | Aventador Low |
| `engine_wind` | `rbxassetid://11876250654` | asphalt (road surface layer) |

### UI & general (`sfx`)

| Key | Current asset ID | Source note |
|-----|------------------|-------------|
| `click` | `rbxassetid://10630778959` | Click |
| `near_miss` | `rbxassetid://14753859187` | bov_1 (whoosh) |
| `combo_break` | `rbxassetid://14755055417` | low_med_off (engine cut) |
| `ui_whoosh` | `rbxassetid://10849970849` | SpawnParticle (swoosh) |
| `purchase` | `rbxassetid://9545920468` | GoldCorn (cha-ching) |
| `purchase_thankyou_buildup` | `rbxassetid://9538232720` | PE-Electrical_BW.32224 (riser) |
| `purchase_thankyou_reveal` | `rbxassetid://9545920468` | GoldCorn |
| `purchase_thankyou_reveal_vip` | `rbxassetid://9660107771` | ClubSmash |
| `purchase_thankyou_reveal_mega` | `rbxassetid://9660466869` | Stomp (heavy impact) |
| `purchase_fail` | `rbxassetid://9538241258` | PE-Electrical_BW.32179 (error buzz) |
| `error` | `rbxassetid://9538241258` | PE-Electrical_BW.32179 |
| `tab_switch` | `rbxassetid://9660507545` | Tap |
| `panel_open` | `rbxassetid://7938564577` | WarmPluck |
| `panel_close` | `rbxassetid://9660507545` | Tap |
| `equip_item` | `rbxassetid://9591690518` | Absorb |
| `world_unlock` | `rbxassetid://9460707764` | BustOpen |
| `world_travel` | `rbxassetid://12842999193` | startup |
| `notification` | `rbxassetid://10630729494` | UIBlip |
| `quest_progress` | `rbxassetid://7938634444` | ui_sound_12 |
| `ui_confirm` | `rbxassetid://7938634444` | ui_sound_12 |
| `cha_ching` | `rbxassetid://10849997662` | Coin |
| `level_up` | `rbxassetid://6971833728` | Item Collect |

### Egg hatch (`sfx`)

| Key | Current asset ID | Source note |
|-----|------------------|-------------|
| `hatch` | `rbxassetid://9546777688` | Bubble (default sting) |
| `hatch_common` | `rbxassetid://9546777688` | Bubble |
| `hatch_uncommon` | `rbxassetid://9554965517` | blinky |
| `hatch_rare` | `rbxassetid://10849970849` | SpawnParticle |
| `hatch_epic` | `rbxassetid://9460707764` | BustOpen |
| `hatch_legendary` | `rbxassetid://9660107771` | ClubSmash |
| `hatch_mythic` | `rbxassetid://9660482478` | Explosion |
| `egg_crack_small` | `rbxassetid://12946370827` | crackle_12 |
| `egg_crack_medium` | `rbxassetid://9729017179` | Punch |
| `egg_crack_large` | `rbxassetid://9660466869` | Stomp |
| `egg_mythic_hum` | `rbxassetid://9538232720` | PE-Electrical_BW.32224 |
| `egg_mythic_resonance` | `rbxassetid://9538241258` | PE-Electrical_BW.32179 |

### Pet equip (`sfx`)

| Key | Current asset ID | Source note |
|-----|------------------|-------------|
| `pet_equip_common` | `rbxassetid://9546777688` | Bubble |
| `pet_equip_uncommon` | `rbxassetid://9591690518` | Absorb |
| `pet_equip_rare` | `rbxassetid://10849970849` | SpawnParticle |
| `pet_equip_epic` | `rbxassetid://7938564577` | WarmPluck |
| `pet_equip_legendary_beam` | `rbxassetid://9538232720` | PE-Electrical_BW.32224 |
| `pet_equip_legendary_impact` | `rbxassetid://9575596194` | Impact |
| `pet_equip_mythic_tear` | `rbxassetid://9538241258` | PE-Electrical_BW.32179 |
| `pet_equip_mythic_explosion` | `rbxassetid://9660482478` | Explosion |

### Rebirth (`sfx`)

| Key | Current asset ID | Source note |
|-----|------------------|-------------|
| `rebirth` | `rbxassetid://9660107771` | ClubSmash (full sting) |
| `rebirth_riser` | `rbxassetid://9538232720` | PE-Electrical_BW.32224 |
| `rebirth_whoosh` | `rbxassetid://9146096134` | StartedBoosting |
| `rebirth_boom` | `rbxassetid://9660482478` | Explosion |
| `rebirth_confetti` | `rbxassetid://9545920468` | GoldCorn |

### Driving HUD & gameplay (`sfx`)

| Key | Current asset ID | Source note |
|-----|------------------|-------------|
| `milestone` | `rbxassetid://7938634444` | ui_sound_12 |
| `combo` | `rbxassetid://9554965517` | blinky |
| `speed_tier` | `rbxassetid://9146096134` | StartedBoosting |
| `fuel_warning` | `rbxassetid://9554965517` | blinky |
| `alert` | `rbxassetid://9538241258` | PE-Electrical_BW.32179 |
| `fusion` | `rbxassetid://9591690518` | Absorb |
| `screech` | `rbxassetid://11864334285` | drift |
| `boost` | `rbxassetid://9146096251` | Boosting |
| `collision` | `rbxassetid://9575596194` | Impact |
| `coin_pickup` | `rbxassetid://10849997662` | Coin |
| `distance_marker` | `rbxassetid://7938634444` | ui_sound_12 |
| `lap_horn` | `rbxassetid://14753859187` | bov_1 |

### Fuel warnings (`sfx`)

| Key | Current asset ID | Source note |
|-----|------------------|-------------|
| `fuel_warning_25` | `rbxassetid://9554965517` | blinky (gentle beep) |
| `fuel_warning_10` | `rbxassetid://9538241258` | PE-Electrical_BW.32179 |
| `fuel_warning_5` | `rbxassetid://9538232720` | PE-Electrical_BW.32224 |
| `fuel_empty` | `rbxassetid://14755055417` | low_med_off (engine stall) |

### Premium, events, tutorial, payout, trophy (`sfx`)

| Key | Current asset ID | Source note |
|-----|------------------|-------------|
| `premium_welcome` | `rbxassetid://9545920468` | GoldCorn |
| `currency` | `rbxassetid://10849997662` | Coin |
| `event_fanfare` | `rbxassetid://9460707764` | BustOpen |
| `tutorial_step` | `rbxassetid://9660507545` | Tap |
| `tutorial_complete` | `rbxassetid://6971833728` | Item Collect |
| `payout_card_pop` | `rbxassetid://9546777688` | Bubble |
| `payout_badge_tick` | `rbxassetid://9660507545` | Tap |
| `payout_run_of_day` | `rbxassetid://7938564577` | WarmPluck |
| `payout_tier_up` | `rbxassetid://9545920468` | GoldCorn |
| `trophy_bronze` | `rbxassetid://9660507545` | Tap |
| `trophy_silver` | `rbxassetid://7938564577` | WarmPluck |
| `trophy_gold` | `rbxassetid://9545920468` | GoldCorn |
| `trophy_diamond` | `rbxassetid://9660107771` | ClubSmash |
| `trophy_total_completion` | `rbxassetid://6971833728` | Item Collect |

**Total registered keys:** 79 (77 with explicit IDs in code + **2 missing volcano keys** to add for parity with five worlds).

---

## Duplicate asset IDs (optional **P1** cleanup)

Several keys intentionally share IDs (e.g. hatch tiers, rebirth layers). These **reuse the same Roblox asset** and may feel samey; consider distinct uploads later:

| Asset ID | Used by (keys) |
|----------|----------------|
| `9538241258` | `purchase_fail`, `error`, `egg_mythic_resonance`, `pet_equip_mythic_tear`, `alert`, `fuel_warning_10` |
| `9538232720` | `purchase_thankyou_buildup`, `egg_mythic_hum`, `pet_equip_legendary_beam`, `rebirth_riser`, `fuel_warning_5` |
| `9545920468` | `purchase`, `purchase_thankyou_reveal`, `rebirth_confetti`, `premium_welcome`, `payout_tier_up`, `trophy_gold` |
| `7938634444` | `quest_progress`, `ui_confirm`, `milestone`, `distance_marker` |
| `9660507545` | `tab_switch`, `panel_close`, `tutorial_step`, `payout_badge_tick`, `trophy_bronze` |
| `7938564577` | `panel_open`, `pet_equip_epic`, `payout_run_of_day`, `trophy_silver` |
| `9554965517` | `hatch_uncommon`, `combo`, `fuel_warning`, `fuel_warning_25` |
| `9146096134` | `rebirth_whoosh`, `speed_tier` |
| `14753859187` | `near_miss`, `lap_horn` |

---

## Board checklist: adding volcano audio

1. Source or create loopable **OGG** (music + ambient), TOS-safe for Roblox upload.
2. Upload to Roblox; copy asset IDs.
3. Add to `ReplicatedStorage.Audio` as instances named `music_volcano` and `ambient_volcano` **or** add two lines to `registerDefaults` in `SoundController.luau`.
4. Playtest: travel to volcano, confirm `setWorld("volcano")` crossfades music and ambient (verify `Bootstrap.local.luau` passes `currentWorld` correctly).

---

## Files on disk

| Deliverable | Path |
|-------------|------|
| This document | `memories/DriveACarSimulator/SOUND_DESIGN.md` |
| Registry implementation | `DACStarterPlayerScripts/Controllers/SoundController.luau` |
| Asset tree / workflow | `Audio/MANIFEST.md` |
