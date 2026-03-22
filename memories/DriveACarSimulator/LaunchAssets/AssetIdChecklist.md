# Drive a Car Simulator — Asset-ID Mapping Manifest

Every `rbxassetid://0` placeholder in the codebase, mapped to a human-readable description and suggested filename for Board upload.

> **Workflow:** Board creates/selects assets → uploads to Roblox → copies numeric `rbxassetid://` IDs → Engineer wires IDs into code (POLA-95).

---

## 1. Currency Icons (Constants.luau)

**File:** `DACReplicatedStorage/Constants.luau` lines 36–39

| Code Slot | Currency | Color | Suggested Filename | Asset Description |
|-----------|----------|-------|--------------------|-------------------|
| `CURRENCY_DISPLAY.coins.icon` | Coins | Gold `(255,200,50)` | `icon_coins.png` | Shiny gold coin, front-facing, subtle shine/sparkle. 128×128 transparent PNG. |
| `CURRENCY_DISPLAY.gems.icon` | Gems | Purple `(200,100,255)` | `icon_gems.png` | Faceted purple gem, slight glow, premium feel. 128×128 transparent PNG. |
| `CURRENCY_DISPLAY.crystals.icon` | Crystals | Orange `(255,120,50)` | `icon_crystals.png` | Angular orange crystal shard, warm glow. 128×128 transparent PNG. |
| `CURRENCY_DISPLAY.skulls.icon` | Skulls | Blue `(80,180,255)` | `icon_skulls.png` | Stylised skull token, cool blue, rebirth-tier aesthetic. 128×128 transparent PNG. |

**Upload to:** `ReplicatedStorage.Images` (as Decal or ImageLabel children).

---

## 2. Sound Assets (SoundController.luau)

**File:** `DACStarterPlayerScripts/Controllers/SoundController.luau` lines 293–344
**Full manifest:** [`Audio/MANIFEST.md`](../Audio/MANIFEST.md) — contains per-file Splice search hints, bitrate guidance, and upload notes.

`SoundController.hydrateFromReplicatedStorageAudio()` reads `ReplicatedStorage.Audio` at init and overwrites `rbxassetid://0` placeholders automatically. The Sound's `Name` must match the registry key (or have an alias in `AUDIO_NAME_ALIASES`).

### 2a. Engine Loops (4 slots)

| Registry Key | Suggested Filename | Description |
|--------------|-------------------|-------------|
| `engine_buggy` | `engines/buggy_idle.ogg` | Small wheezy engine loop, 3–6s |
| `engine_sedan` | `engines/sedan_idle.ogg` | Smooth car idle hum, 4–8s |
| `engine_racer` | `engines/racer_idle.ogg` | Aggressive sport growl, 4–8s |
| `engine_supercar` | `engines/supercar_idle.ogg` | Deep cinematic engine, 4–10s |

### 2b. UI Sounds (8 slots)

| Registry Key | Suggested Filename | Description |
|--------------|-------------------|-------------|
| `click` | `ui/click.ogg` | Soft pop/bubble, 40–90ms |
| `purchase` | `ui/purchase_success.ogg` | Cha-ching sparkle, 0.6–1.4s |
| `purchase_fail` | `ui/purchase_fail.ogg` | Soft error buzz, 0.25–0.5s |
| `tab_switch` | `ui/tab_switch.ogg` | Subtle whoosh swipe, 120–220ms |
| `panel_open` | `ui/panel_open.ogg` | Airy swoosh up, 200–350ms |
| `panel_close` | `ui/panel_close.ogg` | Reverse swoosh, 180–300ms |
| `notification` | `ui/notification.ogg` | Bright ding, 0.15–0.35s |
| `level_up` | `ui/level_up.ogg` | Ascending chime arpeggio, 1–2s |

### 2c. Egg Hatch Rarity (6 slots)

| Registry Key | Suggested Filename | Description |
|--------------|-------------------|-------------|
| `hatch` / `hatch_common` | `hatch/common.ogg` | Cute pop jingle, 0.5–1s |
| `hatch_uncommon` | `hatch/uncommon.ogg` | Gentle chime sparkle, 0.8–1.4s |
| `hatch_rare` | `hatch/rare.ogg` | Rising chime swoosh, 1.2–2s |
| `hatch_epic` | `hatch/epic.ogg` | Dramatic sting impact, 1.8–3s |
| `hatch_legendary` | `hatch/legendary.ogg` | Orchestral fanfare, 3–4.5s |
| `hatch_mythic` | `hatch/mythic.ogg` | Thunder choir bass drop, 4–6.5s |

### 2d. Rebirth Layers (4 slots)

