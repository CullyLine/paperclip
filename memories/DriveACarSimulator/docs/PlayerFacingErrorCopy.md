# Player-facing error & failure copy (Phase 4)

Audit of **network / remote failures**, **purchase flows**, and **inventory (garage) load** surfaces. Tone target: short, confident, whale-friendly — same family as `MicrocopyConfig` celebration pools.

**Toast / HUD line length:** aim **≤ 100 characters** per line (mobile-safe; `UIController` notifications).

---

## Network / remote failure (client)

| Context | Current string(s) | Proposed | Notes |
|--------|-------------------|----------|--------|
| Generic remote invoke failure toast | Random from `MicrocopyConfig.RemoteLoadError` (5 variants), e.g. *"Couldn't sync that — give it another sec!"* | **Keep pool** — already on-brief | Shown by `RemoteFailSafe.notifyRemoteFailure` → `UIController.showNotification`. Source: `DACReplicatedStorage/RemoteFailSafe.luau`, `DACReplicatedStorage/Config/MicrocopyConfig.luau`. |
| Leaderboard fetch failure (inline status) | *"Couldn't load."* | *"Couldn't sync leaderboard — try again in a sec."* | **Hardcoded** in `DACStarterGui/LeaderboardPanel.luau` (~line 141). Prefer moving to `MicrocopyConfig` + one variant for empty-server empathy. ~55 chars. |
| Leaderboard loading state | *"Loading…"* (ellipsis char U+2026) | **Keep** | Fine; universal. |
| Leaderboard empty (not an error) | *"No rankings yet."* / *"No rebirth rankings yet."* | **Keep** | Informational, not failure copy. |

---

## Purchase cancel / Roblox commerce

| Context | Current string(s) | Proposed | Notes |
|--------|-------------------|----------|--------|
| Insufficient coins (store / garage afford) | Random from `MicrocopyConfig.PurchaseFail` | **Keep pool** | Not “error” — motivational denial. `MicrocopyConfig.luau`. |
| User closes Roblox purchase prompt without buying | *(none — engine handles)* | N/A | No custom client string; do not fake a toast on cancel (noise). |
| Game pass / dev product success | Celebration via `VFXFacade` | N/A | Success path, out of scope. |

---

## Inventory / garage load

| Context | Current string(s) | Proposed | Notes |
|--------|-------------------|----------|--------|
| `GetPlayerData` remote fails on open / redraw | Toast: random `RemoteLoadError` variant; **panel shows cleared pet/car list** (no dedicated empty-error label) | Optional: add inline *"Garage didn't sync — reopen Menu."* on empty failure state | **Engineer:** if UX tests show confusion, add a single `TextLabel` in pre-built `Inventory` shell when `lastDataSnapshot == nil` after failed fetch. Content can supply 1–2 strings in `MicrocopyConfig` e.g. `InventoryLoadError`. |
| `DataUpdate` event handler throws | Same `RemoteLoadError` toast via `safeNotifyOnError` | **Keep** | Rare; same pool is appropriate. |

---

## Summary

| Area | Rows reviewed | Config-driven today? | Follow-up |
|------|---------------|----------------------|-----------|
| Remote / network toasts | 5 + leaderboard status | Mostly yes (`RemoteLoadError`) | Move leaderboard hardcoded strings to config |
| Purchase | 1 pool + native Roblox | Yes (`PurchaseFail`) | None for cancel (by design) |
| Inventory load | Toasts only | Yes (`RemoteLoadError`) | Optional inline empty-state copy if playtests ask |

**Row count (table body):** 11 data rows across three sections.
