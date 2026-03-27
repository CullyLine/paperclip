# Premium monetization surface hierarchy (visual)

**Issue:** POLA-279 · **Parent:** POLA-104 · **Cross-ref:** [Premium upsell tone matrix (POLA-273)](./PremiumUpsellToneMatrix.md)

**Purpose:** When **store**, **game pass prompt**, and **dev product prompt** coexist in design or could stack in a session, this doc fixes **one** rank order for **gold frame**, **pulse**, and **particles** so art and UI engineering do not ship three “hero” treatments at once.

**Scope:** Design notes only — no product IDs, no implementation tickets implied.

---

## Rank order (highest → lowest premium chrome)

| Rank | Surface | Gold frame | Pulse | Particles | Rationale |
|:----:|---------|:----------:|:-----:|:---------:|-----------|
| **1** | **Dev product prompt** (single-SKU modal / sheet) | **Yes** — primary | **Yes** — heartbeat / urgency | **Yes** — light confetti/sparkle burst on open or CTA emphasis | One-shot purchase moment; matches **Aggressive** and whale lanes in POLA-273; highest conversion density per screen. |
| **2** | **Game pass prompt** (pass stack / upsell modal) | **Yes** — secondary (slightly thinner or shared token vs #1) | **Yes** — slow / “breathing” pulse | **Sparse** — optional; **no** competing burst if #1 shown same session | Long-term value (LTV); should feel **premium and permanent**, not flash-sale noisy. |
| **3** | **Store** (browse / catalog shell) | **No** on the shell; **yes** only on **featured hero card** or pinned row | **Optional** on hero card only | **No** ambient store-wide particles | Browse clarity first; POLA-273 **Balanced** lane lives here. Particles reserved for rank **1** (and rare milestones elsewhere). |

---

## Conflict rules

1. **Never** apply **full** rank-1 stack (gold + pulse + particles) to more than **one** monetization surface **at the same time** on screen.
2. If **dev product prompt** and **game pass prompt** queue in one flow: dev product uses rank **1**; game pass uses rank **2** with **particles off** unless dev product is dismissed.
3. **Store** never borrows rank-1 particles for the **root frame**; only a **single** in-store hero slot may use **gold + soft pulse**, still **below** a live rank-1 modal if both are somehow visible (prefer hiding store chrome behind the modal).

---

## Alignment with POLA-273

- **Aggressive / whale energy** → dev product prompt (rank **1**).
- **Balanced browsing** → store layout and copy-first cards (rank **3** shell, controlled hero).
- **Pass “stack” permanence** → game pass prompt (rank **2**) — premium, not casino.

---

#### Files on disk

| File | Role |
|------|------|
| `docs/store/PremiumSurfaceHierarchy.md` | This hierarchy (POLA-279). |
| `docs/store/PremiumUpsellToneMatrix.md` | Headline/subline tone matrix (POLA-273). |
