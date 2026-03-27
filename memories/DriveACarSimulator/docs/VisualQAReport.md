# Drive a Car Simulator — Visual QA Report (MCP Playtest)

**Date:** 2026-03-22  
**Method:** Roblox Studio MCP HTTP API (`http://127.0.0.1:58741`), `execute_luau` (plugin context), `capture_screenshot` in **Edit mode** (playtest stopped before panel captures).  
**Place (Studio):** `test` (game ID `9913957151` per `get_place_info` at capture time).

## Artifacts

- **Screenshots (PNG):** `docs/VisualQA_screenshots/` — see `manifest.json` for per-file `execute_luau` status.
- **Capture script (rerunnable):** `docs/run_visual_qa_capture.py`

## Panel coverage (StarterGui.DACMain.Panels)

Each row is a **viewport capture** with other panels hidden and the named frame set `Visible = true`. Static shells are visible in Edit mode without a live client session.

| Panel / ID | Result | Notes |
|------------|--------|--------|
| Inventory | Pass | Screenshot `panel_Inventory.png` |
| Store | Pass | `panel_Store.png` |
| EggStore | Pass | `panel_EggStore.png` |
| Rebirth | Pass | `panel_Rebirth.png` |
| Codes | Pass | `panel_Codes.png` |
| Settings | Pass | `panel_Settings.png` |
| Quest | Pass | `panel_Quest.png` |
| BattlePass | Pass | `panel_BattlePass.png` |
| World | Pass | `panel_World.png` |
| PetIndex | Pass | `panel_PetIndex.png` |
| Daily | Pass | `panel_Daily.png` |
| TrophyCase | Pass | `panel_TrophyCase.png` |

## HUD

| Target | Result | Notes |
|--------|--------|--------|
| Main HUD (ActionBar + PlayerInfo, DrivingUI hidden) | Pass | `hud_main.png` |
| Driving HUD (DrivingUI visible) | Pass | `hud_driving.png` |
| Menu hub strip | Pass | Covered by `hud_main.png` (ActionBar + bottom strip) |

## Separate ScreenGuis

| UI | Result | Notes |
|----|--------|--------|
| Tutorial overlay | Pass | `overlay_Tutorial.png` — `DACTutorialOverlay` |
| Event banner | Pass | `overlay_EventBanner.png` |
| Playtime gem HUD | Pass | `overlay_PlaytimeGem.png` |
| Payout | Pass | `overlay_Payout.png` — Dim + Card shown |

## World ambience

| Zone (requested) | Result | Notes |
|------------------|--------|--------|
| Grasslands | Pass | `world_grasslands_viewport.png` — camera scripted toward first `BasePart` under `Workspace.Worlds` |
| Desert | N/A | This place file only exposes **`Workspace.Worlds.1`** (single world folder). No separate Desert/Tundra/Neon world roots were present to frame independently. |
| Frozen Tundra | N/A | Same as above. |
| Neon City | N/A | Same as above. |

To re-run QA when multiple world folders exist, extend `run_visual_qa_capture.py` with per-folder camera targets or playtest teleports.

## Design system (AGENTS.md)

**Spot-check (automated captures):** Panels use the chunky rounded layout, light panel bodies, separate title/close affordances, and saturated accent buttons consistent with the DAC reference style.

**Not machine-verified:** Exact hex values (`#FFD6EE`, `#2A2A40`, `#2ECC71`, `#FF2222`) and **GothamBold** on every label require Properties / UI inspector review in Studio or image sampling — not asserted by this script.

**Findings:** None blocking from static layout review; recommend a human pass on `docs/VisualQA_screenshots/*.png` for stroke width and watermark visibility.

## Mobile scaling

**Not run:** MCP session did not resize the Studio viewport to phone aspect ratios. Clipping/overlap **cannot** be confirmed from this pass. Recommend Studio Device Emulator or `execute_luau` viewport emulation if exposed by a future MCP tool.

## Blockers

**None for MCP:** Port `58741` was reachable; screenshots were produced.

---

#### Files on disk

- `docs/VisualQAReport.md` (this file)
- `docs/run_visual_qa_capture.py`
- `docs/VisualQA_screenshots/*.png`
- `docs/VisualQA_screenshots/manifest.json` (may reflect first batch; world shot was re-captured after fixing camera script)
