# Drive a Car Simulator — Audio asset manifest

> **CHECK `ReplicatedStorage.Audio` FIRST** — The Board has gathered all uploaded
> audio samples into `ReplicatedStorage.Audio` in Studio. Before creating,
> sourcing, or uploading any new audio (SFX, music, UI sounds, ambient loops):
>
> 1. Browse `ReplicatedStorage.Audio` — these assets are already uploaded and
>    TOS-approved on Roblox.
> 2. Only source/upload new audio if nothing in that folder fits the need.
> 3. `SoundController.hydrateFromReplicatedStorageAudio()` already reads this
>    folder at init and overwrites `rbxassetid://0` placeholders with real IDs.
>    Match the Sound's `Name` to a registry key below (or add an alias in
>    `AUDIO_NAME_ALIASES`).

Placeholder **silent OGG** files were generated with `generate_placeholders.py` (ffmpeg) so the tree exists for Studio upload and version control. **Replace** each file with a Splice-claimed WAV (see workflow below), then re-encode to **OGG Vorbis** at the suggested bitrate before uploading to Roblox.

**Design reference:** `ConceptArt/sound-design-guide.md`  
**Registry:** `DACStarterPlayerScripts/Controllers/SoundController.luau` (`registerDefaults`)

---

## Sourcing workflow (priority order)

### 1. ReplicatedStorage.Audio (preferred)

Check Studio's `ReplicatedStorage.Audio` folder. If a sound there fits the need,
name it to match the registry key (or add an alias in `SoundController.AUDIO_NAME_ALIASES`).
No upload or credits needed — these are already live and TOS-cleared.

### 2. Splice (when nothing in RS.Audio fits)

1. Search → **preview** (saves MP3, no credits) → **claim** (1 credit each) → **download** WAV.  
2. Convert to mono/stereo OGG as needed: `ffmpeg -i input.wav -c:a libvorbis -q:a <n> output.ogg` (or fixed bitrate `-b:a 96k`).  
3. Overwrite the matching path below and record the **Splice sample UUID** in the tables.  
4. Upload to Roblox, paste `rbxassetid://` into `SoundController` for that registry key.

**Splice CLI (this machine):** `F:\CODE STUFF\Paperclip\tools\splice-cli\splice.mjs` — run with `node`. **Auth:** `node ... login` once (token cache: `%USERPROFILE%\.splice-cli\tokens.json`). **Status:** `node ... status` (credits). Search works without login; **claim** + **download** require auth.

---

## OGG bitrate guide (from sound-design-guide §9)

| Content | Vorbis bitrate (starting point) |
|--------|----------------------------------|
| Music bed | 96–128 kbps |
| Rich SFX (hatch, rebirth, mythic) | 96–128 kbps |
| Short UI / simple one-shots | 64–96 kbps |

---

## `engines/` — idle loops (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `buggy_idle.ogg` | `engine_buggy` | loop, small engine, wheezy, cartoon, 3–6s | _pending_ | Mono; test loop seam if pitch-shifted |
| `sedan_idle.ogg` | `engine_sedan` | loop, car idle, smooth hum, 4–8s | _pending_ | Reference level |
| `racer_idle.ogg` | `engine_racer` | loop, aggressive engine growl, sport, 4–8s | _pending_ | Optional second “accel” layer later |
| `supercar_idle.ogg` | `engine_supercar` | loop, deep engine, cinematic, 4–10s | _pending_ | Use sparingly (loudest tier) |

**POLA-436 — ignition one-shots (not loops)**  
Client hook: there is **no** `VehicleSeat`/sit pipeline; a run begins when the server fires `StartRun` → `Bootstrap` → `DrivingController.startRun` (and `DrivingHUD.show`). Ignition SFX + HUD flash are triggered from `DrivingController.startRun` after idle/wind loops start.

| File | Registry key | Notes |
|------|----------------|--------|
| `ignition.ogg` | `ignition` | Short key/starter click before idle loop; placeholder `rbxassetid://0` in `SoundController` until upload |
| `engine_start.ogg` | `engine_start` | Optional second layer (motor catches); placeholder `rbxassetid://0` until upload |

---

