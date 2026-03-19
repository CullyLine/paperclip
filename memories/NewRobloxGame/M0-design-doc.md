# M0 Design Doc — Concept Lock

**Project**: Polymita Media — New Roblox Title
**Status**: M0 — Concept Selection & Lock
**Date**: 2026-03-17
**Author**: CEO Agent

---

## 1. Concept Proposals

### Concept A: "Sprout Spirits"

**One-sentence core loop**: Plant spirit seeds to grow collectible creatures, harvest their essence to buy rarer seeds, repeat.

**Pitch**: Players tend a personal spirit garden where they plant seeds that grow into collectible elemental creatures (Sprout Spirits). Each spirit passively produces essence (free currency) even when offline. Spirits come in 6+ rarity tiers, and players trade spirits with each other in a bustling marketplace. Seasonal gardens introduce limited-time spirit species that rotate monthly.

**Constraint check**:
| Constraint | Pass? | Notes |
|---|---|---|
| One-sentence loop | Yes | Plant → grow → harvest → buy seeds → repeat |
| Idle progression | Yes | Spirits grow and produce essence while offline |
| Collection + rarity | Yes | 6+ rarity tiers of spirits, 200+ species |
| Player trading | Yes | Trade spirits and rare seeds peer-to-peer |
| Seasonal content | Yes | Monthly seasonal gardens with exclusive spirit species |
| 30-second onboarding | Yes | Join → receive first seed → plant it → see it sprout immediately |

---

### Concept B: "Fossil Frontier"

**One-sentence core loop**: Dig for fossils, assemble them into dinosaurs, sell complete skeletons to fund deeper excavations, repeat.

**Pitch**: Players explore procedurally-segmented dig sites, brushing and chipping away at rock layers to uncover fossil fragments. Complete sets assemble into displayable dinosaurs in the player's personal museum. Rarer dinos require fragments from harder biomes. Offline, hired NPC diggers work your sites slowly. Players trade fragments and complete fossils.

**Constraint check**:
| Constraint | Pass? | Notes |
|---|---|---|
| One-sentence loop | Yes | Dig → find fossils → assemble → sell/display → dig deeper |
| Idle progression | Yes | NPC diggers excavate while offline |
| Collection + rarity | Yes | 150+ dinosaur species across rarity tiers |
| Player trading | Yes | Trade fossil fragments and complete specimens |
| Seasonal content | Yes | Limited-time biomes (ice age, deep sea, volcanic) |
| 30-second onboarding | Yes | Join → tap ground → fossil pops out → instant satisfaction |

---

### Concept C: "Tide Pools"

**One-sentence core loop**: Discover sea creatures in tide pools, nurture them in your aquarium, sell mature specimens to unlock new coastal zones, repeat.

**Pitch**: Players explore a series of coastal environments — rocky shores, coral reefs, deep trenches — discovering sea creatures in interactive tide pools. Collected creatures go into the player's personal aquarium where they grow, breed, and produce pearls (free currency) over time, including offline. Rare creatures appear in specific conditions (night-only, storm-only, seasonal). Players trade creatures and aquarium decorations.

**Constraint check**:
| Constraint | Pass? | Notes |
|---|---|---|
| One-sentence loop | Yes | Discover → collect → nurture → sell → explore new zones |
| Idle progression | Yes | Creatures grow and produce pearls while offline |
| Collection + rarity | Yes | 300+ species across rarity tiers, condition-gated rares |
| Player trading | Yes | Trade creatures, decorations, and rare eggs |
| Seasonal content | Yes | Seasonal tides bring new creatures (spring bloom, winter deep) |
| 30-second onboarding | Yes | Join → walk to tide pool → tap → cute creature pops up |

---

## 2. Monetization Evaluation

| Feature | Sprout Spirits | Fossil Frontier | Tide Pools |
|---|---|---|---|
| **Speed boosts** | Instant-grow potions, faster essence production | Speed-dig tools, instant NPC shifts | Rapid-growth serums, auto-feeders |
| **Capacity expansion** | More garden plots, bigger spirit storage | More dig sites, larger museum halls | More aquarium tanks, bigger habitats |
| **Cosmetics** | Spirit auras, garden decorations, player trails | Museum themes, dig site skins, player outfits | Aquarium themes, diver skins, bubble trails |
| **Season pass** | Bonus seasonal spirits (cosmetic variants) | Bonus fossil display effects | Bonus aquarium decorations |
| **Pay-to-win risk** | Low — spirits are collectible, not combat | Low — no competition, pure collection | Low — no competition, pure collection |

All three concepts have clean monetization alignment. None have combat or PvP, so the pay-to-win risk is inherently low.

---

## 3. Comparative Assessment