| Registry Key | Suggested Filename | Description |
|--------------|-------------------|-------------|
| `rebirth` / `rebirth_riser` | `rebirth/riser.ogg` | Brass/string riser, 1–2s |
| `rebirth_whoosh` | `rebirth/whoosh.ogg` | Golden shimmer sweep, 0.4–0.8s |
| `rebirth_boom` | `rebirth/boom.ogg` | Sub impact thump, 0.25–0.45s |
| `rebirth_confetti` | `rebirth/confetti.ogg` | Celebration bells/crowd, 1–2.5s |

### 2e. World Music (4 slots)

| Registry Key | Suggested Filename | Description |
|--------------|-------------------|-------------|
| `music_grasslands` | `music/grasslands.ogg` | Acoustic bright loop, ~120 BPM G major |
| `music_desert` | `music/desert.ogg` | Middle eastern loop, ~100 BPM hijaz |
| `music_frozen` | `music/frozen.ogg` | Ambient pad/music box, ~90 BPM |
| `music_neon` | `music/neon.ogg` | Synthwave loop, ~130 BPM minor pentatonic |

### 2f. World Ambience (4 slots)

| Registry Key | Suggested Filename | Description |
|--------------|-------------------|-------------|
| `ambient_grasslands` | `ambient/grasslands_amb.ogg` | Nature breeze foley bed |
| `ambient_desert` | `ambient/desert_amb.ogg` | Desert wind heat |
| `ambient_frozen` | `ambient/frozen_amb.ogg` | Wind crystalline air |
| `ambient_neon` | `ambient/neon_amb.ogg` | City night hum neon |

### 2g. Driving SFX (6 slots)

| Registry Key | Suggested Filename | Description |
|--------------|-------------------|-------------|
| `screech` | `driving/screech.ogg` | Tire skid cartoon rubber |
| `boost` | `driving/boost.ogg` | Whoosh rocket nitro |
| `collision` | `driving/collision.ogg` | Impact bonk cartoon |
| `coin_pickup` / `currency` | `driving/coin_pickup.ogg` | Coin ding sparkle short |
| `distance_marker` | `driving/distance_marker.ogg` | Short ping checkpoint |
| `lap_horn` | `driving/lap_horn.ogg` | Horn celebratory brass |

### 2h. Fuel Warnings (4 slots)

| Registry Key | Suggested Filename | Description |
|--------------|-------------------|-------------|
| `fuel_warning_25` | `fuel/warning_25.ogg` | Soft digital beep, 60–120ms |
| `fuel_warning_10` | `fuel/warning_10.ogg` | Faster beep alarm |
| `fuel_warning_5` | `fuel/warning_5.ogg` | Two-tone siren light |
| `fuel_empty` | `fuel/empty_stall.ogg` | Engine sputter fail sting |

**Sound total: 40 placeholder slots** (all documented in `Audio/MANIFEST.md`).

---

## 3. Easter Egg Images (EasterEggConfig.luau)

**File:** `DACReplicatedStorage/Config/EasterEggConfig.luau`

Runtime resolution: `EasterEggService` looks up `imageKey` in `ReplicatedStorage.Images`. If a matching child exists, its asset ID overwrites `imageId`. Until Board populates `ReplicatedStorage.Images`, all 24 slots show nothing.

### 3a. World Placements (20 slots)

| Slot ID | World | Display | Description | Suggested Filename |
|---------|-------|---------|-------------|--------------------|
| `grass_1` | Grasslands | poster | Founding-era logo / studio branding at first bend | `easter_grass1_logo.png` |
| `grass_2` | Grasslands | framed | Tiny character avatar portrait on guardrail | `easter_grass2_avatar.png` |
| `grass_3` | Grasslands | decal | Meme / in-joke, visible only at walking speed | `easter_grass3_meme.png` |
| `grass_4` | Grasslands | billboard | Landscape / scenic art above treeline | `easter_grass4_landscape.png` |
| `grass_5` | Grasslands | poster | Abstract / artistic piece behind start-area outcrop | `easter_grass5_abstract.png` |
| `desert_1` | Desert | billboard | Promo splash / game thumbnail mirage billboard | `easter_desert1_promo.png` |
| `desert_2` | Desert | poster | Character / avatar portrait on sun-bleached rock | `easter_desert2_avatar.png` |
| `desert_3` | Desert | decal | Logo / watermark on concrete divider | `easter_desert3_logo.png` |
| `desert_4` | Desert | framed | Personal / sentimental piece on rusted panel | `easter_desert4_personal.png` |
| `desert_5` | Desert | billboard | Landscape / scene render past dunes | `easter_desert5_landscape.png` |
| `frozen_1` | Frozen | poster | Splash image / old game thumbnail on icy cliff | `easter_frozen1_splash.png` |
| `frozen_2` | Frozen | framed | Character portrait on guard rail column | `easter_frozen2_avatar.png` |
| `frozen_3` | Frozen | decal | Meme / in-joke on frozen asphalt | `easter_frozen3_meme.png` |
| `frozen_4` | Frozen | billboard | Studio branding / logo over blue overpass | `easter_frozen4_logo.png` |
| `frozen_5` | Frozen | poster | Abstract / artistic piece behind ice shelf | `easter_frozen5_abstract.png` |
| `neon_1` | Neon | billboard | Promo / flashy splash art, largest in game (240×140) | `easter_neon1_promo.png` |
| `neon_2` | Neon | poster | Character / OC art in alleyway | `easter_neon2_character.png` |
| `neon_3` | Neon | decal | Logo / abstract art on street lane divider | `easter_neon3_logo.png` |
| `neon_4` | Neon | framed | Most personal image, rooftop nook (hardest to find) | `easter_neon4_personal.png` |
| `neon_5` | Neon | billboard | Landscape / scenic piece at massive scale (260×130) | `easter_neon5_landscape.png` |

