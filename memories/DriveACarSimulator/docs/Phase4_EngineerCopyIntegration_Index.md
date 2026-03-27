# Phase 4 — Engineer ↔ content integration index

**Purpose:** Single map for where player-facing copy lives, how engineers wire it, and how Content Strategy re-validates after large Luau string drops.

**Player FAQ pair:** [`docs/player_onboarding_faq.md`](player_onboarding_faq.md) (new players) · [`docs/midgame_systems_faq.md`](midgame_systems_faq.md) (mid-game systems). Quick hub: [`docs/PlayerFAQ.md`](PlayerFAQ.md).

| Doc | Role |
|-----|------|
| `docs/phase4-p0-spec-parity.md` | **P0 parity:** config ↔ server ↔ UI alignment checklist (POLA-634 / 667 / 668) |
| `docs/phase4-milestone-fusion-parity.md` | **Milestone + fusion parity:** POLA-745 anchor — ceremony + pet fusion layers (cross-links `phase4-p0-spec-parity.md`) |
| `docs/HardcodedStringAudit.md` | Surfaces that still bypass central config (refactor backlog) |
| `docs/CopyPolishAudit.md` | Config + server parity notes |
| `docs/MicrocopyWhaleTermCleanup_Phase4.md` | Whale-term policy + grep |
| `docs/CTAVerbConsistency.md` | Claim / Buy / Hatch / Redeem alignment |
| `docs/Phase4_CopyGrepReport.md` | **Dated** output of section 4 greps (re-run after each major string pass) |
| `docs/Phase4_LaunchCopyQAChecklist.md` | Manual spot-checks (esp. §2 after config/UI churn) |
| `PreLaunchChecklist.md` | Holistic launch verification |

---

## 1. Canonical config modules (copy pools)

Primary: `DACReplicatedStorage/Config/MicrocopyConfig.luau`, `LoadingTipsConfig.luau`, `SocialFeedConfig.luau`, `AchievementPopupConfig.luau`, `LeaderboardTextConfig.luau`, `FriendBonusConfig.luau`, `GroupRewardConfig.luau`, `WorldUnlockConfig.luau`, `FomoBadgeLabelConfig.luau`, `DailyRewardConfig.luau`, `EggConfig.luau`, `PetConfig.luau`, `FirstTimeConfig.luau`, `DevProductConfig.luau`, `GamePassConfig.luau`.

---

## 2. Panels & controllers (wiring)

GUI shells live under **StarterGui** per `AGENTS.md`; scripts bind text via `WaitForChild` + config. Key scripts: `DACStarterGui/*.luau`, `DACStarterPlayerScripts/Controllers/*.luau`, `DACServerScriptService/Services/*.luau`.

---

## 3. When engineers land a “major string drop”

1. Touching only configs → Content still runs §4 greps + §2 checklist (fast).
2. Touching HUD/panels/controllers → Full §4 + §2 + spot-check `HardcodedStringAudit` rows for those files.
3. Update `docs/Phase4_CopyGrepReport.md` in the same PR or immediately after merge.

---

## 4. Ripgrep commands (maintenance — from repo root)

Run with **ripgrep** (`rg`) when available. On Windows without `rg` on `PATH`, use IDE search or Git/Cursor grep with the same patterns.

**Policy & tone**

```bash
rg -n "whale|Whale" --glob "*.luau" memories/DriveACarSimulator
```

Expect: pet species (`cosmic_whale`, “Cosmic Whale”), loading tips, product-tier comments, Microcopy policy comments — **not** new player-directed “whale” insults in celebration lines (`docs/MicrocopyWhaleTermCleanup_Phase4.md`).

**Placeholder / ship risk**

```bash
rg -n "lorem|Lorem|\\bTBD\\b|\\bFIXME\\b" --glob "*.luau" memories/DriveACarSimulator
```

Review hits: dev comments and `TBD` in sound spec comments are OK; **player-visible** `TBD`/`lorem` must be zero.

**Anti-pattern CTAs**

```bash
rg -n "Click here|click here" --glob "*.luau" memories/DriveACarSimulator
```

Expect: **no** hits (prefer concrete verbs per `docs/CTAVerbConsistency.md`).

**Section sign (avoid in product UI copy)**

```bash
rg -n "§" --glob "*.luau" memories/DriveACarSimulator
```

Expect: spec cross-refs in **comments** only; no `Text =` / user-visible strings containing `§`.

**Optional: asset placeholder density**

```bash
rg -n "rbxassetid://0" --glob "*.luau" memories/DriveACarSimulator
```

Track trend over time; Easter egg / manifest placeholders are documented in `CopyPolishAudit` / `EasterEggConfig.luau` headers.

---

## 5. Ownership

- **Engineers:** wire new strings through configs or document in `HardcodedStringAudit` if temporarily hardcoded.
- **Content Strategist:** refresh `Phase4_CopyGrepReport.md`, tick `Phase4_LaunchCopyQAChecklist.md` §2, align `PreLaunchChecklist.md` if launch dates or SKUs change.
