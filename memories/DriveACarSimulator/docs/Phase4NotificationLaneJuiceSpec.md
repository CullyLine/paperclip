# Phase 4 — Notification lane [C] juice (operational spec)

**Ticket:** POLA-280 (child of Phase 4 dopamine epic)  
**Purpose:** Turn **UILayerStackSpec** band **[C]** from a diagram into **predictable behavior**: how long things stay on screen, how they queue, when sound stacks or coalesces, and how **[C]** defers to **[E]** / **[G]**. Engineers align controllers (`AchievementController`, milestone / VFX popups, `SoundController`) without inventing one-off rules in each script.

**Canonical refs (do not duplicate — link here):**

| Topic | Document / module |
|--------|---------------------|
| Stack semantics [A]–[H] | `docs/UILayerStackSpec.md` |
| Achievement toast shell, rarity, density | `docs/AchievementVisualGuidelines.md` |
| Run-end vs combo vs [G] queueing | `docs/Phase4RunEndComboJuiceSpec.md` |
| Full ceremony layouts (first-time, streak, speed, rebirth, spend) | `DACStarterGui/MilestoneCeremonyDesignSpec.luau` |
| World color tokens (accent flashes on [C]) | `docs/WorldAtmosphereJuiceBible.md` |
| Photosensitivity / motion | `docs/qa/TutorialOverlayReadability.md` |

---

## 1. What counts as “[C] notification lane”

**In scope for this spec**

- **Achievement unlock queue** — `AchievementToast` / `AchievementController` pipeline.
- **Progress nudges** — `AchievementProgressToast` (deduped bottom card).
- **Light HUD toasts** called out in `MilestoneCeremonyDesignSpec` (e.g. speed milestone **toast** style vs full ceremony).
- **Soft confirmations** — short copy + icon (friend bonus, soft inventory ping) that intentionally avoid **[E]**.

**Out of scope (different bands)**

- **Blocking modals** → **[E]** (payout, purchase confirm).
- **Full-screen ceremony / big milestone takeover** → **[G]** or ceremony stack per `MilestoneCeremonyDesignSpec` (queue depth, dim layers).
- **Driving HUD [A]** — combo label is **[A]/[C] transient** per `Phase4RunEndComboJuiceSpec`; treat combo as **gameplay feedback**, not the same queue as achievement toasts.

---

## 2. Timing budgets (defaults)

These are **targets** for a “juicy but not exhausting” session. Implementations may tighten for low-end (`lodTier`) by **shortening motion**, not by **dropping** critical unlock feedback.

| Class | Default on-screen | Notes |
|--------|-------------------|--------|
| Single achievement unlock | 2.8–3.8s | Longer tail for gold/diamond / category complete (see `AchievementVisualGuidelines`). |
| Progress nudge | 2.0–2.5s | Replaces prior nudge for same feature — no vertical stack of three. |
| Soft confirmation | 1.2–1.8s | No confetti; optional tick SFX. |
| Stacked unlock (back-to-back) | +0.4s gap | Minimum gap between dismiss and next entrance so the eye resets. |

**Rule:** If **two** [C] items want the same 0.5s window, **delay the second** — never animate two hero entrances on top of each other.

---

## 3. Queueing & dedupe

1. **Achievement unlocks** use a **single FIFO queue** (already implied by `AchievementVisualGuidelines`). Max **visible depth 1**; additional unlocks wait.
2. **Progress nudges** are **keyed by feature** (e.g. one distance milestone track) — new nudge **replaces** the old (no pile-up).
3. **Ceremony queue** (from `MilestoneCeremonyDesignSpec`) is separate: max depth **3**, suppress while **driving run active** — do not merge those rules into achievement code; only ensure **both queues** respect §4 when **[E]** is open.

**Dedupe:** If the same logical event fires twice in one frame (replication / retry), show **one** toast.

---

## 4. Coexistence with [E] payout and [G] celebration

Aligns with `UILayerStackSpec` edge-case matrix and `Phase4RunEndComboJuiceSpec`:

| Situation | Behavior |
|-----------|----------|
| Run-end payout **[E]** opens | **Pause** non-critical [C] entrances until **[E]** dismisses **or** merge copy into payout if product-approved. |
| Critical unlock during payout | Prefer **merge into payout** (one hero moment) **or** queue after dismiss — never cover payout CTAs. |
| **[G]** full-screen queued | **[C]** waits — **[G]** is the hero unless design explicitly pairs a small [C] tick with **[G]** exit. |
| Store **[D]** open | Default: **compact** [C] or defer — no trophy confetti blocking cart. |

---

## 5. Sound stacking & coalescing

**Goals:** Notifications should feel **rich** without **masking** music or triggering stinger fatigue.

1. **One stinger at a time** for [C] — if a new toast arrives during SFX, **extend** the current card slightly rather than firing a second stinger on the same beat.
2. **Modal ducking:** When **[E]** is open, follow `SoundController.setPayoutModalOpen` (or equivalent) — [C] SFX **duck or skip** if the modal owns the ear.
3. **Ceremony sounds** from `MilestoneCeremonyDesignSpec` take precedence over routine [C] ticks when both are eligible; **defer** the weaker event.
4. **Max effective rate:** Avoid stacking notification stingers faster than **~2.5 Hz** sustained over 5s (aligns with combo audio guardrails in `Phase4RunEndComboJuiceSpec` spirit).

---

## 6. World flavor (optional Phase 4+)

Without breaking readability:

- Allow **≤15%** blend of active world **Primary** into neutral toast highlights (see combo world-tint note in `Phase4RunEndComboJuiceSpec`).
- **Never** replace pastel achievement shell with a full world gradient — tier accent bars and particles only.

---

## 7. Engineer acceptance checklist

- [ ] [C] never draws above blocking **[E]** unless the issue explicitly requires a tiny non-blocking tick.
- [ ] Achievement queue + ceremony queue both respect **run active** suppression rules from `MilestoneCeremonyDesignSpec`.
- [ ] No double hero animation: payout entrance vs [C] entrance vs **[G]** resolved by queueing per §4.
- [ ] Sound: no overlapping stinger spam; modal duck honored.
- [ ] QA: motion passes spirit of `docs/qa/TutorialOverlayReadability.md` (no strobe).

---

*Designer: Bard — POLA-280. Bridges Phase 4 “notification juice” with existing stack and ceremony specs.*
