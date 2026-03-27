# Hardcoded string audit — Phase 4 new HUD surfaces

**Scope:** User-visible copy wired in code for **friend bonus HUD**, **trophy / achievements UI**, **leaderboard surfaces**, and **social feed–related HUD** (banners, server drop feed, retention). Excludes Studio-only static labels unless noted (not visible from Luau alone).

**Reference:** Product copy pools live primarily in `DACReplicatedStorage/Config/MicrocopyConfig.luau`, `SocialFeedConfig.luau`, `AchievementPopupConfig.luau`, `LeaderboardTextConfig.luau`, and `GroupRewardConfig.luau`. This table flags strings that **bypass** those modules or use **parallel** config files.

---

| File | Approx. line | String snippet (or pattern) | Suggested owner |
|------|--------------|----------------------------|-----------------|
| **Friend bonus** | | | |
| `DACStarterGui/FriendBonusHUD.luau` | 57–58 | `` `Friends Bonus: {pct}` `` (prefix; fallback pct `+10%`) | New key in `MicrocopyConfig` or `FriendBonusConfig` (label template + default percent) |
| `DACServerScriptService/Services/FriendBonusService.luau` | 30–36 | `+20%`, `+10%`, `+0%` (tier labels) | Already numeric tiers in `FriendBonusConfig` — move percent strings into same config or shared `MicrocopyConfig` pool |
| `DACServerScriptService/Services/FriendBonusService.luau` | 97–100 | Fallback template `"{PLAYER} is playing with {FRIEND}! {PERCENT} coins!"` when `FriendPlayFeed` pick is empty | Keep as server fallback but prefer ensuring `SocialFeedConfig.FriendPlayFeed` is never empty; or single `MicrocopyConfig` fallback |
| **Trophy / achievements** | | | |
| `DACStarterGui/TrophyCasePanel.luau` | 113 | `` `{unlockedN}/{total} Achievements Unlocked` `` | `MicrocopyConfig` or small `TrophyCaseConfig` string |
| `DACStarterGui/TrophyCasePanel.luau` | 138 | Tab labels via `string.upper(key)` → `ALL`, `DRIVING`, `COLLECTION`, `ECONOMY`, `SOCIAL`, `SECRET` | Localizable category labels config (not Microcopy toasts; separate `TrophyCaseCopy` or extend `AchievementPopupConfig` metadata) |
| `DACStarterGui/TrophyCasePanel.luau` | 169 | Notification badge initial `Text="0"` | Intentional numeric placeholder — OK as code-only |
| `DACStarterPlayerScripts/Controllers/AchievementController.luau` | 140–142 | Missing def: `headline = "ACHIEVEMENT"`; `subline = id` | `MicrocopyConfig` unknown-achievement strings |
| `DACStarterPlayerScripts/Controllers/AchievementController.luau` | 151–157 | `CATEGORY COMPLETE!`; `100% ACHIEVEMENTS!` | `AchievementPopupConfig` or `MicrocopyConfig` milestone headlines |
| `DACStarterPlayerScripts/Controllers/AchievementController.luau` | 427 | `` `{cur} / {tgt}` `` progress fraction | Acceptable formatting; optional localized ` / ` via config |
| `DACStarterGui/TrophyCasePanel.luau` | 41 | Reads `Title`, `ProgressLabel`, etc. from pre-built UI — **copy may live in StarterGui** | Studio instances: audit in Roblox; should eventually reference config or documented string table |
| **Leaderboard (world SurfaceGui + motivation)** | | | |
| `DACStarterGui/LeaderboardPanel.luau` | 130 | `Loading…` (Unicode ellipsis) | `LeaderboardTextConfig` or `MicrocopyConfig` loading line |
| `DACStarterGui/LeaderboardPanel.luau` | 139 | `Couldn't load.` | Error pool in `LeaderboardTextConfig` |
| `DACStarterGui/LeaderboardPanel.luau` | 142–143 | `No rankings yet.` / `No rebirth rankings yet.` | Same |
| `DACStarterGui/LeaderboardPanel.luau` | 155 | Fallback player name `Unknown` | Low priority; could stay code-only |
| `DACStarterGui/LeaderboardPanel.luau` | 179 | Rank `` `#{rank}` `` | Formatting — OK |
| `DACStarterGui/LeaderboardPanel.luau` | 79 | `` `{format} studs` `` for distance stat | Unit string in config if localizing |
| `DACStarterGui/LeaderboardPanel.luau` | 230 | `Rival` fallback name | Same as `Unknown` |
| `DACStarterGui/LeaderboardPanel.luau` | 257–258 | Tab titles `Distance`, `Rebirths` | `LeaderboardTextConfig` tab labels |
| `DACReplicatedStorage/Config/LeaderboardTextConfig.luau` | (entire module) | Motivation pools (`RankUpMessages`, `TopTenMessages`, etc.) | **Already centralized** — not Microcopy; fine for i18n as one `LeaderboardTextConfig` locale table later |
| `DACStarterGui/LeaderboardPanelDesignSpec.luau` | 31, 62, 99 | Spec-only: `"Leaderboard"`, `"No friends here yet — invite some!"`, `"YOUR RANK"` | Documentation; implement when menu panel ships — should mirror config keys |
| **Social feed & related HUD** | | | |
| `DACStarterPlayerScripts/Controllers/VFXController.luau` | 6915–6916 | Fallback names `Someone`, `Pet` | Optional `MicrocopyConfig` anonymized labels |
| `DACStarterPlayerScripts/Controllers/VFXController.luau` | 6836–6839 | Fallback hatch template `"{PLAYER} hatched {PET} ({RARITY})!"` | Align with `SocialFeedConfig` pools; duplicate of intent |
| `DACStarterPlayerScripts/Controllers/RetentionController.luau` | 113–116 | `Daily reward: ready to claim!`; `` `Next daily reward in {formatDuration(left)}` `` | `MicrocopyConfig` retention lines |
| `DACStarterPlayerScripts/Controllers/RetentionController.luau` | 124–126 | `Battle Pass: …`; `Battle Pass: max tier reached this season` | `MicrocopyConfig` or `BattlePassConfig` copy |
| `DACStarterPlayerScripts/Controllers/RetentionController.luau` | 132 | `` `Egg pity: {pity} hatch(es) since last rare+` `` | `MicrocopyConfig` |
| `DACStarterPlayerScripts/Controllers/RetentionController.luau` | 59 | `soon` (duration formatter) | Micro-sting in shared time-format helper |
| `DACStarterGui/EventBanner.luau` | — | Default `headlineLine` before remote: `MicrocopyConfig.FounderEventBannerHeadlines[1]` | Active founder state uses `FounderEventBannerHeadlines` / `FounderEventCountdown` only; see `docs/Launch_EventWindowConfig_Checklist.md` |
| `DACStarterGui/EventBanner.luau` | 160 | `` `Ends in {formatCountdown(left)}` `` subline | `MicrocopyConfig` event strings |
| `DACReplicatedStorage/Config/GroupRewardConfig.luau` | 25–26 | `bannerHeadline`, `bannerSub` (group join banner) | **Config-owned** — good pattern; not Microcopy |
| `DACStarterGui/GroupJoinBanner.luau` | 40–41 | Assigns text from `GroupRewardConfig` | No extra hardcoding — OK |

---

## Summary

| Area | Bypass Microcopy? | Notes |
|------|-------------------|--------|
| Friend bonus chip | Yes — prefix + tier percents in service/HUD | Small refactor: one template + config percents |
| Trophy case | Partial — progress + ALL caps tabs | Achievement titles/descriptions already in `AchievementPopupConfig` |
| Achievement toasts | Yes — milestone headlines + missing-id fallback | Move strings to `AchievementPopupConfig` |
| World leaderboard | Yes — status/tab/error strings in `LeaderboardPanel.luau` | Motivation copy already in `LeaderboardTextConfig` |
| Social feed banner | Mostly `SocialFeedConfig`; fallbacks in `VFXController` + `FriendBonusService` | Tighten fallbacks; avoid duplicate hatch template |
| Retention AFK popup | Yes — `buildContextLines` | High visibility; good candidate for `MicrocopyConfig` |

**Row count (data rows in table above):** 30
