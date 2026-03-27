# Tutorial flow — content audit (POLA-226)

## Goals addressed

1. **Clarity for first-time players** — Step 1 now states the core loop upfront (drive → earn → upgrade → pets). Step 2 explains that coins bank when the run ends (gas empty), not mid-drive.
2. **Core loop** — Steps 1–5 map directly to: start run → earn → spend coins on Speed → hatch → equip pet for modifier.
3. **Soft monetization** — Completion message mentions Store and Game Passes as optional boosts, framed as excitement (“extra boosts”) without guilt or pressure.

## Step-by-step intent

| Step | Focus | Player action |
|------|--------|----------------|
| 1 | Loop + CTA | Tap Drive |
| 2 | Payout rules | Complete first run |
| 3 | Coin sink | Speed upgrade in Store |
| 4 | Pet acquisition | Hatch Meadow Egg |
| 5 | Power expression | Equip pet in Garage |
| Done | Retention + next goals | Bonus coins + rebirth / passes nudge |

## Optional future enhancements (not in scope for this ticket)

- Add a **step 0** splash (first session only) with 1–2 lines on controls if the game adds steering hints.
- Tutorial **highlight** names for “Menu” if a dedicated menu button name exists in StarterGui.
- **A/B** short vs long body copy using telemetry on skip rate.

## Related code

- `DACServerScriptService/Services/TutorialService.luau` — payloads and completion copy.
- `DACStarterGui/TutorialOverlay.luau` — presentation only (server owns text).
