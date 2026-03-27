# Rarity & premium visual tokens — Drive a Car Simulator

**POLA-629 · Phase 4 · Single source of truth for UI + VFX**

This sheet defines **fill**, **stroke**, **glow band**, and **when to use** each tier so pets, eggs, store, and juice read **more expensive** as rarity rises (pay-to-win positioning). Implementation should converge on **`DACReplicatedStorage/Constants.luau`** → `Constants.RARITY_COLORS` for gameplay rarity fills.

**Related:** Coordinate hatch particle scaling and rainbow mythic treatment with **POLA-624** (VFX overlap).

---

## 1. Gameplay rarity (pets, eggs, hatch reveal, inventory)

Canonical **RGB** is from `Constants.RARITY_COLORS` (below). **HEX** is derived for design handoff.

| Tier key   | Display label | Fill HEX | Stroke HEX | UIStroke thickness | Glow band | Reads as |
|------------|---------------|----------|------------|--------------------|-----------|----------|
| `common`   | Common        | `#B4B4B4` | `#2A2A40`  | 1–1.5              | **G0**    | Baseline / filler |
| `uncommon` | Uncommon      | `#50C850` | `#1E5A1E`  | 1.5                | **G1**    | First “nice” drop |
| `rare`     | Rare          | `#3C82FF` | `#1A2A60`  | 1.5                | **G1**    | Clearly special |
| `epic`     | Epic          | `#B43CFF` | `#3A0F55`  | 2                  | **G2**    | Premium flex |
| `legendary`| Legendary     | `#FFC832` | `#5C3A00`  | 2–2.5              | **G2**    | Jackpot / status |
| `mythic`   | Mythic        | `#FF3250` | `#5A1020`  | 2.5 + **rainbow** outer | **G3** | Top of pyramid; chromatic allowed |

### Glow bands (implementation guide)

| Band | Name        | UI | Particles / VFX (see `VFXController` `BURST_TABLE`) |
|------|-------------|-----|------------------------------------------------------|
| **G0** | Flat        | Fill + dark stroke only; no Outer Glow | Minimal burst (`common`) |
| **G1** | Soft halo   | UIStroke alpha ~0.25–0.35 on fill edge | Light stars / core bump (`uncommon`–`rare`) |
| **G2** | Premium aura| Brighter stroke + optional faint `UIGradient` on title strip | Beams, confetti, shake (`epic`–`legendary`) |
| **G3** | Mythic peak | **Rainbow** `ColorSequence` / mythic-only treatment; never use for sub-mythic | Max burst, mythic rainbow sequences, longest timeline (`mythic`) |

**Pay-to-win read:** Saturation and **glow band** must **monotonically increase** from Common → Mythic. Do not give lower tiers G3 juice.

---

## 2. Premium & monetization (not pet rarity)

Use **separate** tokens so “spend Robux” never looks like a gameplay drop tier.

| Surface | Fill HEX | Stroke / accent HEX | Usage |
|---------|----------|---------------------|--------|
| **Robux / paid strip** | `#1E1E1E`–`#2A2040` dark card | `#FFD54F`–`#FFC83C` gold stroke | Payout upsell strips, “You could have earned”, Game Pass rows |
| **Currency gold (coins)** | `#FFD54F` | — | Coin amounts, positive money |
| **Currency gems** | `#CE93D8` | — | Gem balances |
| **Positive action** | `#2ECC71` | — | Equip, Claim, Rebirth CTAs (per DAC UI guide) |
| **Danger / close** | `#FF2222` | — | Close buttons, hard stops |

Higher **perceived value** for monetization = **gold stroke on dark** + clear number (missed coins), not mythic pink/red (those stay for **items**).

---

## 3. When to use which tier

| Context | Rule |
|---------|------|
| Pet card border / hatch banner | Gameplay tier table only; glow band = row above |
| Store / egg shop price badges | Gameplay tier for **egg quality**; monetization gold for **Robux price** |
| Leaderboard / titles | May use `Constants.TITLES` colors; do not mix mythic rainbow into leaderboard rows unless spec says so |
| Notifications | Rare+ can pick up tier accent for one line; mythic = full G3 allowed for celebration toasts only |
| Pity / streak UI | Copy can reference “Rare+”; visuals stay **G0–G1** until roll resolves |

---

## 4. Code alignment (Engineer)

| Location | Notes |
|----------|--------|
| `DACReplicatedStorage/Constants.luau` | **Canonical** `RARITY_COLORS` + `RARITY_ORDER` |
| `DACStarterPlayerScripts/Controllers/UIController.luau` | Local `RARITY_COLORS` — **slightly different** RGB for `common`, `rare`, `legendary`, `mythic` vs `Constants` — **unify** to `Constants` to avoid drift |
| `DACStarterPlayerScripts/Controllers/VFXController.luau` | `BURST_TABLE` + `REF_HATCH_BREAK_FOR_SCALE` drive intensity; keep visual band consistent with this doc |

---

## 5. Luau reference (canonical RGB)

```lua
-- Constants.RARITY_COLORS (abbrev.)
common    = Color3.fromRGB(180, 180, 180)
uncommon  = Color3.fromRGB(80, 200, 80)
rare      = Color3.fromRGB(60, 130, 255)
epic      = Color3.fromRGB(180, 60, 255)
legendary = Color3.fromRGB(255, 200, 50)
mythic    = Color3.fromRGB(255, 50, 80)
```

---

## 6. Asset paths

| Asset | Path |
|-------|------|
| This token sheet | `memories/DriveACarSimulator/RARITY_PREMIUM_VISUAL_TOKENS.md` |
| Vector swatch strip | `memories/DriveACarSimulator/ConceptArt/rarity-premium-swatches.svg` |
