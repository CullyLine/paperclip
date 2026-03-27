# Phase 4 — Empty-state, loading & zero-data copy audit

**Ticket:** POLA-305 (Phase 4 polish)  
**Goal:** Align user-visible empty placeholders, loading hints, and zero-data rows with Phase 4 tone: **short, confident, reward-forward** (no guilt; whale-friendly without cringe slang).

---

## Summary

| Area | Primary source | Config vs hardcoded |
|------|----------------|---------------------|
| Friend Bonus HUD | `DACStarterGui/FriendBonusHUD.luau` | Hardcoded label prefix; `%` from server payload |
| Group join banner | `DACReplicatedStorage/Config/GroupRewardConfig.luau` | Config strings (banner not wired to `SocialFeedConfig.GroupJoinBanner`) |
| HUD notification lane | `UIController.showNotification`, achievement queue, `RemoteFailSafe` | Mixed: `MicrocopyConfig` pools + dynamic server/client messages |
| Store / egg shop | `StorePanel.luau`, `UIController.wireEggStorePanel`, `SocialFeedConfig` | Hardcoded CTAs + FOMO; world headers built in code |
| Quest rows | `QuestPanel.luau`, `MicrocopyConfig` | Hardcoded celebration + em-dash empty; pools in config |

---

## Audit table

