# POLA-735 — Credits & About (player-facing copy pass)

**Status:** Canonical for in-game **About**, **Credits**, and **build version** line wired from `DACReplicatedStorage/Config/CreditsAboutConfig.luau` and `DACStarterGui/SettingsPanel.luau`.

**Rules**

- No **POLA-###**, internal ticket IDs, or codenames in **TextLabel** text shown to players.
- **Version** uses Roblox **`game.PlaceVersion`** at runtime (increments when the place is published) — keep store/patch notes aligned with published builds.
- **Source of truth for strings:** this document §3 ↔ `CreditsAboutConfig.luau` (edit doc first, then sync the module).

---

## 1. Surfaces

| Surface | Where |
|--------|--------|
| Settings → About | First paragraph + build line |
| Settings → Credits | Short attribution block |

---

## 2. Tone

Friendly, concise, suitable for all ages. No jargon about internal tools. Credits summarize fonts, audio sourcing, and original art — aligned with `docs/Attributions_Phase4.md` but shortened for a scroll panel.

---

## 3. Canonical strings (wire these in code)

| Key | Value |
|-----|--------|
| `SECTION_ABOUT` | `About` |
| `SECTION_CREDITS` | `Credits` |
| `ABOUT_BODY` | `Drive a Car Simulator is a Roblox driving experience: collect cars and pets, race laps, and push your speed. Thank you for playing!` |
| `CREDITS_BODY` | `UI uses Roblox Gotham fonts. Music and sounds use Roblox-uploaded and Roblox Library audio set in our game; some world and driving sounds may be updated as we finalize our audio list. Cars, pets, eggs, and worlds are built for this experience. No third-party Luau packages are bundled in our open project files. For a longer store-style credits blurb, see the game description.` |
| `VERSION_LABEL_PREFIX` | `Build` |

**Version line format (script-assembled, not a single config string):**  
`{VERSION_LABEL_PREFIX} {game.PlaceVersion}`  
Example player-visible: `Build 42`

---

## 4. Verification

- Open Settings in Play Solo or a published place: **About** and **Credits** sections appear with text above; **Build** line matches the current place version (Studio unpublished may show `0`).
- Grep player-facing GUI: no `POLA-` in `Text` properties for these panels.
