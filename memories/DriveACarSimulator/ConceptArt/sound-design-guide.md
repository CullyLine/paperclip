# Drive a Car Simulator — Sound Design Guide

**Game:** Drive a Car Simulator (Roblox)  
**Document purpose:** Single source of truth for audio direction, asset briefs, mixing hierarchy, and implementation notes.  
**Last updated:** March 2026  

---

## Table of Contents

1. [Audio Design Philosophy](#1-audio-design-philosophy)
2. [Engine Sounds](#2-engine-sounds)
3. [UI Sounds](#3-ui-sounds)
4. [Egg Hatch Sounds](#4-egg-hatch-sounds)
5. [Rebirth Fanfare](#5-rebirth-fanfare)
6. [Ambient World Music](#6-ambient-world-music)
7. [Gas / Fuel Warning](#7-gas--fuel-warning)
8. [Driving SFX](#8-driving-sfx)
9. [Technical Specs](#9-technical-specs)

---

## 1. Audio Design Philosophy

### Creative pillars

| Pillar | Meaning in practice |
|--------|---------------------|
| **Cartoon** | Exaggerated transients, playful pitch bends, short tails — never muddy or grim. |
| **Bright** | Emphasis on mid/high presence; avoid dark, muffled mixes for core feedback. |
| **Rewarding** | Every meaningful action (purchase, hatch, rebirth, lap, pickup) gets a clear, pleasurable sonic payoff. |

### Feedback coverage

- **Every action has audio:** If the player can see a state change, they should hear it unless they have SFX muted. Silent failures feel like bugs.
- **Layering:** Combine a short **transient** (click, pop, impact) with a **tonal** layer (chime, chord) for purchases and rare rewards so they read on phone speakers.
- **Readability over realism:** Prefer stylized, iconic sounds over hyper-realistic car audio if realism hurts clarity on mobile.

### Mobile-friendly delivery

| Concern | Guideline |
|---------|-----------|
| **Bandwidth / memory** | Prefer **short loops** and **one-shots**; avoid huge multi-minute stems unless streamed intentionally. |
| **Small speakers** | Boost **2–5 kHz** presence on UI and reward sounds; keep sub-bass **felt** as short hits, not long drones. |
| **Clarity** | Mono or narrow stereo for UI; avoid wide stereo SFX that collapse badly on a single phone speaker. |
| **Compression** | Use **OGG Vorbis** (Roblox-friendly) with sensible bitrates (see [Technical Specs](#9-technical-specs)). |
| **Dynamic range** | Controlled but not flat — peaks for rewards; avoid constant loudness that causes ear fatigue. |

### Mix philosophy summary

**SFX and gameplay feedback first, UI second, music as bed.** Music should never obscure fuel warnings, collisions, or hatch fanfares. Duck music under high-priority events (see [§9](#9-technical-specs)).

---

## 2. Engine Sounds

Engines are the **primary continuous gameplay sound**. Each tier should be instantly recognizable at idle and under load.

### Global engine rules

- **Looping:** Seamless idle loop + separate acceleration layers OR RPM-blended loop sets.
- **Pitch:** Tie pitch to speed/RPM with a **musical but not cartoon-wobbly** curve; cap extreme high pitch to prevent harshness on phones.
- **Spatial:** Car-local 3D sound with distance falloff; avoid world-reverb on engine unless stylistically required.

### Per-tier character

| Tier | Character | Timbre & texture | Pitch center (idle) | Pitch motion | Duration / loop | Relative level (vs sedan idle) |
|------|-----------|------------------|---------------------|--------------|-----------------|--------------------------------|
| **Buggy / Starter** | Puttering, small, wheezy | Thin cylinder, slight rattle, exhaust buzz | Mid-high (~180–280 Hz fundamental feel) | Small range; “busy” idle | 3–6 s seamless idle loop | **−3 to −6 dB** (quieter, less authoritative) |
| **Sedan** | Smooth, moderate hum | Balanced mids, soft exhaust | Mid (~150–220 Hz feel) | Moderate sweep | 4–8 s loop | **0 dB** (reference) |
| **Racer** | Aggressive growl, sharp accel | Sharper transients, metallic edge on high RPM | Low-mid growl (~120–200 Hz) + strong harmonics | Wide sweep; snappy attacks | 4–8 s loop + accel layer | **+1 to +3 dB** |
| **Supercar** | Roar, deep bass, dramatic | Rich lows, controlled highs, cinematic body | Deep low-mid (~90–160 Hz feel) + airy top | Wide, dramatic; subtle stereo width | 4–10 s loop + optional “hero” layer | **+2 to +4 dB** (use sparingly to avoid fatigue) |

### Layering suggestion (implementation-friendly)

| Layer | Buggy | Sedan | Racer | Supercar |
|-------|-------|-------|-------|----------|
| **Idle base** | ✓ thin | ✓ smooth | ✓ growly | ✓ deep |
| **Accel overlay** | light rasp | mild air | strong rasp | sub punch + air |
| **Off-throttle** | small pops optional | soft woosh | quick burble | dramatic overrun (subtle) |

### Shift / gear (optional polish)

- Short **“chunk”** or **swoosh** (80–200 ms) on upshift for racer/supercar; softer or absent for buggy/sedan to keep starter friendly.

---

## 3. UI Sounds

UI must be **soft, non-fatiguing**, and **distinct** per outcome. Keep attack times short; tails short-to-medium.

### Core UI library

| Event | Sound character | Pitch | Duration | Level (LUFS-style peak target) | Notes |
|-------|-----------------|-------|----------|----------------------------------|-------|
| **Button click** | Soft pop / bubble tick | Slight upward bias (+2 to +5 st from baseline) | 40–90 ms | **−18 to −14 dBFS peak** | No harsh click; mono. |
| **Purchase success** | Cash-register **cha-ching** + tiny sparkle | Bright, major-ish | 0.6–1.4 s | **−14 to −10 dBFS peak** | Two-part: register + coin shimmer tail. |
| **Purchase fail** | Error buzz / soft reject | Flat, slightly low | 0.25–0.5 s | **−16 to −12 dBFS peak** | Avoid alarming; “friendly no.” |
| **Tab switch** | Subtle whoosh / airy swipe | Neutral to +1 st | 120–220 ms | **−20 to −16 dBFS peak** | Very quiet; should not compete with music. |
| **Panel open** | Slide / airy swoosh in | Upward motion +1 to +3 st | 200–350 ms | **−17 to −13 dBFS peak** | Slight rise in pitch. |
| **Panel close** | Reverse swoosh / soft suck | Downward −1 to −3 st | 180–300 ms | **−18 to −14 dBFS peak** | Mirror open; lower energy. |
| **Notification** | Bright ding | High, clear (~1–3 kHz emphasis) | 0.15–0.35 s | **−15 to −11 dBFS peak** | One clean strike; optional tiny tail. |
| **Level up** | Ascending chime (3–5 notes) | Upward arpeggio +2 to +8 st total | 1.0–2.0 s | **−12 to −8 dBFS peak** | Add soft sparkle layer; celebratory, not shrill. |

### Currency-specific coloration (optional)

| Currency | Layer idea |
|----------|------------|
| **Coins** | Brassier ching, light shake |
| **Gems** | Glassy tick + shimmer |
| **Crystals** | Icy tick + short sparkle |
| **Skulls** | Slightly darker wood/block + tiny echo (still friendly, not horror) |

---

## 4. Egg Hatch Sounds

Map **egg type** to **world flavor** in ambient bed layers; map **rarity** to **reward intensity**. Always structure as: **anticipation → reveal → stamp rarity**.

### Rarity ladder (primary hatch read)

| Rarity | Character | Layers | Pitch | Duration | Level (peak) |
|--------|-----------|--------|-------|----------|--------------|
| **Common** | Simple pop, soft jingle | Pop + tiny major third jingle | Mid-high | 0.5–1.0 s | **−16 to −12 dBFS** |
| **Uncommon** | Gentle chime + sparkle | Chime pair + sparkle grain | Upward +2 to +4 st | 0.8–1.4 s | **−14 to −10 dBFS** |
| **Rare** | Rising chime sequence + swoosh | 3-note rise + short whoosh | +3 to +7 st sweep | 1.2–2.0 s | **−12 to −8 dBFS** |
| **Epic** | Dramatic chord + whoosh + impact | Pad stab + whoosh + low thump | Wide; low chord root ~80–150 Hz feel | 1.8–3.0 s | **−10 to −6 dBFS** |
| **Legendary** | Orchestral hit + crowd cheer + fanfare | Brass+strings staccato + crowd + short fanfare motif | Heroic; strong mid brass | 3.0–4.5 s | **−8 to −4 dBFS** |
| **Mythic** | Thunder crack + angelic choir + bass drop + full fanfare | Sub-drop + choir pad + thunder transient + brass | Very wide; controlled sub | 4.0–6.5 s | **−6 to −3 dBFS** (momentary) |

### Egg type ambient accents (secondary)

Blend **under** the rarity sting at **−18 to −12 dBFS** so type reads but rarity dominates.

| Egg type | Accent character | Suggested elements |
|----------|-------------------|---------------------|
| **Meadow** | Light breeze, birds (very subtle) | Soft wood tick, floral shimmer |
| **Grass** | Bright grass rustle | Fresh sparkle, daytime air |
| **Desert** | Dry sand, faint heat shimmer | Soft rattles, distant string pluck |
| **Scorching** | Hot sizzle, bolder desert | Low heat haze, bigger whoosh |
| **Frozen** | Ice tick, crystalline glint | Music-box fragment, airy pad |
| **Neon** | Digital blip, synth ping | Short arp, neon zap |

### Hatch flow timing

1. **Anticipation:** 0.3–0.8 s (rising tone or egg shake loop at low level).  
2. **Crack:** 0.1–0.3 s transient.  
3. **Reveal sting:** per rarity table.  
4. **Resolve:** 0.2–0.5 s tail or ambient fade.

---

## 5. Rebirth Fanfare

Rebirth is a **major milestone** — longer than a normal UI success, shorter than Mythic hatch overload.

### Layered sequence

| Phase | Sound | Character | Duration | Level (peak) |
|-------|-------|-----------|----------|--------------|
| **1. Ascending triumphant** | Brass/string riser or heroic arpeggio | Bright, hopeful | 1.0–2.0 s | **−10 to −6 dBFS** |
| **2. Golden energy whoosh** | Shimmering sweep + golden noise | Wide but mono-compatible | 0.4–0.8 s | **−8 to −5 dBFS** |
| **3. Shockwave boom** | Short low thump + air | Sub punch, tight | 0.25–0.45 s | **−6 to −3 dBFS** |
| **4. Celebration / confetti** | Paper rustle + tiny bells + crowd “yay” bed | Playful, not noisy | 1.0–2.5 s | **−12 to −8 dBFS** |

### Pitch & tonality

- Overall **major / heroic**; avoid dissonant clusters except as brief passing tones in the riser.
- **Golden whoosh:** center motion upward **+3 to +8 st** across the sweep.

### UX rules

- Trigger **once per rebirth**; allow **SFX cooldown** so players cannot spam overlapping fanfares.
- Duck music **−4 to −8 dB** for full sequence duration.

---

## 6. Ambient World Music

Music is **looping bed**, not the star. Target loudness **below** driving SFX priority events; see [§9](#9-technical-specs).

### Per-world direction

| World | Mood | Genre / palette | BPM | Key / mode suggestions | Loop length | Level (integrated bed) |
|-------|------|-----------------|-----|-------------------------|-------------|-------------------------|
| **Grasslands** (starter) | Cheerful, “first day of summer” | Bright acoustic + light synth; ukulele/pluck optional | **120** | G / D major; simple I–V–vi–IV variations | 32–64 bars | **−24 to −18 LUFS integrated** (approx bed) |
| **Scorching Desert** | Mysterious, atmospheric | Middle Eastern / Arabic-influenced scales, hand percussion | **100** | Hijaz / minor with bright top melody | 32–64 bars | **−26 to −20 LUFS integrated** |
| **Frozen Tundra** | Ethereal, crystalline | Ambient pads, wind, **music-box** motif, sparse piano | **90** | Minor / Dorian; lots of space | 32–48 bars | **−28 to −22 LUFS integrated** |
| **Neon City** | Retro-future, energetic | Synthwave; pulsing bass, arps, neon leads | **130** | Minor pentatonic + chromatic passes | 16–32 bars | **−22 to −18 LUFS integrated** |

### Arrangement density

| World | Bass | Percussion | Lead |
|-------|------|------------|------|
| Grasslands | Light; bouncy | Claps/shaker | Simple melodic hook |
| Desert | Soft; round | Frame drum, light snaps | Ney-like synth or violin lead |
| Tundra | Very soft sub | Minimal; ice-like hats | Music box + pad |
| Neon City | Pulsing sidechain feel | Drum machine | Saw leads, arps |

### Transitions

- **Crossfade 2–4 s** between world tracks when changing zones.
- Avoid **vocals** in base loops (licensing + clarity); if used, keep wordless and sparse.

---

## 7. Gas / Fuel Warning

Fuel warnings are **functional alarms** — must cut through music but remain **cartoon-safe** (not anxiety-inducing for young players).

### Tiered alert behavior

| Fuel % | Alert type | Character | Rate / rhythm | Pitch | Duration per beep | Level (peak) |
|--------|------------|-----------|---------------|-------|-------------------|--------------|
| **≤ 25%** | Subtle reminder | Soft digital beep or gentle bloop | **Once every 3–4 s** | Mid-high (~800–1.5 kHz) | 60–120 ms | **−18 to −14 dBFS** |
| **≤ 10%** | Faster warning | Same timbre, slightly brighter | **~1 beep / 1.0–1.2 s** | +1 st vs 25% | 70–130 ms | **−16 to −12 dBFS** |
| **≤ 5%** | Urgent alarm | Short siren-like two-tone (still non-grating) | **~1 cycle / 0.5–0.7 s** | Alternating minor third | 40–80 ms per blip | **−14 to −10 dBFS** |
| **Empty / stall** | Engine sputter + fail sting | Coughing sputter + soft “uh-oh” thud | One-shot | Pitch drops −3 to −7 st | 0.8–1.8 s total | **−12 to −8 dBFS** |

### Implementation notes

- **Hysteresis:** Don’t flicker alerts at boundary; use **1–2%** buffer when crossing thresholds.
- **Cooldown:** At 25%, do not stack with 10% simultaneously — escalate **replace** sounds by tier.
- **Ducking:** When 5% alarm plays, duck music **−3 to −6 dB**; duck other non-critical SFX slightly.

---

## 8. Driving SFX

Highway driving needs **continuous readability**: speed, danger, collection, and progress.

### Core driving one-shots

| Event | Character | Pitch / motion | Duration | Level (peak) |
|-------|-----------|----------------|----------|--------------|
| **Tire screech** | Cartoon rubber skid | Rising then falling; bright noise band | 0.3–1.2 s | **−14 to −10 dBFS** |
| **Boost activation** | Whoosh + subtle rocket-y tail | Upward +2 to +5 st | 0.4–0.9 s | **−12 to −8 dBFS** |
| **Collision impact** | Soft bonk + glassy clack (light); heavier thump (big hit) | Downward thud for heavy | 0.1–0.4 s (light), 0.3–0.8 s (heavy) | Light **−16 to −12**; Heavy **−10 to −6** |
| **Coin pickup** | Crisp ding + tiny sparkle | High ~1–3 kHz | 0.1–0.25 s | **−15 to −11 dBFS** |
| **Distance marker** | Short chime / ping | Neutral to +2 st | 0.08–0.18 s | **−18 to −14 dBFS** |
| **Lap completion** | Horn + celebratory blip | Brass horn root; optional fifth | 0.4–1.0 s | **−12 to −8 dBFS** |

### Variation

- **Speed tiers:** Slightly **shorter** screech and **brighter** boost at higher speed; avoid extra loudness — use brightness instead.
- **Coin streak:** If collecting rapidly, use **pitch round-robin** (+0, +2, +4 st) to avoid machine-gun repetition.

---

## 9. Technical Specs

### Format & delivery

| Asset type | Format | Notes |
|------------|--------|-------|
| **Music loops** | **OGG** (preferred in Roblox) | Stereo OK; watch phase on mono downmix. |
| **SFX / UI** | **OGG** or **WAV** short files | Mono preferred for UI and most gameplay one-shots. |
| **Engine** | **OGG** loops + optional WAV layers | Pre-test loop seam at multiple playback speeds if pitch-shifted. |

### Suggested compression (starting points)

| Content | Bitrate | Comment |
|---------|---------|---------|
| Music bed | **96–128 kbps** Vorbis | Adjust by density; synthwave may tolerate lower than full orchestra. |
| Rich SFX (hatch, rebirth) | **96–128 kbps** | If artifacts on choirs/brass, raise slightly. |
| Simple UI | **64–96 kbps** | Short files; prioritize clarity of transient. |

### Loop points (music)

- Prefer **zero-crossing** loop points; **fade 10–30 ms** at seam if needed to kill clicks.
- Loop on **bar boundaries**; document BPM and **loop length in bars** in asset filename/metadata.

### Loop points (engine)

- Mark **loop region** in ms; verify at **min / mid / max** RPM if using pitch shifting.
- Keep idle loop **steady**; avoid audible phasing when layering with accel.

### Volume hierarchy (priority)

| Rank | Category | Typical playback level (relative) |
|------|----------|-----------------------------------|
| 1 | **Critical warnings** (5% fuel, empty stall) | Loudest functional layer |
| 2 | **High-reward moments** (Legendary/Mythic hatch, rebirth) | High peak, short duration |
| 3 | **Gameplay SFX** (collision, boost, horn) | Strong, clear |
| 4 | **UI** | Moderate; never buried |
| 5 | **Ambient bed / music** | Lowest sustained layer |

**Rule of thumb:** **SFX > UI > Music** for *instant* feedback; **Music** is always the **bed** unless in a menu-only context (optional slight music lift when no vehicle engine is playing).

### Ducking rules

| Trigger | Music duck | Duration |
|---------|------------|----------|
| Hatch reveal (Rare+) | −4 to −8 dB | 2–6 s |
| Rebirth fanfare | −6 to −10 dB | Full sequence |
| Fuel 5% alarm | −3 to −6 dB | While alarm active |
| Panel open (settings shop) | 0 to −3 dB | Optional; only if music fights UI |

### Mix targets (practical)

| Bus | Integrated loudness (approx) | Notes |
|-----|------------------------------|-------|
| Music | **−22 to −18 LUFS** | Steady; sidechain lightly to ducking events if needed |
| SFX | Peaks **−12 to −6 dBFS** for biggest hits | Control Mythic / rebirth peaks |
| UI | Peaks **−18 to −8 dBFS** | Level-up and success can peak higher briefly |

### Roblox implementation checklist

- Use **SoundGroups** for Music / SFX / UI with the hierarchy above.
- **Respect mute** toggles: separate groups so players can lower music without losing warnings (or offer “music only” / “SFX only”).
- **Debounce** overlapping stings (especially hatch and rebirth).
- **Distance model** for world SFX; **2D** for UI.

---

## Appendix — Quick reference card

| System | Key idea |
|--------|----------|
| Engines | Tier = authority & pitch range; buggy light, supercar deep. |
| UI | Soft pops; success = cha-ching; fail = gentle buzz. |
| Hatches | Rarity drives duration & drama; egg type = subtle flavor. |
| Rebirth | Riser → golden whoosh → boom → confetti. |
| Worlds | Grasslands 120; Desert 100; Tundra 90; Neon 130 BPM. |
| Fuel | Intermittent → faster → alarm → sputter. |
| Mix | Gameplay first; duck music for big stings and alarms. |

---

*End of sound design guide.*
