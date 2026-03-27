# Social copy alignment — Phase 4 (invite / group / friend bonus)

**Scope:** `MicrocopyConfig`, `SocialFeedConfig`, `FriendBonusConfig`, `GroupRewardConfig`, cross-check `LoadingTipsConfig`, and Luau-wired HUD strings not in config tables.

**Tone baseline:** Phase 4 reward-forward, bubbly, confident — no player-directed “whale” framing (see `docs/MicrocopyWhaleTermCleanup_Phase4.md`, `docs/RetentionWinbackMicrocopySpec.md`).

---

## Canonical numbers (single source of truth)

| Surface | Fact | Source |
|--------|------|--------|
| Friend tier A | 1–2 in-server friends among Roblox friends online → **+10%** coin multiplier | `FriendBonusConfig.tierOneMinFriends` / `tierOneMultiplier` |
| Friend tier B | 3+ in-server friends → **+20%** | `FriendBonusConfig.tierTwoMinFriends` / `tierTwoMultiplier` |
| Group run bonus | **+5%** coins on runs (multiplier) | `GroupRewardConfig.coinBonusMultiplier` |
| Group join headline | **+5% coins + free pet** (banner) | `GroupRewardConfig.bannerHeadline` |
| Group first-time claim | Coins + gems + exclusive pet (`group_member`) | `GroupRewardConfig.joinRewardCoins` / `joinRewardGems`; `PetConfig` `group_member` |

---

## Alignment table (old → proposed)

Only rows where **facts** or **headline promises** diverge between channels. Proposed lines stay minimal; implement in config when Engineering schedules a pass.

| Location | Old line | Issue | Proposed new line |
|----------|----------|--------|-------------------|
| `SocialFeedConfig.GroupJoinBanner` (several entries) | e.g. “Join the crew — bonus pet for group members…” | Promises **pet** only; omits **+5% run coins** that `GroupRewardConfig.bannerHeadline` states. Players may think group value is pet-only. | Rotate at least two lines that include both: e.g. “Join the crew — **+5% coins on runs** and a bonus pet. No spam, just perks!” |
| `LoadingTipsConfig.Headlines` | `"GROUP: Join the community — bonus pet on join, no strings!"` | Same gap: no **+5%** vs banner. | `"GROUP: +5% coins + bonus pet — join the community!"` (keep short; “no strings” optional in body tips, not headline) |
| `SocialFeedConfig.FriendPlayFeed` | `"{PLAYER} is playing with {FRIEND}! {PERCENT} coins!"` | `{PERCENT}` expands to `+10%` / `+20%`; trailing **“coins!”** reads like a currency amount, not a **bonus**. | `"{PLAYER} is playing with {FRIEND}! {PERCENT} coin bonus on runs!"` |
| `DACStarterGui/FriendBonusHUD.luau` | `` `Friends Bonus: {pct}` `` | Label not in `MicrocopyConfig`; “Friends Bonus” vs payout chip **“Friends x{MULT}”** (`MicrocopyConfig.PayoutBadgeFriendsFormat`) — adjacent systems use slightly different nouns. | Optional: **`Friend play: {pct}`** or **`Friends: {pct}`** to echo “friend play” in `FriendBonusService` / feed without adding config churn. |

---

## Reviewed — no change required

- **`MicrocopyConfig.SocialInviteFriendSoft`** — Soft invite; no numeric claims; consistent with “bring a crew / share the lane” voice.
- **`MicrocopyConfig.PayoutBadgeGroupFormat` / `PayoutBadgeFriendsFormat`** — Short chip labels; numbers come from runtime multipliers; align with `GroupRewardConfig` / `FriendBonusConfig` math.
- **`LoadingTipsConfig.Tips`** (friends + group tips) — Matches **+20% at 3+ friends** and group **bonus pet**; acceptable alongside banner **+5% + pet**.
- **`SocialFeedConfig.GroupRewardClaim` / `GroupMemberJoinFeed`** — Celebration / feed; pet-forward is fine; first-time coins/gems are secondary UX.
- **`SocialFeedConfig.PremiumUpsell`** — “Your **friends** with VIP…” uses social “friends,” not Roblox friend-bonus mechanics — no factual conflict.

---

## Engineer follow-up (strings outside config)

| File | Notes |
|------|--------|
| `DACStarterGui/FriendBonusHUD.luau` | HUD text is **hardcoded** (line ~64). Any label change from the table above is a small edit here; consider a `MicrocopyConfig` key later if this chip grows more variants. |
| `FriendBonusService.luau` | Fallback template when feed pool empty: `"{PLAYER} is playing with {FRIEND}! {PERCENT} coins!"` — update in sync if `FriendPlayFeed` line 1 changes. |

---

## Optional backlog (not blocking)

- If `SocialFeedConfig.GroupJoinBanner` is ever retired in favor of **only** `GroupRewardConfig` banner strings, delete duplicate group CTAs to reduce drift.
- `StorePanel.luau` generates `PremiumUpsell` from `SocialFeedConfig` at runtime — already config-driven; no copy conflict found.
