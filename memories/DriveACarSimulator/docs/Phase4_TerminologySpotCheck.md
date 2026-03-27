# Phase 4 — Terminology spot-check (POLA-397)

**Method:** Compared 10 high-traffic `MicrocopyConfig` surfaces (HUD, shop/payout, errors) against `docs/Phase4_TerminologyAndVoiceGlossary.md` and existing audits (`CTAVerbConsistency`, `ErrorMicrocopy_Phase4`, `MicrocopyWhaleTermCleanup_Phase4`).

**Scope constraint:** Max two pages; prioritized HUD, shop, and errors.

---

## Summary

| Result | Count |
|--------|-------|
| Aligned | 6 |
| Mismatch / gap | 4 |

**Trivial fixes applied in-repo:** `MicrocopyConfig.luau` — `RemoteLoadError`, `SoftFailRemoteTimeout`, one `PurchaseFail` line, first line of `EggFail` (matches `docs/ErrorMicrocopy_Phase4.md` proposed text). **Engineer follow-up:** soften remaining `CodeRedeemError` “Invalid” openers in a future pool refresh (see row 8); optional `SoftFailInventoryFull` trim per error audit.

---

## Spot-check table

| # | Config key | Sample line reviewed | Verdict | Notes |
|---|------------|----------------------|---------|-------|
| 1 | `DailyRewardClaimButtonDefault` | `Claim reward` | OK | Matches glossary §3 — **Claim** for earned rewards; concise vs redundant “daily.” |
| 2 | `RemoteLoadError` | *(was)* `Oops, data didn't arrive — check your connection and retry!` | **Fixed** | Violated glossary §5; replaced per `ErrorMicrocopy_Phase4` with “That didn’t load. Try again in a second.” |
| 3 | `CoinGainSmall` | `+{AMOUNT} coins` | OK | “coins” terminology §2; placeholder preserved. |
| 4 | `GemGain` | `Precious! +{AMOUNT} gems!` | OK | “gems” §2; hype tone §1. |
| 5 | `PayoutTitleRunComplete` | `Run complete!` | OK | Short run-end chrome; consistent with “run” §2. |
| 6 | `PurchaseFail` | *(was)* `Can't afford it NOW, but future you definitely can!` | **Fixed** | Replaced with “Not enough coins yet — one more run usually covers it.” per error audit. |
| 7 | `EggFail` | *(was)* `Need more gems for this egg!` | **Fixed** | First line now includes playtime reassurance per error audit. |
| 8 | `CodeRedeemError` | `Invalid code — but don't give up, new ones drop all the time!` | **Soft mismatch** | `ErrorMicrocopy_Phase4` asks to avoid harsh “Invalid” openers; pool refresh deferred — not a one-line trivial fix across variants. |
| 9 | `SoftFailRemoteTimeout` | *(was)* `We waited… nothing yet. Try again — networks have moody days!` | **Fixed** | Replaced with neutral recovery: “We didn't get an answer in time. Tap again — nothing was lost.” |
| 10 | `FirstSessionWelcomeToast` | `Welcome — your first drive banks real coins. Tap Drive when you're ready!` | OK | Onboarding voice; **Drive** CTA matches tutorial; “coins” §2. |

---

## Files touched (this pass)

| File | Change |
|------|--------|
| `docs/Phase4_TerminologyAndVoiceGlossary.md` | Created — canonical glossary stub for Phase 4. |
| `docs/Phase4_TerminologySpotCheck.md` | This document. |
| `DACReplicatedStorage/Config/MicrocopyConfig.luau` | Four string edits (rows 2, 6, 7, 9). |

---

*POLA-397 — Content Strategist — Mar 2026.*
