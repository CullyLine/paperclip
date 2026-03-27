# Phase 4 — Terminology & voice glossary

**Purpose:** Canonical reference for player-facing copy after POLA-394 grep passes. Use with `DACReplicatedStorage/Config/MicrocopyConfig.luau` and panel hardcodes.

**Related:** `docs/CTAVerbConsistency.md`, `docs/ErrorMicrocopy_Phase4.md`, `docs/MicrocopyWhaleTermCleanup_Phase4.md`, `docs/RetentionWinbackMicrocopySpec.md`, `docs/FirstSessionOnboardingCopyPack.md`.

---

## 1. Voice pillars

| Pillar | Rule |
|--------|------|
| **Reward-forward** | Celebrate progress; flex lines hype *outcomes*, not shaming spend or skill. |
| **Bubbly / simulator** | Short, punchy, occasional caps for hype — not corporate or apologetic. |
| **Blame-free errors** | Never imply the player’s *connection* or *device* is at fault unless certain. Prefer “try again,” “didn’t load,” “still syncing.” |
| **No player “whale” framing** | Pet names like **Cosmic Whale** are OK; do not label the *player* whale or mock spend tiers in celebration copy. Use **mega** / vault-tier language where product specifies. |

---

## 2. Core terminology

| Term | Use |
|------|-----|
| **Driver** | Preferred address in session / streak / lobby copy (“speed demon,” “elite driver” variants OK). Avoid “user” in HUD. |
| **Coins** | Soft currency; lowercase in sentences unless title case in a headline. |
| **Gems** | Premium/grind currency from playtime, eggs, dailies — not “crystals” unless World/crystal unlock context. |
| **Crystals** | World unlock / progression currency where `World*` configs say so — don’t mix with gems in the same sentence without designer intent. |
| **Run** | A single drive until fuel ends or payout triggers; “lap” OK for flavor. |
| **Lobby** | Server/session social context — not “menu” unless literal menu UI. |
| **Pet Modifier** | Tutorial term for equipped pet bonus — keep capitalization in tutorial strings. |

---

## 3. CTA verbs (do not cross streams)

| Intent | Verb | Do **not** use for the same intent |
|--------|------|-------------------------------------|
| Take earned daily / BP / streak reward | **Claim** | Redeem |
| Spend coins or Robux on SKU | **Buy** | Claim |
| Enter a promo code | **Redeem** | Claim |
| Put on pet/car | **Equip** | Use |
| Increment stat with coins | **Upgrade** | Buy |
| Open egg after purchase | **Hatch** | Open |

---

## 4. Premium vs VIP

| Surface | Term |
|---------|------|
| Game Pass / monetization row | **Premium** or product name as in `GamePassConfig` |
| Loading tips / nametag / 2× line | **VIP** where legacy strings say VIP — don’t swap mid-panel without a full pass |

---

## 5. Error & soft-fail tone

- **~90 characters** max for soft-fail toasts where noted in specs.
- Prefer **“That didn’t load”** / **“try again in a second”** over **“check your connection.”**
- **Soft-fail purchase cancelled:** calm, **nothing charged** — accurate.
- **Cooldown / inventory full:** name the blocker, one fix — no guilt.

---

## 6. Numbers & placeholders

- Preserve `{AMOUNT}`, `{COINS}`, `{STREAK}`, `{ITEM}`, `{ACTION}`, etc. — engineer-injected; don’t break token names.
- Formatting of large numbers follows `docs/NumberFormattingStyleGuide.md` at display time — microcopy strings stay template-simple.

---

## 7. Emoji & punctuation

- **Event / countdown** lines may use ⏳ ⚠️ 🚨 — keep rare in HUD toasts.
- **Streak / fire** 🔥 allowed in `PlayStreak` pool — don’t add new emoji to error pools without UX review.

---

*Last updated: Phase 4 terminology pass (POLA-397).*
