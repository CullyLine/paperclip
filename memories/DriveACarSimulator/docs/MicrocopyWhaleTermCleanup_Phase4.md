# Microcopy whale-term cleanup — Phase 4 (POLA-276 / POLA-277)

**Purpose:** Keep **reward-forward, bubbly** Phase 4 tone while avoiding **player-directed “whale” slang** in celebration and large-payout microcopy. Product/analytics may still use “whale” internally; **pet name “Cosmic Whale”** and similar **proper nouns** stay in species/loading-tip context.

## Policy

| OK | Avoid in player-facing celebration / flex lines |
|----|--------------------------------------------------|
| “Cosmic Whale” as a **pet species** in tips or catalog | Calling the **player** a whale or implying **monetization shaming** |
| Internal tier key `mega` (2000R$+ thank-you) and badge key `mega_500` | New microcopy that frames identity around **spend tier** insults |

## Surfaces (code)

| Surface | Module | Pool(s) |
|---------|--------|---------|
| Run-end subtitle flex, **>10k coins** | `DACStarterGui/PayoutPanel.luau` | `PayoutFlexBig` + optional `PayoutFlexBigOptional` |
| HUD coin pickup flavor, **≥8k coin tick** | `DACStarterGui/HUD.luau` | `CoinGainLarge` + optional `CoinGainLargeOptional` |

Optional append tables may stay **empty**; when non-empty they **extend** the random pick without duplicating base lines.

## Grep checklist (maintenance)

Run from repo root (or IDE search):

```
# Player-facing Luau — review hits in context; pet names / sound IDs are usually fine
rg -n "whale|Whale" --glob "*.luau" memories/DriveACarSimulator
```

**Expect:** hits in `PetConfig`, `EggConfig`, `LoadingTipsConfig` (species), `PurchaseThankYouController` / `FirstTimeConfig` / `FomoBadgeLabelConfig` (product taxonomy), `SoundController` (asset id). **Do not** add new **celebration** lines that label the player “whale.”

## Product decision (POLA-356, Mar 2026)

**Direction:** Rename player-facing monetization tier copy from **Whale** to **Mega** (reward-forward, matches “mega vault” SKU language). Internal thank-you tier string is `mega` (2000R$+ cumulative); sound key `purchase_thankyou_reveal_mega`; FOMO milestone badge key `mega_500` with label **MEGA**. Pet proper noun **Cosmic Whale** and species tips are unchanged.

## Cross-refs

- `docs/CopyPolishAudit.md` — microcopy tone baseline  
- `docs/store/PremiumUpsellToneMatrix.md` — **marketing** tonal lanes (Aggressive / Balanced / Whales column is for **SKU messaging**, not HUD insults)
