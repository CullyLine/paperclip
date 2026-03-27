# First-session onboarding copy — QA (POLA-293)

**Audit date:** 2026-03-22  
**Scope:** Strings and surfaces that shape a **brand-new player’s first session**, plus dependency **POLA-291** (dedicated first-session pack).  
**Whale-term policy:** `docs/MicrocopyWhaleTermCleanup_Phase4.md`

---

## 1. Dependency status (POLA-291)

| Item | Status |
|------|--------|
| **POLA-291** (*First-session onboarding copy — implement spec*) | **In progress** (Engineer assigned; not `done` at audit time). |
| **`docs/FirstSessionOnboardingCopyPack.md`** (referenced by POLA-291) | **Not present** in this workspace — treat planned first-session-only lines / hook budget as **not yet verifiable on disk**. |

**Implication:** Rows that depend on POLA-291 wiring (welcome modal, first-payout-only hook, empty trophy case line, daily-streak framing per spec) are marked **Pending POLA-291** below. This document still records QA for **what is already shipped** (tutorial, session toast, loading, monetization copy).

---

## 2. Pass / fail matrix (current codebase)

| Surface | Source | Truncation / readability | Tone | Whale-term policy | Verdict |
|---------|--------|---------------------------|------|-------------------|---------|
| **Tutorial steps 1–5** (title + body) | `DACServerScriptService/Services/TutorialService.luau` (`payloads` table) | Bodies wrap in pre-built bubble (`TutorialOverlay`); longest line ~95 chars — OK for 320px-style layout. | Clear, action-led, Phase-4 bubbly. No shame. | No `whale` / `Whale` in tutorial strings. | **PASS** |
| **Session-start welcome toast** | `MicrocopyConfig.SessionWelcome` (+ win-back / streak branches) via `Bootstrap.local.luau` | HUD toast rail width 320px, `TextWrapped = true` (`UIController.showNotification`) — long lines wrap vertically, not clipped. | For **literal first session**, `streak < 2` uses **general** welcome pool — includes high-energy lines (e.g. “LET’S EAT.”) that assume prior context. Product may want a **first-session-only** subset (POLA-291). | Pools cleaned in Phase 4; no player-“whale” framing in these tables. | **PASS** (policy); **tone note** (first-time vs returning not differentiated). |
| **Return / win-back / streak welcome** | `ReturnStreakWelcome`, `SessionWinback7d`, `SessionWinback14d`, `SessionWelcomeStreak` | Same toast behavior as above. | N/A for first session unless streak/return data fires incorrectly. | **PASS** | **N/A** first session default path |
| **New player calm window** | `DACReplicatedStorage/NewPlayerCalmWindow.luau` | Defers other toasts — no user-visible copy in module. | Reduces noise — aligns with onboarding goals. | N/A | **PASS** (behavior) |
| **Loading tips + headlines** | `LoadingTipsConfig.luau`, `LoadingScreen.local.luau` (+ optional `[VIP]` tips) | Tip label uses rotating one-liners; `Cosmic Whale` appears as **pet species** in a tip — acceptable per whale doc. | Simulator hype; OK for first load. | Pet name + established taxonomy only. | **PASS** |
| **Run-end payout flex lines** | `MicrocopyConfig.PayoutFlex*` | Shown on payout panel, not tutorial — first run will see flex lines. | Reward-forward. | Optional pools per Phase 4 whale cleanup — no “you’re a whale” phrasing in celebration lines reviewed. | **PASS** |
| **First-time ceremonies** (first car, hatch, rebirth, etc.) | `FirstTimeConfig.luau` | Ceremony popups — separate from tutorial bubble. | Celebratory. | Spending tier block uses **tierName** “Whale” at 500 R$ — **established spend-milestone taxonomy** (same class as badges / thank-you flow); not new celebration insult. | **PASS** per policy |
| **Game pass: Infinite Gas** | `GamePassConfig.luau` → `infinite_gas.description` | N/A | Store SKU line ends with **“The whale flex pass.”** | Uses “whale” as **product punchline**, not HUD celebration. Align with `MicrocopyWhaleTermCleanup_Phase4.md` *store vs celebration* split — **optional** softening if product wants zero public “whale” outside tier badges. | **PASS** (policy); **optional copy tweak** |
| **Dev product: 3k Gems** | `DevProductConfig.luau` → `gems_pack_m.description` | N/A | “**Whale-friendly** gem stack…” | Same as above — storefront. | **PASS** (policy); **optional copy tweak** |
| **POLA-291 spec surfaces** (welcome modal, single hook line, first payout, empty trophy, daily framing) | Not found in repo / not wired | — | — | — | **Pending POLA-291** |

---

## 3. Needs Engineer (keys / wiring)

| Planned item (from POLA-293 description) | Blocked on | Notes |
|------------------------------------------|------------|--------|
| First-session **hook budget** (at most one nudge line in first session, per POLA-291 spec intent) | POLA-291 + spec file on disk | No `firstSession` / hook counter located in client bootstrap at audit time. |
| Dedicated **first-session welcome** / payout / hatch / trophy strings | POLA-291 | Tutorial uses `TutorialService` hardcoded table; no separate MicrocopyConfig table for “first session only” beyond general pools. |
| **`docs/FirstSessionOnboardingCopyPack.md`** | Content / merge | Needed for final string freeze vs Studio QA. |

---

## 4. Optional config-only one-line fixes (P2, product discretion)

Non-blocking; only if leadership wants **zero** casual “whale” outside established tier names:

1. **`GamePassConfig.luau`** — `infinite_gas.description`: replace “The whale flex pass.” → e.g. “The infinite flex pass.” or “Nonstop runs — maximum flex.”
2. **`DevProductConfig.luau`** — `gems_pack_m.description`: replace “Whale-friendly” → e.g. “High-roller” or “Big-stack”.

---

## 5. Studio verification checklist (manual)

When POLA-291 lands, re-run in Roblox Studio:

- [ ] **Tutorial:** Steps 1–5 — title/body readable on **phone** + **desktop**; highlight arrows don’t cover critical CTAs (`TutorialOverlayReadability.md` cross-ref).
- [ ] **Session toast:** Appears after load; during calm window, confirm deferred toasts flush after 60s without overlap spam.
- [ ] **First payout / flex:** No placeholder tokens (`{COINS}` etc.) visible raw in UI.
- [ ] **Whale grep:** `rg -n "whale|Whale" --glob "*.luau" memories/DriveACarSimulator` — confirm new celebration lines don’t label the **player** “whale” outside established tier / pet name / SKU context.

---

## 6. Summary

- **Shipped paths** (tutorial, session welcome, loading, milestones): **policy-compliant** on whale terms; tutorial copy **PASS**.
- **Differentiation:** True “first session only” copy pack and **single-hook** rule are **not** verifiable until **POLA-291** completes and `FirstSessionOnboardingCopyPack.md` exists in tree.
- **Optional:** Two storefront strings use informal “whale” — acceptable under current Phase 4 doc; soften only if product standards tighten.
