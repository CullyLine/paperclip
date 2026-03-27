# Phase 4 — Public copy compliance pass (POLA-626)

**Role:** Content Strategist · **Parent:** POLA-104 · **Scope:** Roblox Community Standards–aligned review of **public-facing** and **player-visible** copy (experience page sources + in-game strings). **References:** POLA-608 (`PlayerUpdateLog_Phase4_POLA608.md`), POLA-611 (`KnownLimitations_MicroSection_POLA611.md`), POLA-623 companion grep/QA docs.

---

## 1. Sources reviewed

| Source | Risk focus | Verdict |
|--------|----------------|---------|
| `GamePageContent.md` §2 (primary description) | Superlatives, urgency, reward claims | **OK with notes** — numeric feature claims (11+ cars, 14+ pets, 4 worlds, 13 passes) must stay in sync with configs at publish time; **13** matches `GamePassConfig` (13 passes). Premium **+50%** matches `Constants.PREMIUM_COIN_BONUS`. World coin mult “up to 10x” is qualified; verify against `WorldUnlockConfig` / live multipliers before paste. |
| `docs/PlayerUpdateLog_Phase4_POLA608.md` | Honest roadmap, no vendor blame | **OK** — Phase 4 framing, monetization disclosure, “what’s next” is cautious. |
| `docs/KnownLimitations_MicroSection_POLA611.md` | Trust / limitations | **OK** — store SKU and placeholder transparency; no false “everything works” claims. |
| `DACReplicatedStorage/Config/MicrocopyConfig.luau` | Fake stats, earnings brags | **Must-fix applied** — one line implied a **lobby percentile** without server backing (see §3). |
| `DACReplicatedStorage/Config/AchievementPopupConfig.luau` | Global player % claims | **Must-fix applied** — total-completion line cited **&lt;0.01% of players** without analytics (see §3). |
| `DACReplicatedStorage/Config/FomoBadgeLabelConfig.luau` | Hard odds | **OK** — Mythic tooltip “0.01% odds!” aligns with server-facing hatch display (`EggService` uses `~<0.01%` for extreme rare); if balance changes, update tooltip in sync. |
| Event / countdown pools (`MicrocopyConfig.EventBannerHeadlines`, `EventCountdown`) | “LAST HOUR” / FOMO when no event | **Process** — only wire or enable lines when `EventService` (or equivalent) drives a **real** window; avoid static urgency with no timer. |

---

## 2. Community Standards checklist (pre-publish)

- [ ] **Honest features:** Description and thumbnails match what the live experience offers (worlds, passes, codes — update when content changes).
- [ ] **No false statistics:** Do not claim **% of players**, **% of lobby**, or **exact global rarity** unless computed from real metrics or design data shipped in code.
- [ ] **Urgency:** Time-limited copy (events, streak warnings) matches **actual** timers or is framed as motivational, not a fake countdown.
- [ ] **Monetization:** Paid advantages described accurately; free loop remains playable (aligned with POLA-611).
- [ ] **Premium:** **+50% coins** (and stacking language) matches `Constants.PREMIUM_COIN_BONUS` and Premium implementation.
- [ ] **Group / social:** “Exclusive codes” only if group actually receives codes on that schedule.

---

## 3. Redlines (replace X → Y)

| Location | Before (X) | After (Y) | Reason |
|----------|--------------|-----------|--------|
| `MicrocopyConfig.PayoutFlexBig` | “You just out-earned **99%** of the lobby. Casually.” | “**Elite haul energy** — that payout turned heads in the lobby.” | Unverifiable **lobby percentile**; avoid misleading performance claims. |
| `AchievementPopupConfig.TotalCompletion` | “100% COMPLETE! Fewer than **0.01%** of players will EVER stand here!” | “100% COMPLETE! **Full trophy sweep** — one of the rarest flexes in the game!” | Unattributed **global player %**; replace with qualitative flex without fake analytics. |

---

## 4. Non-blocking tone notes (keep or soften later)

- **Payout / flex pools** — Lines like “top earn bracket,” “lobby-resetting,” “statement” are **subjective hype** (not earnings promises); acceptable if tone stays clearly non-literal.
- **Game page** — “LIKE & FAVORITE for **weekly** update alerts” requires a genuine update cadence or soften to “for update alerts.”
- **Thumbnail briefs** — “NEW!” badges and “90K SUBS!” must use **current** YouTube count and approved creator assets (already noted in `GamePageContent.md`).

---

## 5. Sign-off

- **Content Strategist — POLA-626 (2026-03-22):** §1 reviewed; §3 must-fix strings applied in repo; §2 checklist ready for final publish gate with live config + SKU verification.
