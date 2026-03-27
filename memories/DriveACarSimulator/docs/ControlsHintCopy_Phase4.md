# Controls & first-session hint copy — Phase 4 (POLA-380)

**Date:** 2026-03-22  
**Sources audited:** `DACReplicatedStorage/Config/MicrocopyConfig.luau`, `DACServerScriptService/Services/TutorialService.luau`, `DACStarterGui/TutorialOverlay.luau`, `DACReplicatedStorage/Config/LoadingTipsConfig.luau`, `DACStarterGui/SettingsPanel.luau`, `DACStarterPlayerScripts/Controllers/DrivingController.luau`

---

## 1. Audit summary

| Area | Finding |
|------|---------|
| **Tutorial (steps 1–5)** | All copy lives in `MicrocopyConfig.FirstSessionTutorialStep*`. Server (`TutorialService`) drives titles/bodies; step 1 highlights `StartDriveButton`. Tone matches Phase 4 onboarding (short, action-led). |
| **First-session HUD / toast lane** | `FirstSessionWelcomeToast`, `FirstSession*` nudge pools (hatch, pet equip, world, rebirth soft), tagline `FirstSessionTagline`. Documented as HUD / notification-lane in Microcopy comments. |
| **Soft-fail / retry** | `SoftFail*` pools use **“Tap”** language — intentional for touch; on PC the same string still reads (Roblox treats click as activation). |
| **Loading screen** | `LoadingTipsConfig` has **no** dedicated steering / Drive / gas tip — gap vs. first-session goals (players may load before seeing tutorial). |
| **Settings** | **“Steering sensitivity”** is the only control-adjacent label; no inline explainer of **which inputs** it scales (keyboard + touch today). |
| **Implementation reality** | `DrivingController.handleInput` reads **A / D / Left / Right** only; touch uses horizontal drag. **No `GamepadService` / thumbstick path** in `DrivingController.init` — gamepad players cannot steer with sticks until an engineer adds it. |

---

## 2. Gaps (prioritized)

1. **Gamepad steering — code + copy**  
   - **Code:** No left-stick (or trigger) steering in `DrivingController`.  
   - **Copy:** Any future “use the stick to steer” line must wait on wiring; until then, avoid implying gamepad support in player-facing hints.

2. **Mobile-first “Tap” on universal surfaces**  
   - Tutorial step 1 body and `FirstSessionWelcomeToast` say **“Tap Drive”** — accurate on phone/tablet; on PC/console, **“Click Drive”** / **“Select Drive”** variants would reduce friction (optional A/B).

3. **No loading-tip line for core loop controls**  
   - Add 1–2 tips: e.g. steer with A/D or drag (touch), gas runs out → run ends, tap **Drive** to start. Must not duplicate full tutorial paragraphs (POLA-352 cross-ref).

4. **No first-run persistent HUD chrome for “how to steer”**  
   - Optional: one dismissible chip during **first run only** (engineer-gated). Not in Microcopy yet — would need **new keys** (see §4).

5. **Pause surface**  
   - No custom Roblox **Escape** / pause menu copy in this repo — core menu is platform-owned. Marked **N/A** in the table below.

---

## 3. Canonical copy table

**Columns:** Surface | Input mode | String (authoritative or representative) | Max length note  

*Pools:* Where multiple variants exist, one representative line is shown; implementers should treat **~90 characters** as a soft ceiling for toast/single-line HUD (matches `SoftFail*` / POLA-354 guidance in Microcopy).

