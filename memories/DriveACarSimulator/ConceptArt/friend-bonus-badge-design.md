# Friend Bonus HUD Badge — Design Spec (DAC)

**Purpose:** Small **HUD** affordance when **≥1 friend** is in the server, communicating the **+10% Coins** (or configured) multiplier without cluttering the main HUD.

---

## 1. Placement

| Rule | Detail |
|------|--------|
| Anchor | **Below** the **currency strip** (coins / gems / crystals row at top of screen). |
| Alignment | **Left** or **center-left** under strip — **non-intrusive**; must not cover **Drive** / primary action buttons. |
| Z-order | Above world, below modal panels / toasts. |

If the currency strip layout differs per aspect ratio, badge uses **same horizontal margin** as currency row (e.g. **12–16 px** inset from safe area).

---

## 2. Visual shape — compact pill

- **Container:** **Horizontal** auto-width pill — **UICorner** **0.5,0** (fully rounded ends) or fixed height **32–38 px** with **corner radius = height/2**.
- **Fill:** Match DAC positivity — **white** base + **UIGradient** **#FFD6EE** → **#E0D6FF** (same family as panels) **or** slightly more saturated bottom for “juice.”
- **Stroke:** **UIStroke** **#2A2A40**, **2 px** — chunky, not hairline.
- **Shadow:** Optional **1–2 px** drop shadow (dark, low opacity) for separation from busy backgrounds.

---

## 3. Content layout (left → right)

1. **Avatar cluster (max 3)**  
   - **Overlapping** circular thumbnails (**-8 to -10 px** overlap) for depth.  
   - Each **28–32 px** diameter, **#2A2A40** **1–2 px** ring.  
   - Order: arbitrary stable order or join-time — implementation detail; **newest friend** optional polish.  
   - If **>3 friends** in server: show **3** + **tiny “+N”** **GothamBold** badge on last circle (**#1E1E1E** on **#FFD54F** micro-pill).

2. **Copy**  
   - **“+10% Coins”** — **GothamBold**, **#1E1E1E** (primary).  
   - If multiplier is dynamic, bind to config string e.g. **`+{percent}% Coins`**.

3. **Optional micro-icon**  
   - Small **coin** or **two-person** glyph **16–18 px** between avatars and text — only if spacing allows; **omit** if crowded on phone portrait.

**Padding:** **8–10 px** horizontal inside pill; **4–6 px** vertical minimum.

---

## 4. Visibility & animation

| State | Behavior |
|-------|----------|
| Hidden | **0 friends** in server → `Visible = false` or scale 0. |
| Enter | Brief **scale** 0.92 → 1.0 + **fade** 0 → 1 (**0.2–0.35 s**, `Quad Out`). |
| Active (friends present) | **Subtle glow** pulse — e.g. **UIStroke** color tween **#2A2A40** ↔ **#66BB6A** or **#FFD54F** at **low amplitude**, **2–3 s** loop; **or** outer **Frame** with **GradientTransparency** breathing. **No** seizure-fast strobing. |
| Friend leaves | If count → 0, **reverse** enter tween then hide. |

**Performance:** Prefer **TweenService** on **UIStroke** / **ImageTransparency**; avoid per-frame layout for mobile.

---

## 5. Typography & color

| Element | Spec |
|---------|------|
| Bonus text | **GothamBold**, **#1E1E1E** |
| +N overflow | **GothamBold**, **#1E1E1E** on **#FFD54F** pill |
| Accent | **Coin Gold** `#FFD54F` for “+10%” numeric if split styling |

---

## 6. Pre-built vs runtime

- **Static:** Pill container, layout, placeholder avatars, label — **pre-built** under HUD ScreenGui (e.g. `DACMain` sibling or dedicated `DACFriendBonus` gui).
- **Runtime:** Swap **avatar Image** from **userId** thumbnails; show/hide; tweens — **allowed** (ephemeral behavior).

---

## 7. Accessibility & clarity

- Tooltip or long-press (optional): **“Playing with friends boosts your coins!”** — **Gotham**, **#1E1E1E**.
- Color is not the only signal — **text always** states **Coins** bonus.

---

## 8. Engineer checklist

- [ ] Anchored **below** currency strip with shared safe-area margins.
- [ ] Max **3** faces + overflow **+N**.
- [ ] Subtle glow animation when visible; hidden when no friends.
- [ ] Uses **SoundFacade** only if product adds a tiny **pop** on appear (optional; default silent).
- [ ] Matches **AGENTS.md** chunky rounded language — **no** flat Material chips.

---

## 9. Reference

- `AGENTS.md` — Shape language, Gotham usage, positive green `#2ECC71` / gold accents.
- `ConceptArt/leaderboard-panel-design.md` — Related social/competition UI.
