# UI layer stack — Drive a Car Simulator (Phase 4)

**Purpose:** Single reference for how HUD, chrome, feedback, panels, and FX stack. Engineers map this to `ScreenGui.DisplayOrder`, `ZIndex`, and visibility rules in Studio — this doc stays **semantic**, not pixel-perfect.

**Related:** `HudLayoutConfig.luau` (sizes/safe-area), `TutorialOverlayDesignSpec.luau` (tutorial overlay bands), `AGENTS.md` (pre-built UI under `DACMain`).

---

## 1. Stack diagram (bottom → top)

Read **lower** layers first; anything **higher** draws on top when both are visible.

```
BOTTOM
  |
  |  World / 3D view (not GUI)
  |
  |  [A] Driving HUD — speed, run progress, lane-adjacent chips tied to the drive loop.
  |      Must stay readable during play; avoid covering core readouts with transient UI.
  |
  |  [B] Passive chrome — persistent top/bottom safe-area framing, currency strip,
  |      non-blocking hints, Friend Bonus chip, server drop / event banner rails
  |      (informational; should not steal focus from the drive).
  |
  |  [C] Toast & notification lane — achievement unlock, progress milestone,
  |      soft confirmations. Short-lived; typically top or upper-third.
  |
  |  [D] Side panels & menu hub — inventory, store, eggs, settings, quests, etc.
  |      Registered panels under `DACMain`; open/close toggles; may dim world slightly
  |      via panel chrome but are not full-screen blockers unless designed as such.
  |
  |  [E] Blocking modals — payout summary, purchase confirm, code redeem, forced
  |      choices. Dim the world; capture input until dismissed.
  |
  |  [F] Tutorial / coach overlay — soft dim + bubble; can highlight HUD targets.
  |      Above most HUD by design so instructions are never buried.
  |
  |  [G] Full-screen FX & celebration — run-end fanfare, big milestone bursts,
  |      screen-space juice. Short duration; must not permanently hide [E] if both
  |      queue (see edge cases).
  |
  |  [H] Loading / boot / fatal blockers — highest band when present (e.g. loading
  |      screen above everything else until ready).
  |
TOP
```

**Mnemonic:** *Drive → chrome → ping → shop → paywall → teach → party → boot.*

---

## 2. Relative priority (for DisplayOrder mapping)

Assign **bands** first, then fine-tune within a band with `ZIndex`.

| Band | Role | Priority rule |
|------|------|----------------|
| **H** | Boot / loading | Always on top when active; nothing should paint above except dev diagnostics. |
| **G** | Full-screen celebration / VFX | Above modals **only** when the moment is intentionally “takeover”; otherwise defer or queue behind modal if a blocking flow is open. |
| **F** | Tutorial overlay | Above panels **[D]** so instructions are visible; below **[H]**; coordinate with **[E]** so payout/confirm is not hidden behind tutorial. |
| **E** | Blocking modal | Above **[D]** and toasts **[C]**; input sink. |
| **D** | Side panels / menu | Above **[B]** and **[C]** when open (panel focus); closing returns to **[A]/[B]**. |
| **C** | Toasts | Above **[A]/[B]**; **below** **[D]** when a panel is open unless product explicitly wants “toast over shop” (generally avoid). |
| **B** | Passive chrome | Above world, below toasts and panels. |
| **A** | Driving HUD | Baseline gameplay readout; lowest GUI band except world. |

**Within a band:** prefer pre-built hierarchy in StarterGui; use `ZIndex` for ephemeral/runtime children (e.g. achievement card internals vs holder).

---

## 3. Edge-case matrix

| Scenario | Expected behavior |
|----------|-------------------|
| **Run-end payout while a toast is queued** | Payout **[E]** wins: show modal first or flush/cancel non-critical toasts. If toast is critical (e.g. rare unlock), either queue payout after toast **or** merge copy into payout. Never stack two competing hero animations. |
| **Shop open during achievement** | Default: **close or suppress** shop-highlight achievement toast until shop closes, **or** show a **compact** toast in **[C]** that does not cover cart/checkout. Full achievement fanfare **[G]** should not fire while Store **[D]** is focused unless explicitly designed. |
| **Friend feed / social strip vs modal dim** | Passive friend/social **[B]** hides or fades when **[E]** or **[F]** is active so dimmer reads as one surface. Do not leave semi-opaque strips that look like “broken” HUD. |
| **Tutorial during payout or modal** | Tutorial **[F]** should **not** start on top of **[E]**; defer tutorial steps until modal clears, or auto-dismiss low-priority modals per design. |
| **Celebration FX + blocking modal** | If modal is open, **defer** **[G]** or play **muted/minimal** FX behind modal; never trap the player with invisible clicks. |
| **Two panels requested (e.g. Quest + Store)** | Menu hub should enforce **single panel focus** or explicit stack (sub-panel). Avoid overlapping full panels without z-order rules. |
| **Event banner + toast same corner** | Stagger vertically (see `HudLayoutConfig` rest offsets) or alternate corners; never overlap unreadable. |

---

## 4. Implementation notes (Engineer checklist)

- Prefer **separate `ScreenGui`** instances with ordered **DisplayOrder** for major bands; reserve **ZIndex** for intra-gui stacking.
- **Pre-built** shells in StarterGui; ephemeral rows/effects still `Instance.new` per `AGENTS.md`.
- After changes, smoke-test: drive **[A]**, open Store **[D]**, trigger achievement **[C]**, complete run **[E]/[G]**, skip tutorial **[F]**.

---

*POLA-253 — Bard design spec. No code changes required by this document.*
