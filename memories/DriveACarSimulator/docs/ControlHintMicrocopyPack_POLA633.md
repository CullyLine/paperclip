# Control hint microcopy pack — Phase 4 (POLA-633)

**Role:** Content Strategist handoff for **Settings / Help** (and any one-line HUD chips) — short lines that explain **steer**, **menus**, and **rebirth** without crowding the HUD.

**Centralization target (POLA-616):** When engineering adds a help surface or tooltips, add these strings to **`DACReplicatedStorage/Config/MicrocopyConfig.luau`** (or a small sibling module if you split “help hints” from celebration pools — keep one import path for UI). Keys below are **stable identifiers** for wiring; do not rename once shipped without a migration note.

**Implementation note:** `DrivingController.handleInput` supports **keyboard (A/D, arrows)**, **touch drag**, and **gamepad left stick** (`Thumbstick1.X`). Menu panels open from the **bottom ActionBar**; **Escape** and **gamepad B** close / back (`UIController`).

---

## Canonical table: key → string

| Key | Input focus | String |
|-----|-------------|--------|
| `HelpHint_Steer_KeyboardMouse` | Keyboard + mouse | Hold **A** / **D** or the **arrow keys** to steer left and right — your car drives forward automatically. |
| `HelpHint_Steer_Touch` | Mobile / tablet | **Drag left or right** on the screen to steer; release to ease back toward center. |
| `HelpHint_Steer_Gamepad` | Controller | Move the **left stick** left or right to steer; forward speed is handled for you. |
| `HelpHint_Menu_KeyboardMouse` | Keyboard + mouse | Click the **icons on the bottom bar** to open Store, Pets, Rebirth, and more; **Esc** closes an open panel. |
| `HelpHint_Menu_Touch` | Mobile / tablet | **Tap the bottom icons** to open Store, Pets, Rebirth, Settings, and other panels. |
| `HelpHint_Menu_Gamepad` | Controller | Move **GUI selection** to the **bottom icons**, press **A** to open; **B** (or **Esc**) steps back or closes. |
| `HelpHint_Rebirth_KeyboardMouse` | Keyboard + mouse | Click **Rebirth** on the bottom bar when you can afford it — it resets coins for **permanent** speed, power, and gas boosts. |
| `HelpHint_Rebirth_Touch` | Mobile / tablet | Tap **Rebirth** when you can afford it — trade a coin reset for **permanent** stat boosts. |
| `HelpHint_Rebirth_Gamepad` | Controller | Open **Rebirth** from the bottom bar when you can afford the cost — same permanent boosts as other platforms. |
| `HelpHint_Settings_SteerSensitivity` | All | **Steering sensitivity** changes how strong your left/right input feels on keyboard, touch, and controller — not your car’s top speed. |

---

## Optional single-line “universal” variants (if UI shows one line only)

Use when product wants **one** string with no branching (e.g. narrow tooltip). Prefer the split table above when space allows.

| Key | String |
|-----|--------|
| `HelpHint_Steer_Universal` | Steer **left and right** with **A/D**, **arrows**, **touch drag**, or the **left stick** — forward drive is automatic. |
| `HelpHint_Menu_Universal` | Use the **bottom icon bar** to reach Store, Pets, Rebirth, and Settings — **Esc** or **B** closes panels. |
| `HelpHint_Rebirth_Universal` | **Rebirth** on the bottom bar resets coins for **permanent** boosts when you can afford the cost. |

---

## Related docs

- [`ControlsHintCopy_Phase4.md`](ControlsHintCopy_Phase4.md) — broader audit (tutorial, first session, loading gaps).
- [`Phase4_EngineerCopyIntegration_Index.md`](Phase4_EngineerCopyIntegration_Index.md) — where copy lives and grep maintenance.
