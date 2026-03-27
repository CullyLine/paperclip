# Roblox Creator — Game page & discovery copy kit (paste-ready)

**Ticket:** POLA-477 · **Parent:** POLA-104 (Phase 4) · **Date:** 2026-03-22  

**Canonical masters (do not fork — merge deltas here when refreshing):**

| File | Role |
|------|------|
| `GamePageContent.md` | Original title matrix, 997-char baseline, tags, thumbnails |
| `docs/GamePageAndDiscoveryCopy.md` | Phase 4 keyword delta, social one-liners, discovery notes |
| `docs/StorePageCopy_Phase4.md` | Short description variants + feature bullets |
| `docs/Phase4_DiscoveryAndGamePageCopy.md` | Weekly Creator update patterns |

This file is the **single paste block** for the Creator Dashboard **Experience** fields plus discovery notes. Counts are for the usual **~1000 character** long-description limit.

---

## 1. Game title (Creator “Experience name”)

**Recommended:** `Drive a Car Simulator`

**Alternates (A/B only if testing):**

- `Drive a Car Simulator: Pets & Rebirth` — extra keywords; watch mobile truncation.
- `Car Simulator: Drive & Hatch` — niche “hatch” SEO; weaker brand match.

---

## 2. Long description — Phase 4 aligned (997 characters)

Paste the block below into the **Description** field. It matches the current loop (cars, pets, eggs, rebirth, four worlds, currencies, passes, codes, Premium) and Phase 4 polish (achievements, trophy case, milestones, HUD/notification lane, friend/group bonuses).

```
🚗 DRIVE fast cars on ENDLESS highways! HATCH rare pets! REBIRTH for POWER!

🌍 4 WORLDS — Grasslands → Desert → Tundra → Neon City (up to 10x coins!)

⭐ FEATURES:
🚗 11+ cars — Rusty Runabout to Void Runner
🐾 14+ pets (Common→MYTHIC), equip 8 for huge multipliers
🥚 6 eggs — chase the Cosmic Whale (Power: 550!)
🏆 Achievements + trophy case for completionists
✨ Phase 4: milestone pops, smarter HUD & notification lane (mobile-friendly)
🔄 Rebirth = permanent speed, power & gas boosts
👥 Friends in-server bonus coins + group supporter perks
💰 4 currencies: Coins, Gems, Crystals & Skulls
📊 Global leaderboards — distance & rebirths
📱 Mobile-optimized touch controls

💎 13 Game Passes — 2x Coins, Infinite Gas, Lucky Eggs, Ultra Lucky & more!

🎁 FREE CODES:
LAUNCH → 5K Coins + 100 Gems
STYLXUS90K → 10K Coins + 50 Crystals

👑 Roblox Premium = +50% coins + daily gift box!

🔔 LIKE & FAVORITE for weekly update alerts!
💜 New cars, pets, worlds & events every update!

Built by Polymita Media × Stylxus
```

- **Character count (with spaces):** 997 — within Roblox’s typical **1000** cap.
- **Publisher check:** Confirm **codes** and **group perk rates** match the live build before publish (`PreLaunchChecklist.md`, POLA-95 for monetization SKU wiring).

---

## 3. First paragraph / above-the-fold hook (first two lines)

These are the first two lines of §2 — optimized for discover preview:

1. `🚗 DRIVE fast cars on ENDLESS highways! HATCH rare pets! REBIRTH for POWER!`
2. *(blank line in paste — Roblox may collapse; if only one line shows, use the short hook below as the subtitle/thumbnail caption.)*

Natural discovery phrases in line 1: **drive**, **pets**, **rebirth**, **power**.

---

## 4. Short hook (strict character caps, social, thumbnails)

**Tight (~197 chars)** — from `docs/StorePageCopy_Phase4.md` Variant A:

```
Drive endless highways: hatch pets, rebirth for power, explore four worlds. Phase 4 polishes onboarding, achievements + trophy case, milestone pops, cleaner HUD—friends in-server grant bonus coins.
```

**Standard (~302 chars)** — Variant B when the field allows:

```
The premium highway simulator—hatch pets, rebirth for power, and chase multipliers across four worlds. Phase 4 adds guided first runs, achievements with a trophy case, milestone celebrations, and smarter HUD layering for mobile. Invite friends for server bonus coins and stack daily streaks with codes.
```

---

## 5. Discovery keywords (5–10)

Use in description, tags, and group posts **in sentences** — avoid comma-stuffed stuffing.

1. simulator  
2. driving  
3. pets  
4. hatch  
5. rebirth  
6. achievements  
7. trophy  
8. leaderboard  
9. worlds  
10. codes  

**Optional extras** (when relevant): `tycoon`, `idle`, `cars`, `eggs`, `gems`, `mobile`.

---

## 6. Social one-liner (optional)

Pick one for Shorts / X / Discord status:

- **Systems + Phase 4:** “Trophy case just popped—which achievement are you grinding next?” *(from `docs/GamePageAndDiscoveryCopy.md`)*  
- **Premium sim tone:** “Four worlds, eight pets equipped, one highway—how big is your next payout?”  
- **Co-play:** “Roblox friends in your server? That’s extra coins on every run.”

---

## 7. What a human must paste vs what can feed `MicrocopyConfig` later

| Content | Human in Creator Dashboard | `MicrocopyConfig` / in-game |
|--------|----------------------------|-----------------------------|
| Experience **title** | Yes — only a publisher/Creator role | Not sourced from MicrocopyConfig today |
| Long **description** (§2) | Yes | Short **toast** lines (celebrations, coin gain) stay in MicrocopyConfig; **not** the store paragraph |
| **Tags** / genre | Yes | N/A |
| **Codes list** in description | Yes — must match `CodeService` / live codes | Code redemption **errors/success** strings = MicrocopyConfig |
| **Thumbnail / icon** | Yes (art) | N/A |
| Weekly **Creator update** post body | Yes | Align wording with `docs/Phase4_DiscoveryAndGamePageCopy.md` |
| Short **hook** variants (§4) | Paste where the dashboard asks for a short blurb | Loading tips / `PremiumLoadingTips` etc. are separate pools in MicrocopyConfig |

**Tone:** Premium simulator, high-energy, reward-forward. Spending should read as **clear power and convenience** (passes, Premium), not harassment. Avoid **player-directed “whale” slang** in new strings (see `docs/MicrocopyWhaleTermCleanup_Phase4.md`); in-game pet names like “Cosmic Whale” are **content**, not that terminology.

---

## 8. Files on disk

| Path | Role |
|------|------|
| `docs/RobloxGamePageDraft.md` | This kit (POLA-477) |