## `ui/` — interface (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `click.ogg` | `click` | UI click soft pop bubble, oneshot 40–90ms | _pending_ | Mono |
| `ui_quickbar_hover.ogg` | `ui_quickbar_hover` | soft tick when pointer enters ActionBar quick slot (`UIController` MenuHub strip) | _pending_ | Mono; placeholder `rbxassetid://0` until upload |
| `ui_quickbar_press.ogg` | `ui_quickbar_press` | short tactile down-click for ActionBar quick slot press | _pending_ | Mono; placeholder `rbxassetid://0` until upload |
| `purchase_success.ogg` | `purchase` | cash register cha-ching sparkle, 0.6–1.4s | _pending_ | Mono |
| `purchase_fail.ogg` | `purchase_fail` | soft error buzz reject, 0.25–0.5s | _pending_ | Mono |
| `tab_switch.ogg` | `tab_switch` | UI whoosh swipe subtle, 120–220ms | _pending_ | Very quiet bed |
| `cosmetic_select.ogg` | `cosmetic_select` | short tactile “slot in” when picking a different car in Garage → Cosmetics (`InventoryPanel`) | _pending_ | Mono; placeholder `rbxassetid://0` until upload — POLA-424 |
| `panel_open.ogg` | `panel_open` | airy swoosh up, 200–350ms | _pending_ | Mono |
| `panel_close.ogg` | `panel_close` | reverse swoosh suck, 180–300ms | _pending_ | Mono |
| `notification.ogg` | `notification` | bright ding UI, 0.15–0.35s | _pending_ | Mono |
| `collection_discover.ogg` | `collection_discover` | soft holo shimmer / card flip tick when a new pet is indexed (can alias `panel_open` / WarmPluck until upload) | _pending_ | Mono |
| `level_up.ogg` | `level_up` | arpeggio chime ascend reward, 1–2s | _pending_ | Mono |
| `quest_claim_fanfare.ogg` | `quest_claim_fanfare` | compact quest turn-in sting (can alias `level_up` / `quest_complete` until unique asset) | _pending_ | Mono |
| `bp_tier_claim.ogg` | `bp_tier_claim` | Battle Pass tier claim sting (can alias `level_up` until unique asset) | _pending_ | Mono |
| `bp_xp_tick.ogg` | `bp_xp_tick` | soft tick / blip when BP XP increases (can alias `quest_progress`) | _pending_ | Mono |
| `event_countdown_tick.ogg` | `event_countdown_tick` | short UI tick when live-ops banner crosses <1h / <10m / <5m (debounced in `EventBanner`) | _pending_ | Mono; can alias `notification` until dedicated upload |
| `world_portal_confirm.ogg` | `world_portal_confirm` | short tactile UI confirm when confirming world travel/unlock from World panel (`WorldPortalPrompt`) | _pending_ | Mono; currently aliases `ui_sound_12` in `SoundController` until upload |
| `ui_destructive_warn.ogg` | `ui_destructive_warn` | tense UI sting when opening destructive confirm (rebirth, fusion consume) | _pending_ | Mono; placeholder `rbxassetid://0` in `SoundController` until upload |
| `ui_destructive_confirm.ogg` | `ui_destructive_confirm` | short heavy click / lock-in when confirming a destructive action | _pending_ | Mono; placeholder `rbxassetid://0` until upload |
| `lights_toggle_on.ogg` | `lights_toggle_on` | mechanical detent when enabling low or high beams (`DrivingHUD` / optional `LightsToggle`) | _pending_ | Mono; placeholder `rbxassetid://0` — POLA-420 |
| `lights_toggle_off.ogg` | `lights_toggle_off` | mechanical detent when dimming or turning headlights off | _pending_ | Mono; placeholder `rbxassetid://0` — POLA-420 |
| `tutorial_skip_open.ogg` | `tutorial_skip_open` | soft UI open when tutorial skip confirm appears (`TutorialOverlay` / `DACTutorialOverlay.SkipConfirm`) | _pending_ | Mono; placeholder `rbxassetid://0` — POLA-455 |
| `tutorial_skip_confirm.ogg` | `tutorial_skip_confirm` | confirm sting when player taps Skip anyway | _pending_ | Mono; placeholder `rbxassetid://0` — POLA-455 |

