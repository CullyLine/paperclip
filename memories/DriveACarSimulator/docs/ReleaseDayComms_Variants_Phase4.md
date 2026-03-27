# Release day comms — variants (Phase 4)

**Purpose:** Paste-ready **same facts**, three lengths — Roblox **group shout**, **Discord**, **in-game news** — for the next Phase 4 polish publish.  
**Parent:** POLA-104 · **Ticket:** POLA-409  
**Alignment:** Structure and claims follow `docs/WhatsNew_Phase4_PlayerFacing.md` (POLA-375). Use `docs/PatchNotesTemplate_Phase4.md` (POLA-408) as the sibling “patch notes” view of these facts.

---

## Voice cross-check (before paste)

| Check | Source |
|--------|--------|
| Reward-forward, bubbly simulator tone; no guilt / blame | `docs/Phase4_TerminologyAndVoiceGlossary.md` §1–2 |
| No player “whale” framing; **Claim** / **Buy** / **Redeem** verbs per intent | `docs/Phase4_TerminologyAndVoiceGlossary.md` §3–4 |
| Juice / notification / retention tone hubs | `docs/Phase4_JuiceToneMatrix.md` (index to specs) |
| No fake urgency; fair streak framing | `docs/RetentionNudgeCopy_Phase4.md` (referenced from tone matrix) |
| **POLA-95:** Do not claim dev product / Game Pass SKUs are live until Dashboard IDs are confirmed | `docs/WhatsNew_Phase4_PlayerFacing.md` § Alignment note |

---

## A — Roblox group shout (paste block)

```
Phase 4 polish is live: guided first runs, achievements + trophy case, milestone celebrations, smarter HUD & notification lane, friend/group run bonuses, and clearer loading tips. Hop in with friends for extra coins!
```

**Character count:** 216 / 255 (with spaces). Trim the last sentence first if you add emoji or a tracked link.

**Fact source (one line):** Claims map to shipped Phase 4 pillars listed in `docs/WhatsNew_Phase4_PlayerFacing.md` § Group shout + § Bullets (onboarding, achievements/trophy case, milestones, HUD/notifications, friends/group, loading).

---

## B — Discord (~1.2k characters)

Hey drivers — **Phase 4 polish** is in this build, and it is all about feel: **clearer first runs** with welcome beats for early payouts, hatches, trophy case, and daily streak so you are not guessing the loop. **Achievements** unlock into a **trophy case** panel built for showing off milestones. **Milestone celebrations** and first-time moments use feedback tuned to feel rewarding, not spammy.

We also tightened **HUD** layout (including safe-area on phones) and the **notification lane** so achievements and driving feedback queue more predictably — same simulator juice, less overlap between celebration toasts and combo readouts. **Friends** in the same server can mean **bonus coins** on runs; **group** supporter perks apply when your experience’s group rewards are configured. **Loading** tips are clearer while the world streams in.

Daily streak and comeback copy leans **fair urgency** (real stakes, warmer lines) per our retention pass — not a guilt trip for time away. If you are grinding **rebirth**, chasing **leaderboard** runs, or hatching the next **egg**, this build should read cleaner without extra noise. Screenshots welcome — see you on the road.

**Character count:** ~1,172 (with spaces, including markdown asterisks) — within ~1.2k target; shorten a clause if your server adds link tracking or pings.

**Fact source (one line):** Paragraph themes and ordering align with `docs/WhatsNew_Phase4_PlayerFacing.md` § Paragraph + § Bullets and `docs/Phase4_TerminologyAndVoiceGlossary.md` (Driver, coins, gems, run, lobby); friend/group bonus *behavior* is described as in live design docs — **not** as confirmation of any specific Robux SKU wiring (see POLA-95 note above).

---

## C — In-game news (short + bullets)

### Short (headline + lead)

**Headline:** Phase 4 polish — smoother first runs & clearer rewards  

**Lead (one paragraph):**  
Phase 4 focuses on feel: guided early moments, achievements you can browse in a trophy case, milestone celebrations that stay rewarding, and a HUD + notification pass so pop-ups do not fight your driving readouts. Friend and group bonuses stay easier to read on the HUD; loading tips are clearer while you join.

**Fact source (one line):** Headline/lead condensed from `docs/WhatsNew_Phase4_PlayerFacing.md` § Paragraph + tone pillars in `docs/Phase4_TerminologyAndVoiceGlossary.md`.

### Bullets

1. **Guided first runs** — Welcome beats for first payout, hatch, trophy case, and daily streak.  
   *Source:* `docs/WhatsNew_Phase4_PlayerFacing.md` bullet 1; `DACReplicatedStorage/Config/FirstTimeConfig.luau` / tutorial flows as integrated in repo.

2. **Achievements & trophy case** — Unlock milestones and browse them in a dedicated panel.  
   *Source:* `docs/WhatsNew_Phase4_PlayerFacing.md` bullet 2; Achievement/Trophy UI specs under `docs/` (e.g. achievement guidelines) as referenced by Phase 4 index docs.

3. **Milestone celebrations** — First-time and spend milestones with celebration feedback tuned to feel earned.  
   *Source:* `docs/WhatsNew_Phase4_PlayerFacing.md` bullet 3; `docs/Phase4NotificationLaneJuiceSpec.md` for stacking context.

4. **HUD & notification lane** — Safer layout; achievements queue more predictably next to driving feedback.  
   *Source:* `docs/WhatsNew_Phase4_PlayerFacing.md` bullet 4; `docs/Phase4_JuiceToneMatrix.md` → notification specs.

5. **Friends & group** — Bonus coins when Roblox friends are in the same server; group perks when configured.  
   *Source:* `docs/WhatsNew_Phase4_PlayerFacing.md` bullet 5; `docs/SocialCopyAlignment_Phase4.md` for tone. *(Does not assert live Robux product IDs — POLA-95.)*

6. **Loading** — Clearer tips and a softer boot while the world streams in.  
   *Source:* `docs/WhatsNew_Phase4_PlayerFacing.md` bullet 6; `docs/Phase4_LoadingAndQueueTips.md` / `DACReplicatedStorage/Config/LoadingTipsConfig.luau`.

---

## Optional: tie-in line for patch notes

When publishing full patch notes, paste sections from the same fact set using the skeleton in `docs/PatchNotesTemplate_Phase4.md` (POLA-408) — **Summary → New → Improved → Fixes → Known Issues → Links** — so Discord, news, and patch notes stay one story. For a **short player-facing “known limitations”** block (game page, group, or social), use `docs/KnownLimitations_MicroSection_POLA611.md` (POLA-611), aligned with `docs/PlayerUpdateLog_Phase4_POLA608.md` (POLA-608).