| Surface | Current string | Proposed string | Notes |
|---------|----------------|-----------------|-------|
| **Friend Bonus HUD — inactive** | *(chip hidden; no copy)* | *(keep hidden — no empty-state line)* | Empty = no UI; avoids clutter on speed HUD. Optional future: dim chip `"Solo run — invite friends for +10%+"` (≤28 chars); product call. |
| **Friend Bonus HUD — active** | `Friends Bonus: {pct}` (e.g. `Friends Bonus: +10%`) | `Friends online: {pct} coins` | Hardcoded in `FriendBonusHUD.luau` `` `Friends Bonus: {pct}` ``. Slightly clearer that it’s a coin boost; keep `{pct}` from server. ~30 chars typical. |
| **Group join banner — headline** | `Join our group for +5% coins + a free pet!` | `Join the group — +5% coins + bonus pet` | `GroupRewardConfig.bannerHeadline`. Slightly tighter; keeps perks explicit. |
| **Group join banner — sub** | `Tap Join to open the group page, then rejoin to claim rewards.` | `Tap Join → open group → rejoin to claim.` | Same file `bannerSub`. Shorter; arrow reads fast on mobile. |
| **Group join — alt pool (unused by banner)** | Random line from `SocialFeedConfig.GroupJoinBanner` (e.g. `Group perks are live: a free pet when you join. Takes two taps!`) | Consolidate: either wire banner to **pick from this pool** or delete duplicate marketing intent from `SocialFeedConfig` | **Engineer:** `GroupJoinBanner.luau` reads `GroupRewardConfig` only — `SocialFeedConfig.GroupJoinBanner` is orphaned for this surface. Pick one source of truth. |
| **HUD toast — remote fail-soft** | Random from `MicrocopyConfig.RemoteLoadError` (e.g. `Couldn't sync that — give it another sec!`) | Keep pool; optionally add one line: `Back in a flash — retrying your data.` | Already Phase-4 friendly. Shown when `RemoteFailSafe.notifyRemoteFailure` fires (e.g. quest load). |
| **HUD toast — streak / retention** | Random from `MicrocopyConfig` streak pools via `RetentionController` | No change | Copy already audited in `RetentionWinbackMicrocopySpec.md`. |
| **HUD toast — first session** | Various `MicrocopyConfig.FirstSession*` | No change | See `FirstSessionOnboardingCopyPack.md`. |
| **Notification lane — idle** | No on-screen placeholder when queue empty | N/A | By design (`Phase4NotificationLaneJuiceSpec.md`): event-driven only. |
| **Achievement / [C] queue** | Title + body from achievement defs + `AchievementPopupConfig` | No change in this pass | Not empty-state heavy; unlock-driven. |
| **Loading screen — tip fallback** | `Loading...` (when `LoadingTipsConfig.Tips` empty) | `Loading the lobby…` | `LoadingScreen.local.luau` fallback. Slightly warmer; ellipsis matches wait state. |
| **Loading screen — VIP tips** | `` `[VIP] {line}` `` wrapping `MicrocopyConfig.PremiumLoadingTips` | Keep | Prefix signals perk without new strings. |
| **Store — FOMO badge (hot)** | Truncated `SocialFeedConfig.SocialProofStore` etc. | Keep | Pool-driven; truncate max 48 chars in `StorePanel.luau`. |
| **Store — limited stock badge** | Truncated `SocialFeedConfig.LimitedStock` | Keep | Same pattern. |
| **Store — row CTA (gems/dev products)** | `Buy` | `Grab` | Optional verb swap for simulator energy; low risk. |
| **Store — upgrade row CTA** | `Upgrade` | `Upgrade` | Fine as-is. |
| **Store — owned flash** | `OWNED!` → `YOURS!` → `Owned` | `YOURS!` → `Equipped` → `Owned` | Minor: second state could be `Equipped` if it reflects equip; confirm UX with design. |
| **Egg shop — world section title** | `{WorldDisplay} Eggs!` (e.g. `Grasslands Eggs!`) | `{WorldDisplay} eggs` | `UIController.wireEggStorePanel`: sentence case, exclamation optional; “Eggs!” is loud — softer still works. |
| **Egg shop — egg name on slot** | `eggDef.name:upper()` | Keep UPPER or switch to **Title Case** per `NumberFormattingStyleGuide` / panel style | **Engineer:** all-caps may fight Pets panel title case; visual consistency pass. |
| **Egg shop — empty / error** | Studio warnings only (`0 egg slots wired`) | N/A for players | Dev-only `warn` paths. |
| **Quest — empty daily/weekly slot** | `—` (em dash, `QuestPanel.resetEmptyQuestRow`) | `—` or `More quests soon` | Em dash is minimal; if slots should feel “coming soon,” use short line ≤18 chars. |
| **Quest — row title (active)** | `{title}  ({progress}/{target})` + `+{xp} Season XP` | Keep structure | Data-driven from `QuestConfig`. |
| **Quest — milestone complete sub** | `Complete` | `Done` | Slightly punchier; matches Phase 4 brevity. |
| **Quest — completion banner** | `QUEST COMPLETE!` | `QUEST CRUSHED!` | Hardcoded in `QuestPanel.playRowCelebration`; aligns with `MicrocopyConfig.QuestComplete` tone. |
| **Quest — completion subtitle** | Random `MicrocopyConfig.QuestComplete` | Keep pool | Already strong. |
| **Quest — 80%+ nudge** | Random `MicrocopyConfig.QuestProgress` | Keep pool | Already aligned. |
| **Quest — error / fail (gameplay)** | Random `MicrocopyConfig.QuestFail` | Keep | Separate from remote fail toast. |

---

## Row count

**29** table rows (including N/A / process notes).

---

## Follow-ups for Engineering

1. **Single source for group banner headline:** `GroupRewardConfig` **vs** `SocialFeedConfig.GroupJoinBanner` — avoid drift.
2. **Friend Bonus label:** single string template in `MicrocopyConfig` or `FriendBonusConfig` for localization and A/B.
3. **Quest empty slot:** if em dash tests poorly in QA, swap to one approved line from `MicrocopyConfig` (new small pool `QuestSlotEmpty`).

---

## Files referenced

- `DACStarterGui/FriendBonusHUD.luau`
- `DACReplicatedStorage/Config/GroupRewardConfig.luau`
- `DACReplicatedStorage/Config/SocialFeedConfig.luau`
- `DACStarterGui/GroupJoinBanner.luau`
- `DACReplicatedStorage/RemoteFailSafe.luau`
- `DACReplicatedStorage/Config/MicrocopyConfig.luau`
- `DACReplicatedFirst/LoadingScreen.local.luau`
- `DACStarterGui/StorePanel.luau`
- `DACStarterPlayerScripts/Controllers/UIController.luau` (egg store)
- `DACStarterGui/QuestPanel.luau`