**POLA-447 — vehicle enter prompt / success (no `ProximityPrompt` in repo)**  
`rg ProximityPrompt` / `VehicleSeat` in `memories/DriveACarSimulator/**/*.luau` → **no matches**. Runs start via `Workspace.Worlds.*.Start` **Touched** (`RunService.wireStartZone`) and `Remotes.StartRun` (e.g. payout **Play Again**). There is no driver/passenger **ProximityPrompt** to skin; lobby “invitation” juice uses **distance to Start parts** (`VehicleEnterJuiceController`) + HUD ring, and **run begin** uses `vehicle_enter_success` + checkmark in `DrivingController.startRun`.

| File (future) | Registry key | Notes |
|---------------|----------------|-------|
| `vehicle_enter_prompt.ogg` | `vehicle_enter_prompt` | Soft UI tick / shimmer when player is near a world **Start** zone (lobby); placeholder `rbxassetid://0` |
| `vehicle_enter_success.ogg` | `vehicle_enter_success` | Short confirm sting + checkmark pop when `StartRun` begins; placeholder `rbxassetid://0` |

### Spectator / follow camera (POLA-405)

**Gameplay:** There is no dedicated spectator or follow-other-player camera in this codebase as of the POLA-405 audit (only driving chase `Scriptable` vs `Custom` in `DrivingController`). The registry keys below exist so a future mode can call `SoundController.playOneShot("spectator_enter")` / `spectator_exit` without renaming.

| File (future) | Registry key | Notes |
|----------------|----------------|--------|
| _TBD `spectator_enter.ogg`_ | `spectator_enter` | Placeholder `rbxassetid://0` in `SoundController` until upload |
| _TBD `spectator_exit.ogg`_ | `spectator_exit` | Placeholder `rbxassetid://0` in `SoundController` until upload |

---

## `hatch/` — egg rarity (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `common.ogg` | `hatch`, `hatch_common` | cute pop jingle reward, 0.5–1s | _pending_ | `hatch` defaults here until UI passes rarity |
| `uncommon.ogg` | `hatch_uncommon` | gentle chime sparkle, 0.8–1.4s | _pending_ | |
| `rare.ogg` | `hatch_rare` | rising chime sequence swoosh, 1.2–2s | _pending_ | |
| `epic.ogg` | `hatch_epic` | dramatic sting whoosh impact, 1.8–3s | _pending_ | |
| `legendary.ogg` | `hatch_legendary` | orchestral fanfare crowd, 3–4.5s | _pending_ | Higher bitrate if dense |
| `mythic.ogg` | `hatch_mythic` | thunder choir bass drop epic, 4–6.5s | _pending_ | Higher bitrate if dense |

---

## `rebirth/` — layered fanfare (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `riser.ogg` | `rebirth`, `rebirth_riser` | brass string riser heroic, 1–2s | _pending_ | `rebirth` = composite in code later |
| `whoosh.ogg` | `rebirth_whoosh` | golden shimmer sweep, 0.4–0.8s | _pending_ | |
| `boom.ogg` | `rebirth_boom` | sub impact thump short, 0.25–0.45s | _pending_ | |
| `confetti.ogg` | `rebirth_confetti` | celebration crowd rustle bells, 1–2.5s | _pending_ | |

---

## `music/` — world beds (`music`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `grasslands.ogg` | `music_grasslands` | loop acoustic bright 120 BPM G major | `aa4d727d2123eb05cbe710f5586d6c51a4018ad4d8fc3f62d7ddea6cd320b06a` | Stereo OK; −22 to −18 LUFS bed |
| `desert.ogg` | `music_desert` | loop middle eastern 100 BPM hijaz | `ae158fa9026066e3fef772c619052401266044a262a377980d324033df9dbe0d` | |
| `frozen.ogg` | `music_frozen` | loop ambient pad music box 90 BPM | `daf92483c4e07577cb71ecd2b47a7e66199c82eecf167505a1cc1335519f603f` | |
| `neon.ogg` | `music_neon` | loop synthwave 130 BPM minor pentatonic | `584cbb901c7b23e2693ae5fd2d45db5a1e606a4c6e92933c8562ac4115b7bb6b` | |

**Rojo default IDs** — must stay in sync with `DACStarterPlayerScripts/Controllers/SoundController.luau` → `registerDefaults` (POLA-474). See the **POLA-474 — World-bed registry** table under `ambient/` below.

