# Phase 4 QA — screenshot regression (post modal ducking)

**Ticket:** POLA-274 (parent POLA-104). After POLA-256/268 audio + modal work, this folder holds **five** baseline viewport captures for layout/readability checks when music/SFX ducking and modal stacking change.

## Build / date

| Field | Value |
|--------|--------|
| Documented | 2026-03-22 |
| Workspace | `memories/DriveACarSimulator` |
| Capture script | `capture_modal_ducking_regression.py` |
| Last capture | 2026-03-22 — MCP `capture_screenshot` + `execute_luau` (all 5 PNGs + `manifest.json`) |

## Files (five screenshots)

| File | Panel / overlay |
|------|------------------|
| `regression_shop_store.png` | **Shop** — `DACMain.Panels.Store` |
| `regression_trophy_case.png` | **Trophy** — `DACMain.Panels.TrophyCase` |
| `regression_tutorial_overlay.png` | **Tutorial** — `StarterGui.DACTutorialOverlay` (if triggerable in session) |
| `regression_payout_overlay.png` | **Payout** — `StarterGui.DACPayout` |
| `regression_settings.png` | **Settings** — `DACMain.Panels.Settings` |

`manifest.json` is written beside the PNGs when the capture script succeeds (Luau return + whether each PNG saved).

## How to capture (Studio + MCP)

1. Open the place in **Roblox Studio** with the robloxstudio-mcp plugin (HTTP `http://127.0.0.1:58741`).
2. **Edit** mode (not Play). **Game Settings → Security:** enable **Allow Mesh / Image APIs** for `capture_screenshot`.
3. From repo root:

   `python docs/qa/regression/capture_modal_ducking_regression.py`

4. Refresh this README’s **Build / date** row if you re-ran captures for a new build.

## When MCP is offline

If the capture script cannot connect to port `58741` (Studio closed or plugin not running), PNGs will be missing until someone runs the command above locally. The script still writes a `manifest.json` with error details when Luau or screenshot steps fail.

## Fallback (manual Studio)

Hide other panels, show the target panel/overlay, frame the viewport, and use **View → Capture Screenshot** (or OS capture). Save into this folder using the filenames in the table so diffs stay stable.
