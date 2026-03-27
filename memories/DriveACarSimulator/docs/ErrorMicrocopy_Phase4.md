# Error microcopy — Phase 4 audit (single table)

**Scope:** Highest-frequency **network / remote**, **purchase-adjacent**, and **inventory / currency** failure surfaces. Tone: short, blame-free, actionable — no promises the server cannot keep.

**Sources:** `DACReplicatedStorage/Config/MicrocopyConfig.luau`, `DACReplicatedStorage/RemoteFailSafe.luau`, `DACReplicatedStorage/FailureFeedback.luau`, `DACStarterGui/CodesPanel.luau`, `DACStarterGui/LeaderboardPanel.luau`, `DACServerScriptService/Services/CodeService.luau` (server messages that drive client branching).

---

| Surface | Current | Proposed | Wire note |
|--------|---------|----------|-----------|
| HUD toast — generic remote / snapshot miss | Random from `MicrocopyConfig.RemoteLoadError`, e.g. *"Couldn't sync that — give it another sec!"*; includes *"Oops, data didn't arrive — check your connection and retry!"* | **Pool:** keep 4 variants; **replace** the “check your connection” line with *"That didn’t load. Try again in a second."* (avoids implying the player’s connection is the problem) | `MicrocopyConfig.RemoteLoadError` → `RemoteFailSafe.notifyRemoteFailure` → `UIController.showToast` |
| HUD toast — same toast + technical suffix | Message becomes `{poolLine} [DATA]` / `[HATCH]` / etc. when `shortCode` is set | **Strip suffix for players** or swap for a plain English tail: *" (still syncing)"* — engineers keep full codes in `warn()` only | `RemoteFailSafe.luau` (`notifyRemoteFailure`) |
| Soft-fail — `InvokeServer` / wait exceeded | Random `MicrocopyConfig.SoftFailRemoteTimeout`, e.g. *"We waited… nothing yet. Try again — networks have moody days!"* | *"We didn’t get an answer in time. Tap again — nothing was lost."* | `MicrocopyConfig.SoftFailRemoteTimeout` (pair with POLA-353 timeout wiring) |
| Soft-fail — Roblox purchase prompt closed without charge | Random `MicrocopyConfig.SoftFailPurchaseCancelled` | **Keep** — already accurate and calm; optional tiny trim: *"Checkout closed — nothing charged."* | `MicrocopyConfig.SoftFailPurchaseCancelled` |
| Soft-fail — inventory / pet slot cap | Random `MicrocopyConfig.SoftFailInventoryFull`, e.g. *"Can't stash {ITEM} right now — the garage needs a free hook first!"* | *"No free slot for {ITEM} — free one up, then try again."* | `MicrocopyConfig.SoftFailInventoryFull` |
| Soft-fail — action cooldown (spam guard) | Random `MicrocopyConfig.SoftFailCooldownActive` | **Keep** — ensure `{ACTION}` stays 2–4 words (engineer-injected) | `MicrocopyConfig.SoftFailCooldownActive` |
| Soft-fail — almost enough currency (shop afford) | Random `MicrocopyConfig.SoftFailCurrencyShort` | **Keep** | `MicrocopyConfig.SoftFailCurrencyShort` |
| Soft-fail — generic recoverable mismatch | Random `MicrocopyConfig.SoftFailGenericRetry` | **Keep** | `MicrocopyConfig.SoftFailGenericRetry` |
| Center / milestone “failure_toast” — can’t afford car / upgrade | Random `MicrocopyConfig.PurchaseFail`, e.g. *"Can't afford it NOW, but future you definitely can!"* | *"Not enough coins yet — one more run usually covers it."* | `FailureFeedback` → `POOLS.purchase_fail` → `VFXFacade.failureFeedback` |
| Center toast — not enough gems for egg | Random `MicrocopyConfig.EggFail`, e.g. *"Need more gems for this egg!"* | *"Need more gems for this egg — playtime rewards still tick."* | `POOLS.egg_fail` |
| Center toast — equip locked (rebirth gate) | Random `MicrocopyConfig.EquipLocked`, e.g. *"Locked! Rebirth to unlock this tier."* | *"Unlocks after rebirth — keep climbing tiers to equip this."* | `POOLS.equip_fail` |
| Codes panel — wrong / unknown code | Random `MicrocopyConfig.CodeRedeemError` (server may send *"Code redemption failed"*; UI ignores literal message for copy) | **Keep pool**; avoid harsher “Invalid” openers in rotation — prefer *"That code isn’t active"* tone in pool refresh | `CodesPanel.luau` + server `CodeService.redeem` errors |
| Codes panel — expired code | Random `MicrocopyConfig.CodeRedeemExpired` when server message contains `"expired"` | **Keep** | Same as above; branch on `string.find(msg, "expired")` |
| Leaderboard panel — fetch error strip | Hardcoded *"Couldn't load."* | *"Leaderboard didn’t sync — try again in a moment."* | `LeaderboardPanel.luau` (~line 289); consider `MicrocopyConfig.LeaderboardLoadError` (see `PlayerFacingErrorCopy.md`) |
| FailureFeedback — unknown / missing pool | *"Something went wrong."* (`pickLine` empty-pool path is unreachable; unknown `feedbackType` falls back to `PurchaseFail` pool — fallback string only if pool length 0) | *"That didn’t work — try once more."* | `FailureFeedback.luau` |

---

**Coverage note:** `MicrocopyConfig.QuestFail`, `FuelEmpty`, and server strings like *"Already redeemed"* are real surfaces; **“Already redeemed”** currently hits the generic `CodeRedeemError` pool because `CodesPanel` only special-cases `"expired"`. Consider a follow-up row in config + branch for `string.find(msg, "redeemed")` — out of scope for this 15-row cap.

**Row count:** 15.
