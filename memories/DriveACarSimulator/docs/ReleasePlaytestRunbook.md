# Studio release smoke — after Rojo sync, before publish

**Purpose:** Human verifier steps in **Roblox Studio** immediately after a successful Rojo sync and before uploading / switching the place to Public. Deep QA lives in [`PreLaunchChecklist.md`](../PreLaunchChecklist.md); this runbook is the **fast gate** for **audio**, **economy-facing UI**, and **UI smoke**.

**When to run:** Every build you intend to ship. Pair with [Part 2 — Morning (Before Publish)](../PreLaunchChecklist.md#morning-before-publish) on launch day.

---

## Checklist (12 steps)

1. **Sync clean** — Confirm Rojo connected with no missing modules in the Output window (full detail: [§1 Code Readiness — Rojo](../PreLaunchChecklist.md#1-code-readiness)).
2. **Play solo (F5)** — Start from a clean Studio session; no script errors in Output during load (same section as above for DataStore / `pcall` expectations).
3. **Audio — engine & UI** — Drive briefly; open/close 2–3 menus. Hear engine loop + UI click/hover (see [Sound effects in place](../PreLaunchChecklist.md#2-content-readiness)).
4. **Audio — rewards & world** — Collect coins/gems once; trigger egg hatch or rebirth confirm sound at least once; spend 10s in two different worlds and note ambient loops ([§2 Content — SFX list](../PreLaunchChecklist.md#2-content-readiness)).
5. **Economy — earn loop** — Complete one short drive → earn → see currency update on HUD (sanity for progression; [§5 Final QA — playthrough](../PreLaunchChecklist.md#5-final-qa)).
6. **Economy — codes** — Open Codes panel, redeem **one** known test code; confirm success feedback and balance change ([promo codes table](../PreLaunchChecklist.md#1-code-readiness)).
7. **Economy — store & passes (POLA-95 aware)** — Open Store; confirm prices/copy match intent. If `gamePassId` / `productId` are still `0`, treat as **UI-only** verification, not live purchase ([§4 Monetization](../PreLaunchChecklist.md#4-monetization-readiness) and [Document status — POLA-95](../PreLaunchChecklist.md#document-status-read-first)).
8. **UI smoke — core HUD** — `DACMain` + DrivingHUD + speed/run UI readable; no overlapping toasts vs [Phase 4 layering](../PreLaunchChecklist.md#phase-4-polish-pola-104--verify-before-launch).
9. **UI smoke — panels** — Open and close: Inventory, Store, World, Rebirth, Settings, MenuHub routing — no blank/broken shells ([All UI panels functional](../PreLaunchChecklist.md#2-content-readiness)).
10. **UI smoke — retention surfaces** — Spot-check Daily Reward + Quest entry; loading tips if you hit a load screen ([§2 Content — loading tips](../PreLaunchChecklist.md#2-content-readiness)).
11. **Juice pass** — One run-end or milestone moment: fanfare/toast/particle reads as intended (spot-check vs [Juice bullet](../PreLaunchChecklist.md#phase-4-polish-pola-104--verify-before-launch)).
12. **Stop or ship** — If any step fails, fix or file before publish; for go-live morning steps, continue with [Part 2 — Morning (Before Publish)](../PreLaunchChecklist.md#morning-before-publish).

---

**Reference:** [`PreLaunchChecklist.md`](../PreLaunchChecklist.md) Part 1 (§1–§5) and Part 2 morning block.
