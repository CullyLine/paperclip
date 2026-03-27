# Drive a Car Simulator — Phase 4 attributions

Compliance-oriented list for **Roblox game description / store footer** and a future **in-game credits** panel.  
**Source of truth for shipped IDs:** `DACStarterPlayerScripts/Controllers/SoundController.luau` (`registerDefaults`), with optional overrides from `ReplicatedStorage.Audio` at runtime (`hydrateFromReplicatedStorageAudio`). See also `Audio/MANIFEST.md` and `LaunchAssets/AssetIdChecklist.md`.

---

## 1. Typography (fonts)

| Item | Where used | License / terms |
|------|------------|-----------------|
| **Gotham**, **GothamBold**, **GothamBlack**, **GothamMedium** (and related `Enum.Font.Gotham*`) | UI across `DACStarterGui`, controllers | **Roblox engine fonts** — distributed with the Roblox client for experiences. Use is governed by [Roblox Terms of Use](https://en.help.roblox.com/hc/en-us/articles/115001354646) and Roblox Studio rules for text rendering. |

No custom font files are bundled in this Rojo tree; all typography is Roblox’s built-in Gotham family.

---

## 2. Audio

### 2a. Splice (library samples — workflow only on disk)

| Status | Notes | Owner if TBD |
|--------|--------|----------------|
| **TBD — claimed sample UUIDs** | `Audio/MANIFEST.md` lists per-file registry keys and **Splice search hints**. Most rows still show `_pending_` for **Splice sample UUID**; POLA-298 lists **unclaimed preview candidates** for world beds/ambient only (`Audio/MANIFEST.md` §POLA-298). **Do not assert a Splice license** until a sample is **claimed** in Splice and the UUID is recorded in the manifest. | **Board** (claims + manifest updates) with **Engineer** (OGG upload to Roblox + `SoundController` / `ReplicatedStorage.Audio`). |

**Cited workflow (not a license):** `Audio/MANIFEST.md` §“Sourcing workflow” — Splice preview → claim → download WAV → encode OGG → Roblox upload. License for a given sound comes from **Splice’s license for that claimed sample** at claim time; record UUID + pack name in `Audio/MANIFEST.md` when production-ready.

### 2b. Roblox-uploaded / Roblox Library audio (shipped `rbxassetid://…`)

Shipped sounds are **non-zero** IDs in `SoundController.luau` `registerDefaults()`, with informal labels in line comments (e.g. music bed names, “Tap”, “GoldCorn”). These assets are used **inside Roblox** as uploaded sounds or Roblox-provided library content, subject to **Roblox’s rules** for audio in experiences (including Creator Marketplace / Library terms where applicable).

**This document does not assign a per-asset SPDX string** — Roblox does not expose a standard “license field” per sound ID in the way an OSS repo would. For compliance, rely on:

- Roblox’s terms for **your** uploads (you own or have rights to upload), and  
- Roblox’s terms for **Library** assets when the ID comes from the Roblox catalog.

**Engineer:** when replacing a sound, keep the comment in `SoundController.luau` aligned with the Studio asset name so credits stay traceable.

### 2c. Placeholders (`rbxassetid://0`)

Registry keys still at `0` are documented in `Audio/MANIFEST.md` and (in Studio) the placeholder table print in `SoundController`. **No third-party attribution** until a real asset ships.

---

## 3. Images & 3D (Roblox assets)

| Category | Attribution approach |
|----------|------------------------|
| **UI icons / decals** (`rbxassetid://` in scripts, e.g. `UIController` action bar) | Roblox-hosted assets; use falls under Roblox experience distribution. **Board/Engineer:** keep a short internal list of IDs if store credits must name specific packs. |
| **Currency icons** | `Constants.luau` `CURRENCY_DISPLAY.*.icon` — currently **`rbxassetid://0` placeholders** (`LaunchAssets/AssetIdChecklist.md` §1). **TBD** until uploaded. **Owner:** Board (art) + Engineer (wire IDs). |
| **Easter eggs / config images** | `EasterEggConfig` + `ReplicatedStorage.Images` — **TBD** until images exist; see `AssetIdChecklist.md` §3. **Owner:** Board + Engineer. |
| **Cars, pets, eggs, world models** | Built in Roblox Studio per `STUDIO_TEMPLATES.md`; **original game content** unless otherwise noted in Studio. **TBD** if any model is sourced from Creator Store — then add pack name + ID to this doc. |

---

## 4. Open-source / third-party Luau code

| Status | Detail |
|--------|--------|
| **None identified in-repo** | The Rojo project (`DACReplicatedStorage`, `DACServerScriptService`, `DACStarterGui`, `DACStarterPlayerScripts`) uses **project-local `require()`** only — no vendored MIT/Apache modules, no `wally.toml`, no npm-style packages in this tree. |

If future work adds a package (e.g. Wally), add a row here with **package name, version, license SPDX, and link to license file**.

---

## 5. Tooling (not shipped to players)

| Tool | Purpose | License |
|------|---------|---------|
| `Audio/generate_placeholders.py` + **ffmpeg** | Silent OGG placeholders for repo/Studio | ffmpeg: **LGPL/GPL** depending on build — tooling only; not distributed in the Roblox client. |
| **Rojo** | Sync filesystem → Studio | See [Rojo license](https://github.com/rojo-rbx/rojo) (MIT). Dev-only. |

---

## 6. Roblox game description — credits blurb (≤500 characters)

Use as one paragraph on the game page or truncated footer:

> Thanks for playing Drive a Car Simulator! UI uses Roblox's Gotham fonts. Sounds use Roblox-uploaded and Roblox Library audio referenced in our game code; optional Splice-claimed samples will be listed in our audio manifest when finalized. Art and models are built for this experience; currency icons and some SFX are still rolling out. No third-party Luau libraries are bundled in our open repo. For full notes see Attributions_Phase4 in our project documentation.

**Character count (including spaces):** 465 *(under 500).*

---

## 7. Change log

| Date | Change |
|------|--------|
| 2026-03-22 | Initial Phase 4 one-pager (POLA-433). |
