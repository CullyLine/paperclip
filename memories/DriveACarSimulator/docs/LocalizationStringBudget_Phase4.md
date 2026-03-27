# Localization string budget — Phase 4 (prep only)

Purpose: give translators and engineers **character budgets** before any locale ships. English is the source; German and Brazilian Portuguese typically need **~25–35% more horizontal space** for the same meaning (compounds in DE; articles/clitics in PT-BR). No translation work in this ticket — budgets and risk flags only.

References:

- `DACStarterGui/HudNotificationToastDesignSpec.luau` — `TOAST_WIDTH = 320`, body **GothamMedium 15**, wrapped.
- `DACStarterPlayerScripts/Controllers/UIController.luau` — `TOAST_WIDTH`, toast layout.
- `DACReplicatedStorage/Config/MicrocopyConfig.luau` — copy pools and static strings.

---

## 1. Recommended max character counts

| Surface | Role | EN target (soft) | EN hard max | Notes for DE / PT-BR |
|--------|------|------------------|-------------|----------------------|
| **HUD toast** | One short line (ideal) | ≤ 42 | ≤ 55 | Prefer one line; if longer, expect 2 wrapped lines inside 320px rail. |
| **HUD toast** | Full message (wrapped) | — | ≤ 120 total | Same toast width; multi-line is OK but hurts scan speed — keep punchy. |
| **HUD toast** | Soft-fail / calm retry (POLA-354 pool) | ≤ 75 | **≤ 90** | Aligns with `MicrocopyConfig` soft-fail comment (~90 chars max). |
| **Shop / store CTA** | Primary button (`Buy`, `Upgrade`, short verb + price) | ≤ 10 | ≤ 18 | Narrow `TextButton` slices (e.g. ~22–32% of row width in `StorePanel.luau`); long DE verbs (`Kaufen`, `Verbessern`) still need room. |
| **Shop / panel** | Secondary label on same row | ≤ 24 | ≤ 36 | Car/egg row titles; truncate with ellipsis if needed. |
| **Daily reward CTA** | Pre-built `ClaimBtn` | ≤ 14 | ≤ 22 | `DailyRewardClaimButtonDefault` / `Progress` — button must not clip. |
| **Tutorial overlay** | Step title | ≤ 22 | ≤ 32 | `FirstSessionTutorialStep*Title` — single line preferred. |
| **Tutorial overlay** | Step body (one paragraph) | ≤ 280 | ≤ 380 | `FirstSessionTutorialStep*Body` — allow wrap; DE often +30% line count. |
| **Payout / flex line** | Brag line with `{COINS}` etc. | ≤ 85 | ≤ 110 | Numbers widen; leave margin for formatted currency. |

**Rule of thumb:** If EN is at the **hard max**, plan for **~1.3× character count** in DE or PT-BR for the same slot, or **shorten EN** / allow **two lines** / **ellipsis**.

---

## 2. Five English strings likely to overflow or read poorly in German or Portuguese

Strings chosen from `MicrocopyConfig.luau` samples — risk = **length + idiom + compounds** (not a judgment of translation quality).

| # | Config key / area | English line | Why DE / PT-BR is risky |
|---|-------------------|--------------|-------------------------|
| 1 | `PremiumLoadingTips[1]` | `VIP perk: You earn 2x coins on EVERY run. Others wish they were you!` | Long dual sentence; DE often uses longer promotional phrasing; PT-BR may need reordering (“2x” + “VIP” spacing). |
| 2 | `ReturnStreakWelcome[1]` | `You're BACK — and still on a {STREAK}-day streak?! Main character energy!` | Idioms (“main character energy”) do not localize 1:1; DE compound streak phrasing adds width. |
| 3 | `PayoutFlexMega[1]` | `ULTRA PAYDAY! {COINS} coins — that's a LOBBY-RESETTING run!` | ALL CAPS + coined hype (“lobby-resetting”); DE marketing caps and compounds inflate line length. |
| 4 | `FirstSessionPetEquipNudge[2]` | `Unlocked pets only boost runs when equipped. One tap, instant lift!` | Two imperatives; PT-BR “equipped” / pet grammar often longer per line. |
| 5 | `SoftFailInventoryFull[1]` | `Inventory's full — make room, then {ITEM} can come home!` | `{ITEM}` may be a long pet/egg name; DE “Inventar ist voll” + clause order can exceed EN width when item name is inserted. |

**Mitigation for #5:** Keep `{ITEM}` placeholder max length documented per surface (e.g. 24 chars EN) or use **ellipsis** on dynamic names (see §3).

---

## 3. Luau pattern: ellipsis / end truncation (already in use)

**Recommendation:** For fixed-width labels (banners, leaderboard names, single-line HUD chips), set:

```lua
label.TextTruncate = Enum.TextTruncate.AtEnd
```

**Existing usage in this codebase** (keep consistent for localized text):

- `DACStarterGui/EventBanner.luau` — headline / sublabel.
- `DACStarterGui/LeaderboardPanel.luau` — name and stat labels.
- `DACStarterPlayerScripts/Controllers/VFXController.luau` — label truncation.

**Not a substitute for toast bodies:** HUD toasts use **wrapped** `TextLabel`s in a 320px rail; truncation hides copy. Prefer **shorter translation** or **extra line wrap** for toasts. Use `TextTruncate.AtEnd` where the design is **single-line** and overflow is worse than an ellipsis.

**Optional dynamic shrink:** For rare cases where one label must fit (e.g. nametag), `TextScaled = true` appears in `TitleNametag.local.luau` / `VipNametag.local.luau` — use sparingly; it can make localized text unreadably small. Prefer budget + ellipsis first.

---

## 4. Engineer checklist (when locales ship)

1. Apply §1 budgets per surface before locking `.json` / localization table.
2. Grep for new `TextLabel`/`TextButton` strings; set `TextTruncate` on single-line chrome.
3. Playtest **DE** and **PT-BR** on **720p** and **1080p** — worst-case for toast rail width is narrow viewports (inset still 320px fixed width; height grows with wrap).

---

*POLA-426 — Content: Localization string budget + overflow risk notes.*
