# Phase 4 — Milestone ceremony + pet fusion parity

**Purpose:** On-disk deliverable for **POLA-745** (Designer milestone / pet fusion specs parity). This doc names the layers that must stay aligned so **milestone celebrations** and **pet fusion** never drift between config, server, and UI.

**Related P0 doc:** [`docs/phase4-p0-spec-parity.md`](phase4-p0-spec-parity.md) — global config ↔ server ↔ UI checklist.

## Milestone ceremony (types A–E)

| Layer | Location |
|-------|----------|
| Visual / motion spec | `DACStarterGui/MilestoneCeremonyDesignSpec.luau` |
| Copy pools | `DACReplicatedStorage/Config/MilestoneCeremonyCopyConfig.luau`, `FirstTimeConfig.luau`, `SpeedMilestoneConfig.luau`, `RebirthMilestoneConfig.luau` |
| Server orchestration | `DACServerScriptService/Services/MilestoneCeremonyService.luau` |
| Client (speed local, queue, VFX) | `DACStarterPlayerScripts/Controllers/DrivingController.luau`, `VFXController.luau` |

**Parity rule:** Thresholds, tier names, and ceremony copy in config must match what the server emits and what the client renders (including queue / suppression rules in the design spec).

## Pet fusion

| Layer | Location |
|-------|----------|
| Mechanics & gates | `DACServerScriptService/Services/PetService.luau` |
| Copy & labels | `DACReplicatedStorage/Config/MicrocopyConfig.luau`; Inventory / fusion UI shells under StarterGui per `AGENTS.md` |
| Player FAQ | `docs/midgame_systems_faq.md` (fusion overview) |
| CTA alignment | `docs/CTAVerbConsistency.md` |

**Parity rule:** Fuse costs, tier rules, and destructive-action strings must match server validation and `DACReplicatedStorage/Config/PetConfig.luau` tuning.

## Adjacent juice specs

- [`docs/Phase4RunEndComboJuiceSpec.md`](Phase4RunEndComboJuiceSpec.md) — run-end fanfare (often fires near milestone cadence)

---

## Ops checkpoint — POLA-95 (live monetization IDs)

| Date | Note |
|------|------|
| 2026-03-23 | **POLA-745** is **done**. **POLA-95** remains **blocked** until a human completes the **Roblox Creator Dashboard** step: create passes/products for the place and paste numeric `gamePassId` / `productId` values into `DACReplicatedStorage/Config/GamePassConfig.luau` and `DevProductConfig.luau` (see `PreLaunchChecklist.md` Part 1). |