| Surface | Input mode | String | Max length note |
|---------|------------|--------|-----------------|
| HUD — session welcome toast | All (mobile-leaning) | `Welcome — your first drive banks real coins. Tap Drive when you're ready!` | ~85 chars; “Tap” may feel odd on KB — see §2. |
| HUD — first-session tagline | All | `Every run pays off.` | Short; single hook per POLA-291. |
| HUD — first payout brag (pool) | All | *Example:* `First payout on the board! The road keeps paying.` | ~55 chars typical. |
| HUD — first hatch (pool) | All | *Example:* `First hatch! Your pet is already boosting your next run.` | ~65 chars. |
| HUD — empty trophy (pool) | All | *Example:* `Case is empty for now — drive, hatch, and climb to fill it with trophies!` | ~75 chars; “drive” verb OK on all inputs. |
| HUD — daily streak framing (pool) | All | *Example:* `Daily streaks stack rewards — come back tomorrow to keep the line hot!` | ~70 chars. |
| HUD — hatch nudge (pool) | All (touch-leaning) | *Example:* `Eggs are your unlock — open Eggs and hatch when you have one ready!` | ~70 chars. |
| HUD — pet equip nudge (pool) | All (touch-leaning) | *Example:* `Open Pets — equip a pet so your Pet Modifier actually applies!` | ~65 chars. |
| HUD — world switch nudge (pool) | All | *Example:* `New world, new coin tier — switch when you're ready for the next grind!` | ~70 chars. |
| HUD — rebirth soft teaser (pool) | All | *Example:* `Rebirth trades a coin reset for permanent speed — it's the long-game unlock.` | ~75 chars. |
| HUD — soft-fail remote timeout (pool) | All | *Example:* `That took a little long — tap {ACTION} again when you're ready!` | ~65 chars + `{ACTION}`; **“tap”** is device-ambiguous. |
| HUD — soft-fail generic retry (pool) | All | *Example:* `Tiny hiccup — nothing lost. Tap again and it should snap back!` | ~60 chars. |
| HUD — remote load error (pool) | All | *Example:* `Connection hiccup! Tap again when you're ready.` | ~45 chars. |
| Tutorial — step 1 | All (highlight: Drive) | Title: `Welcome, driver!` — Body: `Drive → earn coins → upgrade → hatch pets → go faster. Tap Drive to start your first run!` | Body ~95 chars; longest tutorial line — verify bubble wrap in Studio (`TutorialOverlayDesignSpec`). |
| Tutorial — step 2 | All | Title: `Bank your first payout` — Body: `Keep driving until gas runs out — that banks your coins. Faster runs, bigger payouts!` | Body ~90 chars. |
| Tutorial — step 3 | All | Title: `Spend coins, feel faster` — Body: `Open Menu → Store and buy Speed. Each level makes the next run pay more!` | Body ~80 chars. |
| Tutorial — step 4 | All | Title: `Hatch your first pet` — Body: `Open Eggs, grab a Meadow Egg if you need one, then Hatch. Pets boost your earnings — stack bonuses as you grow your team!` | Body ~115 chars — **longest** tutorial body; QA wrap required. |
| Tutorial — step 5 | All | Title: `Equip for bonus coins` — Body: `Open Garage and Equip your pet. More pets equipped = a bigger Pet Modifier every run!` | Body ~95 chars. |
| Tutorial — completion (server) | All | Title: `You're ready to grind!` — Body: `Here's {BONUS_COINS} bonus coins to spend! Next goals: keep upgrading, hatch rarer pets, and Rebirth for permanent speed. Check Store & Game Passes anytime for extra boosts — happy driving!` *( `{BONUS_COINS}` interpolated server-side, value `1000` today.)* | **~240+ chars** — longest tutorial copy; confirm `Bubble.Body` wraps without clip in Studio. |
| Tutorial — overlay fallback (client) | All | Title: `Tutorial Complete!` / Body: `You're ready to hit the road!` | Short; fallback only. |
| Tutorial — Skip button | All | *(Pre-built `DACTutorialOverlay.SkipTutorial` — Studio text, typically `Skip`.)* | 1 word — OK. |
| Settings — scroll (dynamic) | All | `Steering sensitivity` | Label only; no multi-line explainer in data. |
| Settings — other rows | All | `Game sound`, `Music volume`, `SFX volume`, `Graphics (0 low — 2 high)`, etc. | Not driving controls; listed for context only. |
| Loading — tips carousel | All | *(No steering/Drive-specific line in config today.)* | **Gap** — see §2. |
| Pause | — | *No custom DAC pause menu copy.* | N/A |

---

## 4. Engineer: new `MicrocopyConfig` keys (only if product wants them)

Add **after** gamepad steering exists (if applicable) and UX approves placement:

| Proposed key | Purpose |
|--------------|---------|
| `ControlsHintLoadingTipSteerKbTouch` | One loading tip: keyboard A/D + touch drag (no “gamepad” until wired). |
| `ControlsHintLoadingTipDriveGas` | One tip: auto-forward drive, gas meter, end of run → payout. |
| `FirstSessionWelcomeToastKb` | Optional PC variant: `Welcome — your first drive banks real coins. Click Drive when you're ready!` |
| `FirstSessionTutorialStep1BodyKb` | Optional: same step 1 teaching, `Click` instead of `Tap`. |
| `HudFirstRunSteerHint` | Optional one-line, first lap only; **must** differ per platform (KB vs touch vs future gamepad). |

**Wiring notes:**  
- Prefer `UserInputService:GetLastInputType()` or platform flags to pick KB vs touch variants — avoid showing three lines at once.  
- Do **not** duplicate full tutorial text in loading tips (POLA-352 / LoadingTips cross-ref).

---

## 5. Related files

| File | Role |
|------|------|
| `DACReplicatedStorage/Config/MicrocopyConfig.luau` | All first-session + tutorial + soft-fail strings |
| `DACServerScriptService/Services/TutorialService.luau` | Tutorial step payloads + targets (`StartDriveButton`, etc.) |
| `DACStarterGui/TutorialOverlay.luau` | Presentation + completion fallback strings |
| `DACStarterPlayerScripts/Controllers/DrivingController.luau` | Actual input bindings (keyboard + touch) |
| `DACReplicatedStorage/Config/LoadingTipsConfig.luau` | Loading carousel (add tips here if approved) |
| `docs/FirstSessionOnboardingCopyPack.md` | First-session surface map |
| `docs/TutorialCopyReview.md` | Tutorial string QA |
| `docs/ControlHintMicrocopyPack_POLA633.md` | POLA-633: stable keys for Settings/help (steer, menu, rebirth); centralization note for POLA-616 |
