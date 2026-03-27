# Weekly patch bullets — Phase 4 (Discord & X)

**Purpose:** Short, repeatable skeleton for a **weekly** social post (Discord `#announcements`, X / Bluesky). Use when you have a small delta to share without writing full patch notes.  
**Parent:** POLA-104 · **Ticket:** POLA-451

**Alignment:** Facts must match `docs/WhatsNew_Phase4_PlayerFacing.md` (POLA-375). For long-form Creator Hub / changelog structure, use **`docs/PatchNotesTemplate_Phase4.md` (POLA-408)** — Summary → New → Improved → Fixes → Known Issues → Links.

**Constraints:** No roadmap promises. Tone: reward-forward, bubbly simulator voice — see `docs/Phase4_TerminologyAndVoiceGlossary.md`.

---

## Empty template (5 bullets)

Copy this block and replace the placeholders each week.

| Slot | Paste line |
|------|------------|
| **1 — Headline fix** | *(One concrete player-visible fix or stability win this week. If none, use “No player-facing fixes this week” or merge a small polish into slot 4.)* |
| **2 — Headline feature** | *(The one thing you want skimmers to remember — usually one shipped improvement or new surface.)* |
| **3 — Balance** | *(Economy, payout, friend bonus rates, egg odds — only if config actually changed; otherwise “No balance changes this week.”)* |
| **4 — QoL** | *(Small UX: copy, HUD, loading, sound toggle, tutorial string — polish that isn’t a “fix.”)* |
| **5 — Known issue** | *(One honest caveat — or “None blocking” if clean.)* |

**Optional one-liner above the list (≤ 280 chars for X):**

```
This week in Drive a Car Simulator: [FIX] · [FEATURE] · [BALANCE] · [QOL] — [KNOWN ISSUE]
```

---

## Filled example (verified Phase 4 shipped facts only)

*Below uses only claims already documented as Phase 4 shipped behavior in `docs/WhatsNew_Phase4_PlayerFacing.md`. It does **not** invent new features or dates.*

| Slot | Example line |
|------|----------------|
| **1 — Headline fix** | **HUD & notification lane** — Achievements and milestones queue more predictably next to driving feedback on phone and desktop (layout + overlap polish). |
| **2 — Headline feature** | **Achievements & trophy case** — Unlock milestones and browse them in a dedicated panel built for completionists. |
| **3 — Balance** | **Friends & group** — Bonus coins when Roblox friends are in the same server; group supporter perks when configured *(rates match live config when published).* |
| **4 — QoL** | **Loading & first sessions** — Clearer tips and a softer boot while the world streams in; guided beats for first payout, hatch, trophy case, and daily streak. |
| **5 — Known issue** | **Assets & IDs** — Some placeholder art and registry keys may still be mid-pass; paid SKU wiring is only “live” when Dashboard IDs land in config (**POLA-95**). |

**Example X-length hook (single line, ~240 chars):**

```
Weekly recap: tighter HUD + notification queue, trophy case for achievements, friend/group bonuses, smoother loading & first-run tips. Some assets still in flight — thanks for riding with us!
```

---

## Cross-links

| Doc | Use |
|-----|-----|
| `docs/PatchNotesTemplate_Phase4.md` | **POLA-408** — full patch notes skeleton |
| `docs/WhatsNew_Phase4_PlayerFacing.md` | **POLA-375** — canonical player-facing claims & shout budgets |
| `docs/ReleaseDayComms_Variants_Phase4.md` | Discord / news variants aligned with the same facts |
