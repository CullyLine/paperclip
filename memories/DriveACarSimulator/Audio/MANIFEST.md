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

> The Splice CLI referenced in the project skill was not present in this workspace; **Splice sample UUID** columns are left for you to fill after claiming.

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

---

## `ui/` — interface (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `click.ogg` | `click` | UI click soft pop bubble, oneshot 40–90ms | _pending_ | Mono |
| `purchase_success.ogg` | `purchase` | cash register cha-ching sparkle, 0.6–1.4s | _pending_ | Mono |
| `purchase_fail.ogg` | `purchase_fail` | soft error buzz reject, 0.25–0.5s | _pending_ | Mono |
| `tab_switch.ogg` | `tab_switch` | UI whoosh swipe subtle, 120–220ms | _pending_ | Very quiet bed |
| `panel_open.ogg` | `panel_open` | airy swoosh up, 200–350ms | _pending_ | Mono |
| `panel_close.ogg` | `panel_close` | reverse swoosh suck, 180–300ms | _pending_ | Mono |
| `notification.ogg` | `notification` | bright ding UI, 0.15–0.35s | _pending_ | Mono |
| `level_up.ogg` | `level_up` | arpeggio chime ascend reward, 1–2s | _pending_ | Mono |

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
| `grasslands.ogg` | `music_grasslands` | loop acoustic bright 120 BPM G major | _pending_ | Stereo OK; −22 to −18 LUFS bed |
| `desert.ogg` | `music_desert` | loop middle eastern 100 BPM hijaz | _pending_ | |
| `frozen.ogg` | `music_frozen` | loop ambient pad music box 90 BPM | _pending_ | |
| `neon.ogg` | `music_neon` | loop synthwave 130 BPM minor pentatonic | _pending_ | |

---

## `ambient/` — world ambience (`ambient`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `grasslands_amb.ogg` | `ambient_grasslands` | loop nature breeze light foley bed | _pending_ | Lower than music; duck under SFX |
| `desert_amb.ogg` | `ambient_desert` | loop desert wind heat subtle | _pending_ | |
| `frozen_amb.ogg` | `ambient_frozen` | loop wind crystalline air | _pending_ | |
| `neon_amb.ogg` | `ambient_neon` | loop city night hum neon | _pending_ | |

---

## `driving/` — gameplay (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `screech.ogg` | `screech` | tire skid cartoon rubber | _pending_ | |
| `boost.ogg` | `boost` | whoosh rocket nitro layer | _pending_ | |
| `collision.ogg` | `collision` | impact bonk cartoon vehicle | _pending_ | |
| `coin_pickup.ogg` | `coin_pickup`, `currency` | coin ding sparkle short | _pending_ | `currency` shares this asset for now |
| `distance_marker.ogg` | `distance_marker` | short ping chime checkpoint | _pending_ | |
| `lap_horn.ogg` | `lap_horn` | horn celebratory brass lap | _pending_ | |

---

## `fuel/` — warnings (`sfx`)

| File | Registry key | Splice search hints | Splice sample UUID | Roblox upload notes |
|------|----------------|----------------------|--------------------|---------------------|
| `warning_25.ogg` | `fuel_warning_25` | soft digital beep bloop 60–120ms | _pending_ | Repeat every 3–4 s in gameplay |
| `warning_10.ogg` | `fuel_warning_10` | faster beep UI alarm gentle | _pending_ | ~1 beep / 1.0–1.2 s |
| `warning_5.ogg` | `fuel_warning_5` | two-tone siren light cartoon | _pending_ | ~0.5–0.7 s cycle |
| `empty_stall.ogg` | `fuel_empty` | engine sputter fail sting | _pending_ | One-shot stall |

---

## Files on disk (regenerated by script)

Run from `Audio/`:

`python generate_placeholders.py`

Categories: `engines/`, `ui/`, `hatch/`, `rebirth/`, `music/`, `driving/`, `fuel/`, `ambient/` — **40** OGG placeholders total.
