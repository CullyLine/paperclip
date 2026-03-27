# VIP & spend-tier copy glossary — Phase 4

**Issue:** POLA-393  
**Parent:** [POLA-104](/pola/issues/6802628e-70f5-4106-a13e-2342ef950399) (Phase 4)  
**Purpose:** Single source of truth for **player-facing** names for spend milestones, premium identity, and storefront tone — plus words to avoid. Aligns with `docs/MicrocopyWhaleTermCleanup_Phase4.md`, `docs/store/PremiumUpsellToneMatrix.md`, and `docs/FirstSessionOnboardingCopyQA.md`.

**Engineer handoff:** Config string passes for **Game Pass** and **Dev Products** are tracked under **[POLA-391](/pola/issues/d9510ffa-b710-4db8-9cec-e4c5fcc1ddc7)** — apply this glossary when editing `DACReplicatedStorage/Config/GamePassConfig.luau` and `DACReplicatedStorage/Config/DevProductConfig.luau`.

---

## 1. Approved tier & badge labels (player-facing)

Use these **exact spellings** when naming cumulative-spend celebration tiers, thank-you flows, and milestone badges. Source of truth in code: `FirstTimeConfig.luau` (`SpendMilestones.tierName`), `FomoBadgeLabelConfig.luau` (`PermanentBadges`).

| Concept | Approved label | Notes |
|--------|----------------|--------|
| First purchase band | **First Timer** | Milestone splash only — not a personality label. |
| Early support band | **Investor** | Neutral, reward-forward. |
| Mid band | **VIP** | Matches **VIP** Game Pass product name (`GamePassConfig.Passes.vip.name`). |
| High band (2000 R$+ thank-you tier key `mega`) | **Mega** | Replaces legacy “Whale” for **player-facing** copy per POLA-356. |
| Ultra-high progression | **Legend**, **Tycoon** | Sequential tiers — status without slang. |
| Top spend tier name | **Mythic Spender** | Proper tier name in ceremony copy; do not shorten to insults. |
| FOMO spend badge @ 500 R$ | **MEGA** | Badge label `mega_500` — short all-caps in UI. |
| FOMO spend badge @ 2500 R$ | **TYCOON** | Badge label `tycoon_2500`. |

**SKUs vs tiers:** Game Pass names (**2x Coins**, **VIP**, **Infinite Gas**, **Crystal** packs, etc.) are **products**, not spend-tier names. Do not call a player a product name; use the tier table above for spend-milestone messaging.

---

## 2. Discouraged terms (casual “whale” & similar)

| Avoid in new player-facing copy | Why | Use instead |
|--------------------------------|-----|--------------|
| **Whale** / **whales** (player-directed) | Sounds like spend shaming; conflicts with POLA-356 rename. | **Mega** tier, **big-stack** / **top-tier** / **completionist** (context-dependent). |
| **Whale-friendly**, **whale flex pass** (store punchlines) | Informal; optional cleanup per FirstSession QA. | **High-stack**, **max flex**, **nonstop runs** — see rewrites below. |
| **Wallet** insults, **pay-to-lose** framing | Toxic; breaks bubbly sim tone. | Mechanical benefits (coins, speed, cosmetics). |
| New copy that **labels the player** by spend as an insult | Policy in `MicrocopyWhaleTermCleanup_Phase4.md`. | Celebration lines stay **reward-forward**; tier names from §1 only. |

**Still OK:** Proper nouns such as **Cosmic Whale** (pet species), loading-tip taxonomy, and internal analytics vocabulary — not directed at the player in HUD/celebration lines.

**Marketing matrix:** The column labeled **Whales** in `PremiumUpsellToneMatrix.md` is for **SKU / store experiments**, not HUD insults. Do not import that column’s voice into tutorial, payout toast, or streak celebration strings.

---

## 3. Example rewrites (storefront → glossary-safe)

These map optional fixes called out in `FirstSessionOnboardingCopyQA.md` §4 to approved vocabulary.

| Location | Before | After (example) |
|----------|--------|-------------------|
| `GamePassConfig.Passes.infinite_gas.description` | “… **The whale flex pass.**” | “… **The infinite flex pass.**” or “**Nonstop runs — maximum flex.**” |
| `DevProductConfig.Products.gems_pack_m.description` | “**Whale-friendly** gem stack …” | “**High-stack** gem line …” or “**Big-stack** gems …” |
| Generic SKU blurb (gems/crystals top tier) | “For **whales** only.” | “For **collectors and completionists**” / “**Top tier** — big runway.” |

---

## 4. Cross-references

| Doc / asset | Role |
|-------------|------|
| [POLA-391](/pola/issues/d9510ffa-b710-4db8-9cec-e4c5fcc1ddc7) | Engineer task: align `GamePassConfig` + `DevProductConfig` strings with this glossary. |
| `docs/MicrocopyWhaleTermCleanup_Phase4.md` | Celebration vs storefront policy; grep checklist. |
| `docs/store/PremiumUpsellToneMatrix.md` | Aggressive / Balanced / premium tonal lanes for store creatives. |
| `docs/FirstSessionOnboardingCopyQA.md` | First-session QA; optional whale softening in two config lines. |

**Constraints:** No new product promises beyond existing mechanical descriptions. Keep future edits **short**; this file should stay **≤ ~2 pages** when printed.