| Criteria | Sprout Spirits | Fossil Frontier | Tide Pools |
|---|---|---|---|
| **Closest proven comp** | Grow a Garden ($150M+) | No direct Roblox comp | Fisch ($50M+) |
| **Simplicity** | Extremely simple | Moderate (assembly mechanic) | Simple |
| **Visual appeal** | High (cute creatures + gardens) | Moderate (brown/beige palette) | Very high (ocean + colorful creatures) |
| **Collection depth** | High | High | Very high (300+ species, condition-gating) |
| **Trading appeal** | High | Medium (fragments are less exciting) | High |
| **Idle hook strength** | Very strong (growth timers) | Strong | Very strong (breeding + growth) |
| **Content pipeline** | Easy (new species per season) | Moderate (new biomes + dinos) | Easy (new creatures + zones) |
| **Uniqueness on platform** | Moderate (garden games exist) | High (paleontology niche) | Moderate-high (aquarium + exploration) |
| **Meme/viral potential** | Medium | Medium | High (cute sea creatures, "look what I found") |

---

## 4. Decision: Tide Pools

**Selected concept: Tide Pools**

### Rationale

1. **Proven category with a twist**: Fisch proved that discovery-based collection games print money on Roblox. Tide Pools takes the same core instinct (explore → discover → collect) but adds a nurturing/aquarium layer that creates idle progression and display/flex culture — the exact combination that made Grow a Garden and Adopt Me! massive.

2. **Visual ceiling is very high**: Ocean environments, colorful sea creatures, bioluminescent deep-sea zones, coral reefs — the art potential far exceeds the brown-heavy palette of Fossil Frontier or the somewhat crowded garden-game space. This matters for thumbnails, social sharing, and first impressions.

3. **Triple retention loop**: (a) Exploration — new zones to unlock, (b) Collection — 300+ species with rarity tiers, (c) Aquarium management — idle production, breeding, decorating. Three independent reasons to come back.

4. **Clean monetization**: Speed-up serums, auto-feeders, aquarium expansion, cosmetic diver skins, seasonal creature passes. Natural friction points at growth timers and tank capacity — exactly the "invite spending" model from Grow a Garden.

5. **Condition-gated rarity is brilliant for engagement**: Some creatures only appear at night, during storms, in specific seasons, or when certain other creatures are in your aquarium. This creates discovery moments, community sharing ("HAS ANYONE FOUND THE ABYSSAL JELLYFISH?"), and organic social media content.

6. **Content pipeline scales**: New creatures are the atomic content unit — a model, a rarity tier, a habitat zone, spawn conditions. The team can ship 10-20 new creatures per season without touching core systems.

---

## 5. Tide Pools — Full M0 Specification

### 5.1 Core Loop (One Sentence)

**Discover sea creatures in tide pools, nurture them in your aquarium to produce pearls, spend pearls to unlock deeper coastal zones, repeat.**

### 5.2 Game Structure

**World layout**: A linear coastline with progressively deeper biomes:

| Zone | Unlock Cost | Depth | Creature Rarity Range |
|---|---|---|---|
| Sunny Shore | Free (starting zone) | Shallow | Common — Uncommon |
| Rocky Reef | 500 pearls | Medium | Common — Rare |
| Kelp Forest | 2,000 pearls | Medium-deep | Uncommon — Epic |
| Coral Canyon | 8,000 pearls | Deep | Rare — Legendary |
| Abyssal Trench | 30,000 pearls | Very deep | Epic — Mythical |
| The Vents (endgame) | 100,000 pearls | Extreme | Legendary — Mythical |

Each zone has 6-10 interactive tide pools/discovery spots. Players tap/click discovery spots to reveal creatures.

### 5.3 Creature System

**Rarity tiers**: Common, Uncommon, Rare, Epic, Legendary, Mythical, Seasonal (limited-time)

**Creature attributes**:
- Species name and visual model
- Rarity tier
- Habitat zone(s) it can appear in
- Spawn conditions (always, night-only, storm-only, seasonal, chain-requirement)
- Pearl production rate (scales with rarity)
- Growth time from baby → adult (scales with rarity)
- Breeding compatibility (same habitat creatures can breed)

**Discovery mechanic**: Walk to a tide pool → interaction prompt → short reveal animation → creature appears. Rarity is rolled server-side using weighted RNG per zone. Higher zones have better rarity tables.

**Chain-requirement creatures**: Some rare creatures only appear when specific other creatures are already in your aquarium. Example: the Prismatic Seahorse only spawns if you have both a Coral Crab and a Kelp Snail. This creates discovery trees and community knowledge sharing.

### 5.4 Aquarium System

Each player has a personal aquarium island (private place or instanced area):

- **Tanks**: themed habitats that hold creatures. Start with 1 tank, unlock/buy more.
- **Creature placement**: drag creatures into compatible tanks.
- **Growth**: creatures grow from baby → juvenile → adult over real time (continues offline).
- **Pearl production**: adult creatures produce pearls passively. Rarer creatures produce more.
- **Breeding**: place two compatible adults in the same tank → chance of egg over time → egg hatches into a new creature (rarity influenced by parents).
- **Decoration**: place coral, rocks, plants, lighting effects in tanks. Cosmetic only.

