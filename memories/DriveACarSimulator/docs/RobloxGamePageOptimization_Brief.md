# Roblox discovery & game page optimization — Drive a Car Simulator

**Issue:** POLA-749 · **Parent:** [POLA-104](/pola/issues/6802628e-70f5-4106-a13e-2342ef950399) (Phase 4 / launch readiness)  
**Role:** Content Strategist · **Date:** 2026-03-23  

**Purpose:** Improve **impressions → CTR → play conversion** by aligning the Creator **Experience** package with what players actually get (highway idle sim + pets + rebirth), while borrowing patterns from top listings **without** copying their voice wholesale.

**Canonical paste blocks (do not fork — merge deltas here):**  
`docs/RobloxGamePageDraft.md` · `docs/GamePageAndDiscoveryCopy.md` · `GamePageContent.md` (repo root) · `README.md` (game loop truth).

---

## 1. Competitive scan (3–5 listings — patterns only)

*Public listings change; treat visit counts as directional. Use this for **hook + keyword patterns**, not to clone titles.*

| # | Public listing title (pattern) | First-line / hook pattern | Keyword / structure notes |
|---|--------------------------------|---------------------------|----------------------------|
| 1 | **Drive World** (drift/racing framing) | Lead with **mode** (drifting, racing) + customization promise | Heavy vehicle-tuning lexicon; **emoji in title** (🏎️); “world” as brand |
| 2 | **The Long Drive** | Adventure / survival + **long journey** fantasy | “Long” + mood; less “simulator” in title, more **story** |
| 3 | **Eight Driver Car Racing** | Racing + **multi-mode** (drift, drag, police) | “Driver” + “Racing” double SEO; platform compatibility called out |
| 4 | **(🛣️HIGHWAY) Full Self Driving / Autopilot Simulator** | **Road emoji** + **niche vehicle** (real-brand adjacent) in title | **Parenthetical prefix** for discovery; “simulator” explicit |
| 5 | **Dangerous Driving [NEW]** | **“NEW”** tag + danger / truck / roads | **Bracket tag** for freshness; challenge framing |

**Synthesis for DAC**

- **Differentiation:** DAC is **not** a free-roam drift MMO or licensed FSD sandbox — it is **auto-forward highway laps + gas-limited runs + pet/rebirth progression**. Any page that implies **PvP racing** or **open-city driving** will hurt **qualified CTR** (see `docs/GamePageAndDiscoveryCopy.md` §5).
- **Borrow:** emoji + short **mode** in title (optional A/B); **“simulator”** + **“highway”** / **“endless”**; **feature bullets** in description; **\[NEW\]** / update tags only when **true**.
- **Avoid:** promising **tuning garages** or **player-vs-player race** unless the product ships it.

---

## 2. Updated game page package (paste-ready)

### 2.1 Experience name — title variants

| Priority | Title | Notes |
|----------|-------|--------|
| **Primary** | **Drive a Car Simulator** | Matches `README`, Stylxus cross-SEO, safe on mobile. |
| Alt A | **Drive a Car Simulator** 🚗 | Single emoji; test A/B for CTR on **search** vs **home** placements. |
| Alt B | **Drive a Car Simulator: Pets & Rebirth** | Extra keywords; **watch truncation** on phone. |
| Alt C | **Car Simulator — Drive & Hatch** | “Hatch” SEO; **weaker** brand match vs `Drive a Car Simulator`. |

**Recommendation:** Keep **primary** unless Dashboard experiments show Alt A lifts **qualified** plays (session length), not just clicks.

### 2.2 Subtitle (Creator short field / first line under name — if used)

**Option A:** `Endless highways • hatch pets • rebirth for power`  
**Option B:** `Auto-drive sim — stack pets, rebirth, four worlds`

### 2.3 Short description (**≤ 350 characters** — Roblox short-description style field)

**Character count: 345** (including spaces; verify in Creator before publish).

```
Endless highway simulator—steer left/right, hatch pets, rebirth for permanent Gas/Power/Speed. Four themed worlds up to 10x coins, eggs, achievements + trophy case, leaderboards, daily streaks, codes & Game Passes. Mobile touch HUD. Friends in-server = bonus coins. Reward-forward sim—no PvP racing bait. Premium perks stack. Polymita x Stylxus.
```

### 2.4 Five feature bullets (for Creator bullet list, group posts, or description **FEATURES** block)

1. **Auto-drive highway runs** — steer left/right; gas limits each payout; distance = coins.  
2. **Pets & eggs** — equip multipliers, hatch tiers from Common to Mythic, fuse toward rarer rolls.  
3. **Rebirth** — reset run economy for **permanent** Gas/Power/Speed scaling.  
4. **Four worlds** — escalating coin multipliers (up to **10x** in Neon) + world-specific eggs.  
5. **Meta progression** — achievements + trophy case, leaderboards, daily rewards, friend/group bonuses, codes.

### 2.5 Three thumbnail text-overlay concepts *(copy only — art: Bard / design)*

| # | Concept | Headline (large) | Subline (small) | Visual note (non-binding) |
|---|---------|------------------|-----------------|----------------------------|
| 1 | **Payout** | `YOUR BEST RUN` | `+999M Coins` or `Distance PB` | HUD / brag line from real payout panel |
| 2 | **Pet fantasy** | `HATCH MYTHIC` | `Cosmic Whale · 550+ Power` | Egg + rarity burst; **match real pet names** from `PetConfig` |
| 3 | **Worlds** | `4 WORLDS` | `10x Coins in Neon` | Four-zone strip or map; **no fake car brands** |

---

## 3. Cross-check vs in-game tone (config + docs)

| Source | Alignment | Conflict / action |
|--------|-----------|-------------------|
| `README.md` | Auto-forward, steer-only, gas-limited, lap loop | **None** — page must **not** imply full steering control racing. |
| `MicrocopyConfig.luau` | Punchy, reward-forward, occasional ALL CAPS in toasts | **None** — store page can stay emoji-forward; avoid **snark** that isn’t in microcopy. |
| `LoadingTipsConfig.luau` | Specific facts (e.g. Neon **10x**, Premium **+50%**, friend **+20%**) | **Verify** live `Constants` / services before locking **codes** in long description (`RobloxGamePageDraft.md` already flags this). |
| `docs/Phase4_DiscoveryAndGamePageCopy.md` | No **false urgency**; no competitor names in **public** weekly posts | This brief is **internal**; competitive names are for **analysis** only. |
| `docs/GamePageAndDiscoveryCopy.md` | Phase 4 keywords (achievements, trophy case, etc.) | **Short description** above doesn’t repeat every keyword — **long** description in `RobloxGamePageDraft.md` carries the rest. |

**Flag:** If marketing uses **“11+ cars” / “14+ pets”** style counts, **reconcile** with `CarConfig` / `PetConfig` before publish (see `PreLaunchChecklist.md`).

---

## 4. Handoff

- **Engineering / PM:** Paste **§2.3** into short description; keep **§2.3** and **long** block in `docs/RobloxGamePageDraft.md` in sync when numbers change.  
- **Art (Bard):** Thumbnail **§2.5** — three variants for A/B; use **in-game HUD** and **real** rarities.  
- **Parent issue:** POLA-104 — link this file path in the epic when discovery OKR moves.

---

## 5. Deliverable checklist

- [x] Competitive scan (§1)  
- [x] Title / subtitle / **350-char** short description / bullets / thumbnails (§2)  
- [x] Config & tone cross-check (§3)  
- [x] On-disk path: **`memories/DriveACarSimulator/docs/RobloxGamePageOptimization_Brief.md`**
