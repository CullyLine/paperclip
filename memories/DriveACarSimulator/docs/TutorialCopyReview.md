# Tutorial overlay copy review — POLA-258

**Date:** 2026-03-22  
**Sources:** `DACServerScriptService/Services/TutorialService.luau` (authoritative strings), `DACStarterGui/TutorialOverlay.luau` (client fallbacks when `title`/`body` missing on completion).

## Phase 4 tone (POLA-104) checklist

| Criterion | Notes |
|-----------|--------|
| Reward-forward | Steps 2–5 emphasize coins, speed, pets, modifier — good. Step 1 is instructional; acceptable. |
| Dopamine / juice | Completion confetti + `tutorial_complete` SFX align; copy could lean slightly more “celebrate” than “homework.” |
| Skippable-friendly, no guilt | Skip path clears without shame copy (empty payload). In-step lines avoid “don’t miss out”; **watch:** “collect them all!” and “You’re ready to grind!” (see below). |
| Roblox-appropriate | Short sentences, arrows in step 1, `=` stacks line — fits simulator voice. |

## String inventory (server)

| Step | `title` | `body` | Highlight target |
|------|---------|--------|------------------|
| 1 | Welcome, driver! | Core loop: Drive → earn coins → upgrade → hatch pets → go faster. Tap Drive to start your first run! | `StartDriveButton` |
| 2 | Bank your first payout | Stay on the road until your gas hits empty — that's when your coins get deposited. Bigger speed = bigger stacks! | *(none)* |
| 3 | Spend coins, feel faster | Open the menu, head to Store, and buy a Speed upgrade. Every upgrade makes the next run more profitable! | `TutorialUpgradeSpeed` |
| 4 | Hatch your first pet | Open Eggs, grab a Meadow Egg if you need one, then tap Hatch. Pets boost your earnings — collect them all! | `TutorialEggHatchBasic` |
| 5 | Equip for bonus coins | Open Garage and tap Equip on your new pet. More pets equipped = a bigger Pet Modifier on every run! | `TutorialPetEquipFirst` |
| Done | You're ready to grind! | Here's {1000} bonus coins to spend! Next goals: keep upgrading, hatch rarer pets, and Rebirth for permanent speed. Check Store & Game Passes anytime for extra boosts — happy driving! | *(none)* |

`TutorialOverlay.luau` **defaults** if server ever sends `done` without strings: title **Tutorial Complete!**, body **You're ready to hit the road!** — tone is fine; keep server as source of truth for the real completion line.

## Mobile / line length (approximate)

Assumptions: bubble body uses ~`TextSize` 15–18 on a narrow phone; usable width often **~260–320 px** → roughly **28–40 characters per line** before aggressive wrap (font and padding dependent).

| Step | Title len | Body len | Wrap risk |
|------|-----------|----------|-----------|
| 1 | 16 | ~98 | Body **high** — 3+ lines typical. |
| 2 | 22 | ~115 | Body **very high** — consider splitting into two sentences on separate mental beats. |
| 3 | 22 | ~108 | Body **high**. |
| 4 | 21 | ~98 | Body **high**. |
| 5 | 21 | ~95 | Body **high**. |
| Done | 21 | ~175+ (with number) | **Very high** — expect 5–7 lines; scannable bullets or shorter clauses would help. |

**Recommendation:** Treat **~38 characters** as a soft per-line budget for body copy if you later split strings or add `\n` for critical breakpoints (test in Studio on smallest device frame).

## Suggested rewrites (optional — not applied in code here)

Goals: shorter clauses, reward-first, reduce “grind” / collection FOMO, keep mechanics accurate.

| Step | Current issue | Suggested direction |
|------|---------------|---------------------|
| 1 | Dense first sentence | **Title:** *Welcome!* or *Welcome, driver!* (keep). **Body:** *Drive → earn coins → upgrade → pets → more speed. Tap **Drive** for your first run!* (drops one “hatch” mention in the loop list to shorten; optional.) |
| 2 | Long; em dash chain | **Body:** *Keep driving until gas runs out — that banks your coins. Faster runs, bigger payouts!* |
| 3 | “Every upgrade…” is long | **Body:** *Open **Menu → Store** and buy **Speed**. Each level makes the next run pay more!* |
| 4 | “collect them all!” | **Body:** *Open **Eggs**, grab a **Meadow Egg** if you need one, then **Hatch**. Pets boost your earnings — stack bonuses as you grow your team!* (avoids “gotta catch ‘em all” pressure.) |
| 5 | OK; could trim | **Body:** *Open **Garage** and **Equip** your pet. More pets equipped = bigger **Pet Modifier** every run!* |
| Done | “grind” + long monetization tail | **Title:** *You’re ready — let’s roll!* or *Nice — you’re ready!* **Body:** *Here’s **{N}** bonus coins! Keep upgrading, hatch rarer pets, and try **Rebirth** for permanent speed. **Store** and **Game Passes** are there if you want extra boosts. Have fun out there!* (Shorter clauses; “if you want” softens monetization.) |

## Client-only strings (`TutorialOverlay.luau`)

| Context | String | Note |
|---------|--------|------|
| Skip | *(button text lives in StarterGui `DACTutorialOverlay`, not in script)* | Verify button says **Skip** or **Skip tutorial** — neutral, no “Are you sure?” |
| Completion fallback | Tutorial Complete! / You're ready to hit the road! | Safe; only used if payload omits `title`/`body`. |

## Verdict

- **Flow and mechanics** match the documented tutorial intent (`docs/tutorial-flow-improvements.md`).
- **Phase 4 polish:** Biggest wins are **shortening step 2 body**, **softening step 4 (“collect them all”)**, **retiring “grind” in completion title**, and **tightening completion body** for small screens.
- **Skip:** Server skip is guilt-free; no copy change required for skip behavior.

## Files on disk

- `docs/TutorialCopyReview.md` (this file)
