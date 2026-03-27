# Store page copy — Phase 4 (Creator Dashboard)

**Purpose:** Punchy **feature bullets** and a **short description** aligned with shipped Phase 4 polish (achievements, juice, trophy case, onboarding, social bonuses, HUD layering). Use when refreshing the Roblox Creator Dashboard experience page alongside **POLA-95** (live pass/product IDs — still a separate human + config step).

---

## Change log

| Date | Ticket | Notes |
|------|--------|--------|
| 2026-03-22 | POLA-370 | Initial pack: 8 feature bullets + short description variants with character counts. Sources: `PreLaunchChecklist.md` (Phase 4 / non-ID sections), `docs/marketing/WhatsNewBullets.md`, `docs/Phase4_DiscoveryAndGamePageCopy.md`, `docs/GamePageAndDiscoveryCopy.md`; features cross-checked against Luau modules (e.g. `TrophyCasePanel`, `AchievementController`, `MilestoneCeremonyService`, `FriendBonusService`, `GroupRewardService`, `TutorialOverlay`, `HudToastConfig`). |

---

## Character limits (reference)

| Field | Typical cap | Canonical doc |
|-------|-------------|----------------|
| Primary / long description | **1000** characters | `GamePageContent.md` §2 (997-char master block — **do not fork**; merge Phase 4 lines from `docs/GamePageAndDiscoveryCopy.md` when updating) |
| Short blurbs / previews | Varies by surface; **count before paste** | Use the variants below; trim from **Variant B → A** if a field rejects long text |

**POLA-95:** Until Creator Dashboard products exist and `GamePassConfig.luau` / `DevProductConfig.luau` hold non-zero IDs, **do not** tell players that monetization SKUs are “live” or “wired” in store copy.

---

## Short description (2–3 sentences)

**Variant A — tight** — previews, strict caps, or first-line mobile fold

```
Drive endless highways: hatch pets, rebirth for power, explore four worlds. Phase 4 polishes onboarding, achievements + trophy case, milestone pops, cleaner HUD—friends in-server grant bonus coins.
```

- **Characters (with spaces):** 197

**Variant B — standard** — longer “short description” slots (~300 characters)

```
The premium highway simulator—hatch pets, rebirth for power, and chase multipliers across four worlds. Phase 4 adds guided first runs, achievements with a trophy case, milestone celebrations, and smarter HUD layering for mobile. Invite friends for server bonus coins and stack daily streaks with codes.
```

- **Characters (with spaces):** 302

**Publisher pick:** Use **Variant B** where the dashboard allows; fall back to **Variant A** for hard character ceilings.

---

## Feature bullets (5–8) — store-ready

Use **5–8** lines on the experience page, weekly update, or “What’s New” — copy-paste ready; tone is **premium simulator, dopamine-forward** (no “whale” jargon in player-facing strings).

1. **Guided first runs** — Welcome beats for your first payout, hatch, trophy case, and daily streak so new drivers aren’t guessing the loop.
2. **Achievements & trophy case** — Unlock milestones and show off progress in a dedicated case built for completionists.
3. **Milestone celebrations** — Big moments land with celebration feedback tuned to feel rewarding, not spammy.
4. **HUD that stays readable** — Safe-area layout, driving readouts, and passive chips (like friend bonus) kept off the lane on phone and desktop.
5. **Notification lane polish** — Achievements and milestones queue more predictably next to driving feedback.
6. **Friends = bonus coins** — Roblox friends in the same server grant tiered run bonuses while you drive together.
7. **Group supporters** — Join the community group for bonus payouts on runs and claim rewards *(rates match live config when published).*
8. **Calmer loading** — Clearer tips and a softer boot while the world streams in.

*Bullets 1–8 = full Phase 4 set. If you must ship **5–7**, drop in this order: 8 → 7 → 5 (keep social proof bullets if group/friends are live in that build).*

---

## Related files on disk

| Path | Role |
|------|------|
| `docs/StorePageCopy_Phase4.md` | This pack (POLA-370) |
| `GamePageContent.md` | Master 997-char description, tags, thumbnails |
| `docs/GamePageAndDiscoveryCopy.md` | Phase 4 description insert + discovery keywords |
| `docs/marketing/WhatsNewBullets.md` | Alternate bullet wording & publisher notes |
| `PreLaunchChecklist.md` | Launch verification; POLA-95 monetization guardrails |
