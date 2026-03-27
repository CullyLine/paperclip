# Number formatting style guide (HUD + UI)

**Audience:** Engineering implementing or refactoring `formatNumber` helpers and any UI that shows coins, currencies, scores, distance, or multipliers.

**Goal:** One consistent mental model for players: abbreviated big numbers during play, readable precision where it matters, and no mixed conventions in the same surface.

---

## Canonical helper (today)

`DACReplicatedStorage/Utils.luau` — `Utils.formatNumber(n: number): string` is the **default** for currency-like and large score values across HUD, panels, and most toasts.

Reference behavior (keep docs in sync if this changes):

| Range | Output shape | Example |
| --- | --- | --- |
| `n >= 1_000_000_000_000` | One decimal + `T` | `1.2T` |
| `n >= 1_000_000_000` | One decimal + `B` | `3.4B` |
| `n >= 1_000_000` | One decimal + `M` | `12.5M` |
| `n >= 1_000` | One decimal + `K` | `1.2K` |
| `n < 1_000` | Integer string, **no** suffix | `0`, `42`, `999` |

Implementation uses `math.floor` for the sub-1K branch and `string.format("%.1f", …)` for every abbreviated tier.

---

## Abbreviations

- **Suffixes:** `K` (thousands), `M` (millions), `B` (billions), `T` (trillions). Uppercase only in UI strings.
- **Precision:** Exactly **one** digit after the decimal for all abbreviated tiers (e.g. `1.2M`, not `1.25M` or `1M`).
- **Thresholds:** Abbreviate at **1e3 / 1e6 / 1e9 / 1e12** inclusive, matching the table above. Do not introduce `k`/`m` lowercase or locale-specific suffixes unless product explicitly requests localization later.

---

## Thousands separators (full numbers)

- **When:** Use **comma-separated groups of three** (US-style) when showing a **full integer** for emphasis, clarity, or comparison — e.g. distance in **studs** on leaderboards, or any spec that calls for “exact” feel.
- **How:** Digits only, commas between groups; no decimals unless the value is genuinely fractional (rare for studs). Example: `1,234,567` studs.
- **Do not** combine comma grouping with `K`/`M`/`B`/`T` in one token (bad: `1,2M`; good: `1.2M` **or** `1,200,000` depending on mode).

---

## Max digits & density

- **HUD / live counters:** Prefer `Utils.formatNumber` so labels stay short; avoid wrapping on mobile.
- **Sub-1K integers:** No decimal places; floor toward zero for display consistency with current helper.
- **Multipliers** (e.g. stacked run multiplier in payout flex lines): Use **one** decimal (`"%.1f"`) unless design spec asks otherwise; do not use `formatNumber` for multipliers that are typically small (e.g. `2.4x` not `2.4Kx`).

---

## Edge cases

- **Billions / trillions:** Supported via `B` and `T` tiers; same one-decimal rule.
- **Zero:** Show `0` (no `0.0K`).
- **Negative values:** If they can appear in UI, prefer explicit sign and same tier rules (e.g. `-1.2M`); confirm gameplay actually allows negative currency before showing.
- **Non-finite values:** Avoid displaying `inf`/`nan` to players; clamp or substitute with `—` / `0` per surface.

---

## When to show full numbers vs abbreviated (including run-end payout)

| Context | Default | Notes |
| --- | --- | --- |
| In-run HUD (coins, gems, crystals, skulls) | Abbreviated (`Utils.formatNumber`) | Keeps layout stable. |
| Store / inventory costs | Abbreviated | Matches HUD. |
| Leaderboard distance (studs) | **Comma full integer** where implemented | Easier to compare ranks at a glance. |
| Run-end payout summary (coins / distance lines) | Abbreviated **today** (`PayoutPanel` uses `Utils.formatNumber`) | If a future polish pass wants a “big reveal” beat, optional **comma full integer** for the primary coin line only is acceptable; document in the relevant UI spec. |
| Admin / debug readouts | May use full integers | Not player-facing polish. |

**Rule of thumb:** Abbreviate for speed and density; use full comma-separated integers when the moment is **about precision or comparison**, not speed.

---

## Copy and units

- Put the **number before** the currency name when both appear (`1.2M coins`), unless a template already uses `{AMOUNT}` substitution — keep templates consistent with `MicrocopyConfig` / panel copy.
- **Studs** and **meters** should keep their unit suffix outside the formatted number (`1.2K studs`, `{Utils.formatNumber(n)} m`).

---

## Engineering checklist (new UI)

1. Use `Utils.formatNumber` for large currencies and scores unless the spec says otherwise.
2. For stud-style leaderboard lines, reuse or mirror **comma** integer formatting (see `formatStudsComma` pattern in `VFXController`) — do not use `formatNumber` if the spec asks for commas.
3. Keep multiplier displays separate from currency formatting.
4. After changing thresholds or precision, update **this doc** and scan for duplicate local `formatNumber` copies (e.g. configs) for consistency.

---

## Rule index (for ticket closure)

1. Default large numbers: `Utils.formatNumber`.
2. Suffixes: `K` / `M` / `B` / `T` only, uppercase.
3. One decimal place on every abbreviated tier.
4. Sub-1K: integer string, no decimals.
5. Thresholds at 1e3, 1e6, 1e9, 1e12.
6. No comma grouping inside abbreviated tokens.
7. Comma thousands for full integers when the spec calls for precision/compare (e.g. studs).
8. Do not abbreviate multipliers like currency; use dedicated float format (e.g. `"%.1f"`).
9. Zero displays as `0`.
10. Run-end: abbreviated by default; full comma optional for hero moments if spec’d.
11. Units (`coins`, `studs`, `m`) after the numeric token.
12. Update this document when `Utils.formatNumber` behavior changes.

**Total: 12 rules.**
