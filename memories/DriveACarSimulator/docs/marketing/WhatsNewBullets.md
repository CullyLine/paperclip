# What’s New — Phase 4 polish (next publish)

**Purpose:** Copy-ready lines for in-game news, Discord, and store/game description updates.  
**Parent:** POLA-104 · **Ticket:** POLA-309  
**Last updated:** 2026-03-22

---

## Title (pick one)

| Line | Audience |
|------|----------|
| **Phase 4 polish — smoother onboarding, smarter HUD, juicier feedback** | **Public** |
| **DAC Phase 4: first-session onboarding + retention pass + UI stack clarity** | **Internal** (dev-facing / changelog) |

---

## Bullet list (5–8 lines)

Use verbatim or trim one bullet for tight character limits. Tags apply **per line**.

| # | Copy | Audience |
|---|------|----------|
| 1 | **First-session onboarding** — guided copy on your first runs (welcome, first payout, hatch, trophy case, daily streak) so new drivers aren’t guessing what to do next. | **Public** |
| 2 | **Return & streak moments** — warmer session welcomes when you’re back after a break, plus clearer streak and idle nudges so daily rewards feel fair, not naggy. | **Public** |
| 3 | **HUD & chrome that stays out of your way** — driving readouts, safe-area layout, and passive chips (like friend bonus) tuned so the road stays readable on phone and desktop. | **Public** |
| 4 | **Notification lane polish** — achievements, milestones, and soft confirmations queue more predictably; less overlap with driving feedback and big celebrations. | **Public** *(“juice” is fine in Discord; say “clearer popups” on the game page if you want plainer language)* |
| 5 | **Play with friends** — bonus coins when Roblox friends are in the same server (tiers scale with how many friends are in-session with you). | **Public** |
| 6 | **Group supporters** — join the community group for bonus coin payouts on runs and one-time claim rewards *(exact rates match live config when published).* | **Public** *(swap to **Internal** if group ID / URLs are not finalized in Studio yet)* |
| 7 | **Loading & boot experience** — calmer first moments and clearer tips while the world streams in. | **Public** |
| 8 | **Sound & mix** — ongoing pass on UI and feedback audio levels *(ship this line only when the audio pass is in the build you’re publishing; otherwise use **Internal** or drop).* | **Public** *or* **Internal** — see note below |

### Notes for publishers

- **Line 8 (audio):** Use **Public** only if this publish actually includes the intended audio/mix changes. If not, mark line 8 **Internal** (“track list / levels still in progress”) or omit it from player-facing channels.
- **Line 6 (group):** If `GroupRewardConfig.groupId` is still `0` or URLs are placeholders, keep **Internal** on line 6 for Discord/game page until the human sets the real group ID in Dashboard + config.
- **Monetization / Creator Dashboard IDs (POLA-95):** Do **not** tell players that **game passes or developer products are “live” or “wired to real IDs”** until POLA-95 is closed and configs hold non-zero IDs. This doc deliberately avoids that claim.

---

## Summary

- **Path:** `docs/marketing/WhatsNewBullets.md`
- **Public-ready bullets (minimum set):** **7** numbered lines tagged **Public** above (use line 8 only when audio ships; otherwise **6** public lines + optional internal note).
- **Full list as written:** **8** bullets including the conditional audio line.

---

## Internal-only reminder (do not paste to players)

- **POLA-95:** Game pass / dev product numeric IDs remain a **Dashboard + config** step; marketing copy must not imply SKU IDs are live until engineering confirms.
- **Code/docs anchors:** Onboarding — `FirstSessionOnboardingService`, `MicrocopyConfig` first-session pools; retention — `RetentionController`, `MicrocopyConfig` / `SocialFeedConfig` session pools; layering — `UILayerStack`, `HudLayoutConfig`, notification-lane specs; social — `FriendBonusConfig`, `FriendBonusHUD`, `GroupRewardConfig`.