---

## `ambient/` — world ambience (`ambient`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `grasslands_amb.ogg` | `ambient_grasslands` | loop nature breeze light foley bed | `50f64487bf7c59cb12b3290553a6048a1c194a3f244ec8be6284586fd1fd5a83` | Lower than music; duck under SFX |
| `desert_amb.ogg` | `ambient_desert` | loop desert wind heat subtle | `eb8ea7761e21eaef004479dfcfaf12bac784bc2537bd612072dc41a71942ca3e` | |
| `frozen_amb.ogg` | `ambient_frozen` | loop wind crystalline air | `1f8f8b8063d874b6c5079afe8c44d5298d3649069efb427127f226918ae773f5` | |
| `neon_amb.ogg` | `ambient_neon` | loop city night hum neon | `ff89b7f31f9e8e5df928c3beeed07d4bbbb80385de7dfd002adb6a103ed241a6` | |

**Rojo default IDs** — same as music row above; authoritative table below.

### POLA-474 — World-bed registry (Rojo ↔ SoundController)

Eight slots (four worlds × music + ambient). Defaults in repo are **non-zero** `rbxassetid://…` strings in `SoundController.registerDefaults`; `hydrateFromReplicatedStorageAudio()` may override from `ReplicatedStorage.Audio` when Sound names match registry keys.

| Registry key | Default `rbxassetid` | In-code comment (asset label) |
|--------------|----------------------|------------------------------|
| `music_grasslands` | `rbxassetid://1841647093` | grasslands.ogg — Life in an Elevator |
| `music_desert` | `rbxassetid://122720386196973` | desert.ogg — Dealership (60s) |
| `music_frozen` | `rbxassetid://7640700658` | frozen.ogg — Witches' Brew (133s) |
| `music_neon` | `rbxassetid://97844915150974` | neon.ogg — Rhythm Junkie (103s) |
| `ambient_grasslands` | `rbxassetid://73798751154555` | grasslands_amb.ogg — Lake |
| `ambient_desert` | `rbxassetid://9059618023` | desert_amb.ogg — Defiance_Ambiance03 |
| `ambient_frozen` | `rbxassetid://11876250716` | frozen_amb.ogg — snow |
| `ambient_neon` | `rbxassetid://2843658663` | neon_amb.ogg — City Sounds |

**Studio smoke (manual, POLA-474):** In Play Solo, visit each world (`grasslands`, `desert`, `frozen`, `neon`) and confirm music + ambient crossfade (POLA-471: ambient leads, music staggered), no missing-sound spam for these eight keys. `SoundController.setWorld` warns once per key if a slot is still `rbxassetid://0` after hydration.

### World beds — Bard alignment (Phase 4)

Use `docs/WorldAtmosphereJuiceBible.md` as the single mood reference so music + ambience match VFX color direction. When searching Splice, blend the **MANIFEST “Splice search hints”** column with the **Juice Bible** terms below (same world row).

| World | Music row above | Ambience row above | Juice Bible mood (one line) | Extra Splice keywords (from Bible) |
|-------|-----------------|----------------------|------------------------------|-------------------------------------|
| grasslands | `grasslands.ogg` | `grasslands_amb.ogg` | Friendly summer road trip; medium pollen/leaves | `summer highway`, `open road loop`, `light wind meadow`, `upbeat driving ambient` |
| desert | `desert.ogg` | `desert_amb.ogg` | Relentless sun, long straights; heat haze | `desert wind loop`, `heat shimmer drone`, `middle eastern highway`, `sand sweep` |
| frozen | `frozen.ogg` | `frozen_amb.ogg` | Cold clarity; aurora/mythic accent | `arctic wind`, `ice sparkle`, `cold drone ambient`, `blizzard gust` |
| neon | `neon.ogg` | `neon_amb.ogg` | Future-money, synth energy without HUD clutter | `cyberpunk city night`, `neon synth drone`, `rain street`, `synthwave whoosh` |

**Mix:** Keep ambience **several dB under** the music bed at default volumes; duck ambience further under SFX near wheel/traffic. Target music bed **−22 to −18 LUFS** (see `music/` table); ambience should read as texture, not a second song. After encoding from Splice WAV → OGG (`libvorbis -q:a 5`), if world-to-world loudness still feels uneven in Studio, trim gain per slot in `SoundController` defaults or normalize sources once before upload — do not chase LUFS in-repo without a metered pass in Roblox.