### 3b. Secret Gallery Frames (4 slots)

| Slot ID | Wall | Description | Suggested Filename |
|---------|------|-------------|--------------------|
| `gallery_north` | North | Founder collage — most iconic Board/Stylxus image | `gallery_north_founder.png` |
| `gallery_south` | South | Stylxus tribute — Stylxus-created or joint piece | `gallery_south_stylxus.png` |
| `gallery_east` | East | Legacy splash — old game thumbnail from a past project | `gallery_east_legacy.png` |
| `gallery_west` | West | Studio in-joke — the funniest image in the library | `gallery_west_joke.png` |

### 3c. Loading Screen Splash Images (4 empty slots)

**File:** `DACReplicatedStorage/Config/EasterEggConfig.luau` line 331  
**Consumer:** `DACReplicatedFirst/LoadingScreen.local.luau` — picks one at random.

`EasterEggConfig.LoadingScreenImages` is currently an empty table `{}`. Board should populate it with 3–4 `rbxassetid://` strings once images are uploaded.

| Slot | Content Type | Suggested Filename | Notes |
|------|--------------|--------------------|-------|
| 1 | Landscape / Scene | `loading_landscape.png` | Sets visual tone. High-res, landscape-oriented. |
| 2 | Logo / Branding | `loading_logo.png` | Studio identity. Clean on dark background. |
| 3 | Character / Avatar | `loading_character.png` | Personal feel. |
| 4 | Artistic / Abstract | `loading_abstract.png` | Eye candy while waiting. |

---

## 4. Game Page & HUD Thumbnails (PreLaunchChecklist.md)

These are not `rbxassetid://0` code slots — they are external uploads to the Roblox Creator Dashboard and game page. Listed here for completeness.

| Asset | Dimensions | Suggested Filename | Description |
|-------|------------|--------------------|-------------|
| Game Icon | 512×512 | `gameicon_speed_pets.png` | Radial gradient, hero car, 2–3 orbiting pets, coin shower. Must read at 50×50px. |
| Thumbnail 1 | 1920×1080 | `thumb_gameplay_action.png` | Gameplay action shot — car racing on highway. |
| Thumbnail 2 | 1920×1080 | `thumb_feature_grid.png` | Feature grid showcase — cars, pets, eggs, worlds. |
| Thumbnail 3 | 1920×1080 | `thumb_rare_pet_chase.png` | Rare pet chase — Cosmic Whale or Golden Dragon reveal. |
| Thumbnail 4 | 1920×1080 | `thumb_stylxus_social.png` | Stylxus social proof (pending Stylxus approval). |
| Thumbnail 5 (backup) | 1920×1080 | `thumb_update_badge.png` | Update badge — fallback if Stylxus thumbnail isn't ready. |

---

## Summary

| Category | Slot Count | Status |
|----------|-----------|--------|
| Currency icons | 4 | `rbxassetid://0` — needs Board upload |
| Sound assets | 40 | `rbxassetid://0` — hydrated from `RS.Audio` at runtime; see `Audio/MANIFEST.md` |
| Easter egg images | 20 | `rbxassetid://0` — resolved via `imageKey` → `RS.Images` at runtime |
| Gallery frames | 4 | `rbxassetid://0` — same resolution path as easter eggs |
| Loading screen splashes | 4 (empty) | Table empty — Board adds `rbxassetid://` strings |
| Game page / thumbnails | 6 | External Creator Dashboard uploads |
| **Total** | **78** | |

---

*This manifest does not replace POLA-95 (Engineer wires numeric IDs once Board creates products). It maps every placeholder slot so the Board knows exactly what to prepare and upload.*
