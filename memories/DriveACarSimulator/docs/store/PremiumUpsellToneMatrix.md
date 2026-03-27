# Premium upsell tone matrix (store-facing)

**Issue:** POLA-273  
**Parent:** POLA-104 (Phase 4 — dopamine & juice polish)  
**Status:** Pre–POLA-95 — **no live Roblox product IDs in this doc.** When POLA-95 unblocks, paste Creator Dashboard IDs into `DevProductConfig` / `GamePassConfig` and mirror any final titles here.

**Purpose:** Give engineering and marketing **three tonal lanes** for premium pitches: **Aggressive** (urgency / FOMO), **Balanced** (clear value, low cringe), **Whales** (status, completion, “best account on the server”). Aligns with the Drive a Car Simulator positioning: **pay-to-win monetization with sim-depth** (pets, eggs, rebirth, worlds, leaderboards) and Phase 4 **reward-forward, bubbly** voice — see `GameCopy.md`, `docs/GamePageAndDiscoveryCopy.md`, and in-game pass/product names in `DACReplicatedStorage/Config/GamePassConfig.luau` & `DevProductConfig.luau`.

**Rows (SKUs referenced, not IDs):**

| Row | SKU anchor (config id) | In-game name (current strings) |
|-----|-------------------------|----------------------------------|
| Game Pass | Multi-pass catalog; hero value props | e.g. **2x Coins**, **VIP**, **Infinite Gas** (`GamePassConfig.Passes`) |
| Top dev product | Highest single dev-product tier used as “whale” SKU | **Crystal Pack L** — 5,000 crystals (`crystals_pack_l`) |
| Starter bundle | First-purchase bundle | **Starter Pack** — one-time coins + gems + eggs (`starter_pack`) |

---

## Matrix: headline + subline

### Game Pass (multi-pass / “get the stack”)

| Tone | Headline | Subline |
|------|----------|---------|
| **Aggressive** | **STOP LEAVING COINS ON THE ROAD.** | Stack passes and lap the leaderboard — 2× coins, auto-collect, luck multipliers. **Own the highway.** |
| **Balanced** | **Passes pay for themselves.** | Boost coins, speed, eggs, and gas — pick what matches how you play. **Permanent perks, no rent.** |
| **Whales** | **Account diff — passes included.** | VIP tag, exclusive skin, infinite gas, ultra luck: **the flex is the loadout.** |

---

### Top dev product — Crystal Pack L (5,000 crystals)

| Tone | Headline | Subline |
|------|----------|---------|
| **Aggressive** | **NEON CITY ISN’T WAITING.** | 5,000 crystals — **skip the grind** and unlock endgame cars and worlds on your terms. |
| **Balanced** | **Premium currency, premium destinations.** | Big crystal stack for **Neon City** cars and skips — **one purchase, long runway.** |
| **Whales** | **Max crystals. Max options.** | Top-up for **collectors and completionists** who don’t negotiate with gates. |

---

### Starter bundle — Starter Pack (one-time)

| Tone | Headline | Subline |
|------|----------|---------|
| **Aggressive** | **FIRST SESSION SHOULD HIT DIFFERENT.** | 25K coins, 500 gems, 3 Meadow Eggs — **one purchase, instant momentum.** |
| **Balanced** | **Kickstart without guesswork.** | Bundled coins, gems, and eggs so **your first upgrades and hatches feel fair.** |
| **Whales** | **Alt account speedrun starter.** | Same bundle — framed for **smurfs and collectors** who want a clean **fast climb**. |

---

## Usage notes

- **Roblox store fields:** Map headline → short title / summary line; subline → description body or bullet — keep under Creator character limits; trim aggressively for mobile.
- **Compliance:** Avoid guaranteed outcomes (“you will get mythic”) — egg odds are variable; passes describe **mechanical** benefits (aligned with existing `description` fields in config).
- **POLA-95 handoff:** Replace SKU labels in UI with **numeric IDs** from dashboard; keep tone columns as A/B labels for experiments (Aggressive vs Balanced vs Whale-targeted creatives).

#### Files on disk

| File | Role |
|------|------|
| `docs/store/PremiumUpsellToneMatrix.md` | This matrix (POLA-273). |
| `DACReplicatedStorage/Config/GamePassConfig.luau` | Pass names + mechanical descriptions. |
| `DACReplicatedStorage/Config/DevProductConfig.luau` | Dev product names + rewards. |
| `GameCopy.md` | Canonical voice for long-form copy. |