### POLA-298 — Splice world beds (claimed + on disk)

**Done (2026-03-22):** claimed on Splice, downloaded WAV, encoded to OGG into `music/*.ogg` and `ambient/*.ogg`. UUIDs are authoritative in the `music/` and `ambient/` tables above.

| Registry key | UUID | Source WAV (first-line hint) |
|--------------|------|------------------------------|
| `music_grasslands` | `aa4d727d2123eb05cbe710f5586d6c51a4018ad4d8fc3f62d7ddea6cd320b06a` | The Vault: Golden Soul Resampled — `AHA_TV_120_resampled_melody_loop_open_road_E` |
| `music_desert` | `ae158fa9026066e3fef772c619052401266044a262a377980d324033df9dbe0d` | Middle East Essentials — `GIO_RS_105_melodic_loop_kupuz_mandol_melody_blue_A` |
| `music_frozen` | `daf92483c4e07577cb71ecd2b47a7e66199c82eecf167505a1cc1335519f603f` | Ambient Pads — `Bpm90_C_HomeDreamin` |
| `music_neon` | `584cbb901c7b23e2693ae5fd2d45db5a1e606a4c6e92933c8562ac4115b7bb6b` | Synthetic Sunsets — `NW_SYS_135_kit_loop_royalty_full_Bbmaj` |
| `ambient_grasslands` | `50f64487bf7c59cb12b3290553a6048a1c194a3f244ec8be6284586fd1fd5a83` | Howl & Gust — `SPLC-0573_FX_Loop_Wind_Trees_Rustling` |
| `ambient_desert` | `eb8ea7761e21eaef004479dfcfaf12bac784bc2537bd612072dc41a71942ca3e` | Rohaan — `ROHAAN_112_synth_loop_desert_wind_Emin` (tonal; duck vs music if it reads as a second melody) |
| `ambient_frozen` | `1f8f8b8063d874b6c5079afe8c44d5298d3649069efb427127f226918ae773f5` | Lannavaara Piano Loops — `LPL_-_Arctic_Winds__84Bpm__c_` |
| `ambient_neon` | `ff89b7f31f9e8e5df928c3beeed07d4bbbb80385de7dfd002adb6a103ed241a6` | Funk & Disco Sessions — `SS_DFS3_105_fx_nights_city_ambience` |

---

## `driving/` — gameplay (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `screech.ogg` | `screech` | tire skid cartoon rubber | _pending_ | |
| `boost.ogg` | `boost` | whoosh rocket nitro layer | _pending_ | |
| `collision.ogg` | `collision` | impact bonk cartoon vehicle | _pending_ | |
| `impact_heavy.ogg` | `impact_heavy` | heavy metal crash bass slam vehicle barrier (POLA-414; high-speed) | _pending_ | Placeholder `rbxassetid://0` until upload |
| `coin_pickup.ogg` | `coin_pickup`, `currency` | coin ding sparkle short | _pending_ | `currency` shares this asset for now |
| `distance_marker.ogg` | `distance_marker` | short ping chime checkpoint | _pending_ | |
| `combo_ding.ogg` | `combo_ding` | glassy arcade reward ping, 80–120ms, bright short tail | _pending_ | Mono; **pitch ramp** at runtime (`VFXController.nearMissRecover` → `SoundFacade.playOneShot`); see **POLA-668** below |
| `lap_horn.ogg` | `lap_horn` | horn celebratory brass lap | _pending_ | Legacy; `VFXController` prefers `lap_complete` then falls back here |
| `checkpoint_pass.ogg` | `checkpoint_pass` | tight whoosh stripe when crossing a sector checkpoint | _pending_ | Placeholder `rbxassetid://0` until upload; reserved for future sector splits |
| `objective_ping.ogg` | `objective_ping` | soft short ping when tutorial onboarding advances to a new step (debounced; POLA-407) | _pending_ | Placeholder `rbxassetid://0`; falls back to `notification` until upload |
| `lap_complete.ogg` | `lap_complete` | compact lap-finish fanfare (non-PB lane) | _pending_ | Placeholder OK; `playOneShotPrefer({lap_complete, lap_horn})` |
| `race_finish_fanfare.ogg` | `race_finish_fanfare` | podium / finish-line brass+whoosh sting (POLA-452; preferred over `lap_complete`) | _pending_ | Placeholder `rbxassetid://0`; `VFXController.lapFlash` uses `playOneShotPrefer({race_finish_fanfare, lap_complete, lap_horn})` |
| `horn_short.ogg` | `horn_short` | car horn honk one-shot 80–200ms cartoon | _pending_ | Player horn press; placeholder `rbxassetid://0` until upload (POLA-425) |
| `horn_repeat.ogg` | `horn_repeat` | same horn timbre, loop-friendly tail or short re-honk | _pending_ | Hold-to-honk repeat at 2/s max; can alias `horn_short` in Studio |
| `rev_limiter.ogg` | `rev_limiter` | short metallic buzz / limiter tick loop 0.1–0.25s seam | _pending_ | POLA-438; `DrivingHUD` + `SoundFacade.playLoop` when speed ≥ ~86% of run cap; placeholder `rbxassetid://0` |
| `vehicle_reset.ogg` | `vehicle_reset` | short service “clamp” / hydraulic lift chuff when a manual recover fires | _pending_ | POLA-442; registry only — no shipped flip/reset UI yet; car stays upright via `DrivingController` frame loop |
| `handbrake_on.ogg` | `handbrake_on` | short e-brake pull / hydraulic bite (80–180ms) | _pending_ | POLA-457 cosmetic engage; no physics; placeholder `rbxassetid://0` in `SoundController` |
| `handbrake_off.ogg` | `handbrake_off` | soft release / rack return | _pending_ | POLA-457; pairs with `handbrake_on`; placeholder `rbxassetid://0` |

