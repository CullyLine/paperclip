# Phase 4 — Loading tips & notification-queue alignment

**Purpose:** Track how **loading-screen** copy relates to Phase 4 voice (`docs/Phase4_TerminologyAndVoiceGlossary.md`), the **first-session hook** (*Every run pays off.*), and **HUD / notification-lane** strings so we do not paste the same line in every surface.

**Canonical code**

| Surface | Config / script |
|--------|------------------|
| Tip carousel + FOMO headline | `DACReplicatedStorage/Config/LoadingTipsConfig.luau`, `DACReplicatedFirst/LoadingScreen.local.luau` |
| VIP-only loading lines | `MicrocopyConfig.PremiumLoadingTips` |
| First-session tagline (single hook) | `MicrocopyConfig.FirstSessionTagline` — **not** mixed into `LoadingTipsConfig.Tips` |
| First-session / hatch nudges (notification lane) | `MicrocopyConfig.FirstSessionHatchNudge` etc. — gated separately from loading tips |

**Rotation (loading):** `LoadingScreen.local.luau` builds `tipsPool` = all `LoadingTipsConfig.Tips` in order, then appends `[VIP] {line}` entries when the player owns any pass. Tips advance on a ~3–5s loop (`tipIndex`); headline is one random pick per load from `LoadingTipsConfig.Headlines`.

---

## Audit addendum — POLA-404 (2026-03-22)

**Verified OK** — The string **Every run pays off.** does **not** appear in `LoadingTipsConfig.Tips` or `Headlines`. It remains only as `MicrocopyConfig.FirstSessionTagline` per POLA-291 / `docs/FirstSessionOnboardingCopyPack.md`.

**Counts (snapshot)**

| Pool | Count |
|------|------:|
| `LoadingTipsConfig.Tips` | 42 |
| `LoadingTipsConfig.Headlines` | 10 |
| `MicrocopyConfig.PremiumLoadingTips` | 6 (prefixed `[VIP]` when merged into loading pool) |

**Substring note:** Two base tips use the factual phrase *every run* (2x Coins / Roblox Premium economics), not the branded tagline — acceptable diversity vs. repeating the hook on every line.

**Discovery / store alignment:** No change required vs. `docs/Phase4_DiscoveryAndGamePageCopy.md`; loading tips are in-session education, not Creator update body text.
