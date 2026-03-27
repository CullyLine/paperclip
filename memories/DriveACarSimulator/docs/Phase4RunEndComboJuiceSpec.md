# Phase 4 — Run-end & coin-combo juice (implementation spec)

**Ticket:** POLA-271 (child of POLA-104)  
**Purpose:** One place engineers can align **driving-time combo feedback** with **run-end payout / celebration** so Phase 4 polish stays coherent — same art direction, predictable stacking, and safe motion.

**Canonical refs (do not duplicate):**

| Topic | Document / module |
|--------|---------------------|
| HUD band order, [C]/[E]/[G] | `docs/UILayerStackSpec.md` |
| Per-world color tokens & mood | `docs/WorldAtmosphereJuiceBible.md` |
| Payout screen drama, timings | `DACStarterGui/PayoutPanelDesignSpec.luau` |
| Achievement toast vs milestone popups | `docs/AchievementVisualGuidelines.md` |
| Photosensitivity / motion guardrails | `docs/qa/TutorialOverlayReadability.md` |
| Sound IDs & modal ducking | `DACStarterPlayerScripts/Controllers/SoundController.luau` |

---

## 1. Player journey (happy path)

1. **Driving:** Player collects coins along the lane. Internal streak (`coinComboStreak`) builds when pickups are within **2s** of each other; otherwise streak resets.
2. **Combo HUD:** From streak **≥ 2**, the client shows the **`CoinCombo`** label (runtime `TextLabel` under the main `ScreenGui`, **not** pre-built in StarterGui). Streak text `xN`, color ramps white → yellow → orange → red, size escalates with streak tier.
3. **Run end:** Driving loop stops; **payout / summary** is a **blocking modal band [E]** per `UILayerStackSpec`. Full-screen celebration / coin rain / card fanfare lives in the payout stack (`DACStarterGui/PayoutPanelDesignSpec.luau` + `PayoutPanel` implementation).
4. **Post-run:** Any separate **full-screen FX [G]** (milestone bursts, world ceremony, etc.) must **queue or defer** if [E] is open — see edge-case matrix in `UILayerStackSpec.md`.

**Design intent:** Combo is **session tension** while driving; payout is **resolution**. Do not run two “hero” animations competing for the same 0.5s window.

---

## 2. Coin combo streak (driving band [A] / transient [C])

**Code anchor:** `DACStarterPlayerScripts/Controllers/VFXController.luau` — `comboCoinPickup`, `ensureComboLabel`, `comboColorForStreak`, `comboTextSizeForStreak`.

| Rule | Spec |
|------|------|
| **Placement** | Anchor center, **Y ≈ 0.58** of screen height — below central HUD so it does not obscure speed/run readouts; stays in “lower third” of safe zone on phones. |
| **Visibility** | Hidden when streak &lt; 2; hidden after **2s** idle from last pickup (see `scheduleComboReset`). |
| **ZIndex** | Label **1001** (above generic HUD chrome, below loading [H]). If stack conflicts appear, prefer **raising band via `ScreenGui.DisplayOrder`** over inflating ZIndex unbounded. |
| **Color ramp** | Keep existing **white → gold → orange → hot red** ladder for readability. Optional Phase 4+ enhancement: **tint the white tier** with the active world’s **Primary** from `WorldAtmosphereJuiceBible.md` at **≤ 15% blend** so combo feels “of the world” without breaking rarity read. |
| **Motion** | `UIScale` punch on tick-up is allowed; avoid **> 3 full-screen flashes/sec** on any red layer (see QA doc). |

**Audio:** Coin pickups use one-shots (`coin_pickup`); combo streak may use registered `combo` SFX where already wired — do not stack conflicting stingers faster than **~6 Hz**.

---

## 3. Run-end payout (band [E]) vs celebration (band [G])

**Code anchor:** Payout UI + `SoundController.setPayoutModalOpen` (modal duck for clarity).

| Rule | Spec |
|------|------|
| **Order** | **Payout modal owns** the first read moment after the run. Do not fire unrelated **[G]** full-screen VFX on top of the payout card entrance unless the product explicitly calls for a merged moment (rare). |
| **Dim / focus** | Follow **PayoutPanelDesignSpec** — dim overlay and anticipation beats are the “juice”; they already sit in [E]. |
| **World flavor** | Stagger reveals and particle accents may pull **Accent / Secondary** from the active world in `WorldAtmosphereJuiceBible.md`; keep **text** on DAC panels readable (dark on light or white + stroke). |
| **After dismiss** | Deferred **[G]** (e.g. milestone ceremony) may play **after** payout closes; if both must occur in one session, **shorten** [G] duration when [E] was long. |

---

## 4. Stacking & concurrency (must match UILayerStackSpec)

- **Toast [C] + payout [E]:** Payout wins — flush or delay non-critical toasts (already documented in edge-case matrix).
- **Store [D] open:** Do not fire full achievement / combo fanfare **[G]** over the store; suppress or compact **[C]** per existing policy.
- **LOD:** Respect `lodTier` multipliers in `VFXController` for trails/bursts so low-end devices still get **timing** without max particles.

---

## 5. Engineer acceptance checklist (Phase 4)

- [ ] Combo label never hides primary speed / distance readouts on 16:9 and 19.5:9 test frames.
- [ ] Run end: payout opens; `SoundController` duck state consistent (no double music swell).
- [ ] No competing hero animation: payout card entrance vs external **[G]** celebration resolved by queueing.
- [ ] World accent usage (if added) stays within Bible tokens; no new one-off hex colors in scattered scripts — centralize next to existing combo helpers.
- [ ] QA: flash / pulse patterns pass `docs/qa/TutorialOverlayReadability.md` spirit (smooth motion, no strobe).

---

*Designer: Bard — aligns POLA-104 dopamine goals with existing specs and shipped controllers.*
