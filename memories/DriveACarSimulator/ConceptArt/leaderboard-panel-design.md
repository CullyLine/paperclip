# In-Menu Leaderboard Panel — Design Spec (DAC)

**Issue context:** Surface-only leaderboard exists on world mesh; this spec defines an **in-menu** `LeaderboardPanel` under `StarterGui.DACMain`, opened from HUD (e.g. trophy / chart icon), matching **AGENTS.md** panel anatomy and pastel simulator language.

---

## 1. Purpose & UX

| Goal | Detail |
|------|--------|
| Parity | Match top-simulator expectation: full leaderboard without walking to a board. |
| Modes | Player compares **Distance**, **Coins**, **Rebirths**, and **Friends** (server friends + optional friends-only filter). |
| Clarity | Top **100** visible in a scroll list; local player always findable via **Your Rank** footer. |

---

## 2. Panel anatomy (mandatory — AGENTS.md)

1. **Tab bar** — White **pill** container **above** the main panel body, centered. Four tabs with **dark silhouette icons** (ruler/road, coin stack, rebirth skull/arrow, two people). Active tab: slightly larger icon + soft pastel fill (`#FFD6EE` tint) inside the pill segment.
2. **Title** — **Outside** the panel frame, **top-left**: colorful icon (trophy or podium) + **GothamBlack**, **white** text, **black TextStroke** (~0.45–0.55 transparency). Title copy: **“Leaderboard”** (or **“Top Drivers”** if product prefers flavor).
3. **Close** — **#FF2222** rounded square, white **✕**, **top-right** of the **body** frame (not overlapping title float).
4. **Body** — Vertical **UIGradient**: **#FFD6EE** (top) → **#E0D6FF** (bottom). **UIStroke** charcoal **#2A2A40**, **2–3 px**. **UICorner** ≥ **14 px**. Optional faint watermark (car/pet silhouettes at ~6–10% opacity) like other DAC panels.
5. **Content** — Scrollable list region (see §3) fills body below tab pill overlap.
6. **Sticky footer** — **Your Rank** bar pinned to **bottom inside body** (above outer safe area on mobile); does not scroll with list.

**Pre-built rule:** Static shell (root, tabs, scroll container, footer chrome, close) = **pre-built** under `DACMain`; **rows** = runtime `Instance.new` parented to scroll (same pattern as inventory rows).

---

## 3. Layout & components

### 3.1 Tab strip

| Tab | Stat shown in list | Notes |
|-----|-------------------|--------|
| Distance | Total distance (formatted) | Default tab on open if product agrees. |
| Coins | Lifetime or session per `LeaderboardService` contract | Large numbers: use existing `Utils.formatNumber` style. |
| Rebirths | Rebirth count | |
| Friends | Same stat as active “primary” tab **but** list filtered to **friends in server** (or friends first + rest grayed — pick one in implementation; spec assumes **filter**). |

Inactive tabs: readable gray label **#5C5C70**; active: **#1E1E1E** **GothamBold**.

### 3.2 Scroll list (top 100)

- **ScrollingFrame** with **UIListLayout** vertical, **8 px** padding between rows, **12 px** inner padding from body edges.
- **Row height:** chunky (~**48–56 px** at 1080p reference) — never cramped.
- **Per row (left → right):**
  1. **Rank column (fixed ~56 px):**  
     - Ranks **1–3:** **crown** asset — **gold / silver / bronze** (use `ReplicatedStorage.Images` or new approved assets; three distinct tints **#FFD700**, **#C0C0C0**, **#CD7F32** with **UIStroke** for readability).  
     - Ranks **4–100:** **GothamBold** numeral, **#1E1E1E**, centered in column.
  2. **Avatar:** **Circular** mask (**UICorner** 1,0,1,0 or `ImageLabel` round), **40–44 px**, **1–2 px** **#2A2A40** stroke.
  3. **Display name:** **GothamBold**, **#1E1E1E**, truncate with **…** if long.
  4. **Stat value:** **right-aligned**, **GothamBold**, **#1E1E1E**; use **Coin Gold** `#FFD54F` or **emerald** `#2ECC71` accents only for emphasis if design needs (e.g. your row).

**Current player row:** full-width **subtle glow** — e.g. **UIStroke** **#4FC3F7** or **#AB47BC** at **2 px**, plus **BackgroundColor3** white at **0.15** transparency behind row, or **UIGradient** left-to-right pastel highlight. Must be obvious at a glance.

### 3.3 Empty / loading

- **Loading:** skeleton rows (3–5 gray rounded bars) or spinner in DAC pastel style — **no** minimal Material spinner.
- **Friends tab, no friends in server:** friendly copy: **“No friends here yet — invite some!”** **GothamBold**, **#1E1E1E**, centered in scroll area.

### 3.4 Sticky footer — “Your Rank”

- **Height:** ~**52–60 px**; **top border** **2 px** **#2A2A40** or inset shadow to separate from scroll.
- **Background:** slightly **more saturated** lavender strip (`#E8DEFF`) or white **0.2** transparency overlay so it reads as **footer**.
- **Content:**
  - Left: small **“YOUR RANK”** **GothamBold** **#5C5C70** (or section header bar style from AGENTS.md).
  - Center/left: **your avatar** + **display name** (same sizes as row, compact).
  - Right: **#42** (rank) + **stat** for current tab.
- If player is **not** in top 100: show **“#142 globally”** style — still **truthful** to backend.

---

## 4. Typography

| Element | Font | Notes |
|---------|------|--------|
| Panel title | GothamBlack | Outside frame |
| Tabs | GothamBold | |
| Row name / stat | GothamBold | |
| Footer label | GothamBold | |
| Tiny hints | Gotham | Secondary only |

---

## 5. Registration & open behavior

- `MenuHub.registerPanel("leaderboard", rootFrame)` (or agreed key).
- Opens from HUD button; **does not** pause driving if product uses tap-to-open while idle — document in implementation if needed.

---

## 6. Engineer checklist

- [ ] Shell + scroll + footer pre-built; rows cloned or `Instance.new` in controller.
- [ ] Tab switch requests correct stat from server / replicated leaderboard cache.
- [ ] Friends tab respects privacy (friends in server only).
- [ ] Top 3 crowns + **#1E1E1E** ranks 4+.
- [ ] Local player row highlight + footer always synced.
- [ ] Mobile: safe area, touch scroll, no sub-12 px text.

---

## 7. Reference

- `AGENTS.md` — Visual Design Guide, pre-built UI rule.
- `ConceptArt/visual-style-guide.md` — palette / typography.
- `DAC/*.PNG` — Pets Inventory panel as canonical chunkiness.