### POLA-668 — Near-miss combo ding (`combo_ding`)

**Trigger:** `VFXController.nearMissRecover` when `streak >= 5` (lane near-miss recovery combo).

**Locked audio spec (aligned with `NearMissComboRewardDesignSpec` / `DrivingVFXDesignSpec`):**

| Aspect | Choice |
|--------|--------|
| **Timbre** | Short glassy/pluck arcade “reward tick” (~80–120 ms), mono, minimal overlap with engine/road bed. |
| **Pitch ramp** | `SoundFacade.playOneShot("combo_ding", pitch)` — `pitch` scales with streak (higher combo = higher `PlaybackSpeed`, clamped 0.5–2 in `SoundController`). |
| **Layering** | **Future-only:** optional second sparkle/saturation layer at very high streaks; ship as a single one-shot until a second asset or composite sequence is approved. |
| **Duck / mix** | Routed on **duckBus** with other gameplay SFX (not `uiBus`); respects modal duck when menus/payouts open. Keep perceived level below simultaneous `coin_pickup` / `collision` spikes so it reads as “reward tick,” not a second horn. |

**Defaults:** `SoundController.registerDefaults` uses `rbxassetid://9554965517` (blinky) until `driving/combo_ding.ogg` is sourced and uploaded; `hydrateFromReplicatedStorageAudio()` overrides when `ReplicatedStorage.Audio` contains a `Sound` named `combo_ding`.

---

## `fuel/` — warnings (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `warning_25.ogg` | `fuel_warning_25` | soft digital beep bloop 60–120ms | _pending_ | Repeat every 3–4 s in gameplay |
| `warning_10.ogg` | `fuel_warning_10` | faster beep UI alarm gentle | _pending_ | ~1 beep / 1.0–1.2 s |
| `warning_5.ogg` | `fuel_warning_5` | two-tone siren light cartoon | _pending_ | ~0.5–0.7 s cycle |
| `low_warn_chirp.ogg` | `fuel_low_warn` | soft UI chirp ~80–140ms; DrivingHUD periodic warn while 5–20% | _pending_ | Max once / 8s in code |
| `empty_stall.ogg` | `fuel_empty` | engine sputter fail sting | _pending_ | One-shot stall |

---

## Files on disk (regenerated by script)

Run from `Audio/`:

`python generate_placeholders.py`

Categories: `engines/`, `ui/`, `hatch/`, `rebirth/`, `music/`, `driving/`, `fuel/`, `ambient/` — **41** OGG placeholders total.
