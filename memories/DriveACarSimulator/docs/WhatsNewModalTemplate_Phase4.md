# What’s New — in-experience modal + patch notes (template)

**Purpose:** Paste-ready structure for the Roblox **in-experience news / What’s New** modal and optional **group or game page** patch notes.  
**Parent:** POLA-104 · **Ticket:** POLA-482  
**Canonical detail & tone cross-check:** `docs/WhatsNew_Phase4_PlayerFacing.md`, `docs/marketing/WhatsNewBullets.md`, `docs/PatchNotesTemplate_Phase4.md`

---

## 1) In-experience modal (Roblox)

Use **one title**, **3–6 bullets**, **one CTA line**. Keep bullets short; players skim on phone.

### Title (one line)

| Example (Phase 4 polish) | Template (next release) |
|---------------------------|-------------------------|
| **Phase 4 is live — smoother runs, bigger moments** | **`{{UPDATE_NAME}} — {{ONE_HOOK}}`** |

### Bullets (3–6)

**Phase 4 example (paste as-is or trim to 5):**

1. **Clearer first drives** — Guided beats on early runs so you always know what to do next.
2. **Achievements + trophy case** — Unlock milestones and show them off in a dedicated panel.
3. **Milestone celebrations** — Big moments get celebration feedback that feels rewarding, not spammy.
4. **HUD that stays readable** — Layout tuned for phones and desktop; notifications queue next to driving feedback.
5. **Friends & community** — Bonus coins when Roblox friends are in your server; group perks when configured *(rates match live config).*
6. **Smoother loading** — Clearer tips while the world streams in.

**Blank template (next publish):**

1. **`{{BULLET_1}}`**
2. **`{{BULLET_2}}`**
3. **`{{BULLET_3}}`**
4. *Optional:* **`{{BULLET_4}}`**
5. *Optional:* **`{{BULLET_5}}`**
6. *Optional:* **`{{BULLET_6}}`**

### CTA line (one line)

| Example (Phase 4) | Template |
|-------------------|----------|
| **Grab your best car — new rewards are waiting on the road.** | **`{{PRIMARY_ACTION}} — {{WHY_NOW}}.`** |

**Publisher guardrails**

- Do **not** claim Game Passes or Developer Products are “live” or “wired” until Dashboard SKUs and configs are confirmed (POLA-95).
- Only promise **audio / mix** if that build actually ships the pass (see `docs/marketing/WhatsNewBullets.md`).

---

## 2) Optional — short patch notes (group / game page)

Paste under a **Summary** + **Highlights** pattern; keep total under ~1,200 characters if the surface is cramped.

```markdown
## Update summary
{{1–2 sentences: theme of the release — e.g. feel, onboarding, social, juice.}}

## Highlights
- {{Highlight 1}}
- {{Highlight 2}}
- {{Highlight 3}}
- {{Optional: Highlight 4}}

## Notes
- Known issues or config dependencies only if players need to see them; otherwise keep internal.
```

**Phase 4 fill-in (aligned with `docs/PatchNotesTemplate_Phase4.md`):**

```markdown
## Update summary
Phase 4 focuses on feel: clearer onboarding, achievements and a trophy case, milestone celebrations,
and HUD / notification polish — plus friend and group bonuses when configured.

## Highlights
- Guided first-run beats and clearer loading tips while worlds stream in.
- Achievements, trophy case, and milestone celebrations tuned for reward without spam.
- Safer HUD layout and a more predictable notification lane next to driving feedback.
- Bonus coins with friends in-session; community group perks when enabled.

## Notes
- Bonus and group rates always match the live experience configuration at publish time.
```

---

## Links

| Need | Doc |
|------|-----|
| Paragraph + long modal / blog block | `docs/WhatsNew_Phase4_PlayerFacing.md` |
| Title options + extended bullet table | `docs/marketing/WhatsNewBullets.md` |
| Long-form patch skeleton | `docs/PatchNotesTemplate_Phase4.md` |
| Store / discovery | `docs/StorePageCopy_Phase4.md` |