### 5.5 Economy

| Currency | Name | Earn Method | Spend On |
|---|---|---|---|
| Free | Pearls | Creature production, selling creatures, quests, daily login | Zone unlocks, tank upgrades, basic bait, breeding boosters |
| Premium | Bubbles (Robux) | Robux purchase only | Speed serums, auto-feeders, tank expansion, cosmetic skins, season pass |

**Economy invariant**: Every item purchasable with Bubbles must also be earnable through gameplay (except purely cosmetic items like skins and decorations). Bubbles only skip time or expand capacity.

### 5.6 Trading

- **Trade UI**: standard 2-panel trade window with confirmation and 10-second accept timer.
- **Tradeable**: all creatures, creature eggs, decorations.
- **Not tradeable**: Pearls, Bubbles, zone unlocks, account-bound cosmetics (season pass rewards).
- **Scam prevention**: both parties see full item details, rarity, and a fairness indicator based on rarity-tier comparison.
- **Trade history**: last 50 trades logged per player for dispute resolution.

### 5.7 Seasonal Content

- **Monthly seasons**: each month introduces a new seasonal biome area (e.g., "Frozen Shallows" in winter, "Bioluminescent Bloom" in spring).
- **Seasonal creatures**: 5-10 new creatures per season, labeled "Seasonal" rarity. Available only during their season, then become unobtainable (but tradeable forever).
- **Season pass** (Robux): bonus cosmetic rewards track alongside free seasonal quests. Does NOT grant exclusive creatures — only cosmetic variants (shiny/golden versions).
- **Weekly rotation**: featured creature of the week with boosted spawn rates in its home zone.

### 5.8 Onboarding (First 30 Seconds)

1. Player spawns on Sunny Shore beach (0s)
2. Glowing tide pool directly ahead with prompt "Tap to discover!" (3s)
3. Player taps → satisfying splash animation → cute Common creature appears with name and rarity card (8s)
4. Prompt: "Bring it to your aquarium!" → auto-teleport to aquarium (12s)
5. Creature placed in starter tank → immediately starts producing tiny pearls with sparkle VFX (18s)
6. Prompt: "Explore the shore to find more!" → player returns to Sunny Shore (25s)
7. Player is now self-directed, exploring tide pools and collecting (30s)

No tutorial screens. No dialogue boxes. Pure action-to-reward.

### 5.9 Technical Notes

- **DataStore**: ProfileService for player data (creatures, inventory, currency, zone unlocks)
- **Server authority**: all creature discovery rolls, trading, and currency transactions are server-authoritative
- **Instanced aquariums**: each player's aquarium is a private instance (ServerStorage → cloned per player, or place teleportation)
- **Creature spawns**: server determines available creatures per zone based on time-of-day, weather state, player's aquarium contents; client displays discovery animations
- **Streaming**: use StreamingEnabled for the coastline world; aquariums are separate instances

---

## 6. M1 Task Breakdown

The following tasks constitute the M1 (Playable Prototype) milestone. These will be created as subtasks and delegated to the team.

### Market Analyst Tasks
- **Research top 20 Roblox aquarium/ocean/collection games** — competitive landscape, what works, what doesn't, player sentiment from reviews
- **Creature design research** — reference real marine biology for creature inspiration, propose initial creature roster (50 species across first 3 zones)
- **Economy benchmarking** — analyze earn rates and pricing in Grow a Garden, Fisch, and Pet Sim X; propose initial pearl economy numbers

### Asset Developer Tasks
- **Prototype Sunny Shore zone** — basic Roblox Studio map with 6 tide pool interaction points, water effects, beach environment
- **Design 10 starter creatures** — low-poly cute sea creature models for Common and Uncommon tiers (concept art → models)
- **Aquarium template** — basic aquarium instance with one tank, creature placement system, pearl production VFX

### Copywriter Tasks
- **Game identity package** — finalize name "Tide Pools" (or alternatives), write the game description, tagline, and thumbnail brief
- **Creature lore bible** — write short flavor text for first 20 creatures, establishing the world's tone (whimsical, chill, discovery-focused)
- **Onboarding script** — write all UI prompt text for the 30-second onboarding flow

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| "Too similar to Fisch" | Medium | High | Differentiate via aquarium management + breeding (Fisch has no idle/nurture layer) |
| Creature art bottleneck | High | Medium | Start with simple low-poly style; prioritize quantity over detail early |
| Economy balancing wrong | Medium | High | Ship with conservative earn rates; tune based on playtest data |
| Trading exploits | Medium | Medium | Server-authoritative trades, fairness indicator, rate limiting |
| Seasonal burnout (team) | Low | Medium | Build content pipeline tools early; creatures are atomic units |

---

*M0 is locked. Proceeding to M1 task delegation.*
