# What’s New — Phase 4 (player-facing)

**Purpose:** Reusable copy for a future in-game news modal, Discord, or social post. For Creator Dashboard store fields, use `docs/StorePageCopy_Phase4.md` (POLA-370).  
**Parent:** POLA-104 · **Ticket:** POLA-375

---

## Character budgets (paste before publish)

| Surface | Typical limit | How to use this doc |
|--------|----------------|----------------------|
| **Roblox group shout** | **255** characters | Use § Group shout only — trim emoji or clauses if the client rejects the paste. |
| **News modal / blog / Discord** | Paragraph **≤ ~600** characters + bullets below; total block can exceed 600 | Use § Paragraph + § Bullets together. |

---

## Group shout (≤ 255 characters)

**Canonical line (216 characters with spaces):**

```
Phase 4 polish is live: guided first runs, achievements + trophy case, milestone celebrations, smarter HUD & notification lane, friend/group run bonuses, and clearer loading tips. Hop in with friends for extra coins!
```

**Tighter spare (171 characters)** if you need room for emoji or link tracking:

```
Phase 4 polish: guided first runs, achievements + trophy case, milestone celebrations, smarter HUD & notification lane, friend/group run bonuses, and clearer loading tips.
```

---

## Paragraph + bullets (modal / longer surfaces)

### Paragraph (478 characters)

Phase 4 is about feel: clearer first runs, achievements you can show off in a trophy case, and milestone celebrations tuned to reward big moments without drowning out the road. We tightened HUD layout for phones and desktops, polished the notification lane so achievements queue next to driving feedback predictably, and added bonus coins when Roblox friends drive in your server—plus group supporter rewards when configured. Load-in tips are clearer while the world streams in.

### Bullets (6) — headline Phase 4 shipped behavior

1. **Guided first runs** — Welcome beats for your first payout, hatch, trophy case, and daily streak so new drivers aren’t guessing the loop.
2. **Achievements & trophy case** — Unlock milestones and browse them in a dedicated panel built for completionists.
3. **Milestone celebrations** — First-time and spend milestones land with celebration feedback tuned to feel rewarding, not spammy.
4. **HUD & notification lane** — Safe-area layout; achievements and milestones queue more predictably next to driving feedback on phone and desktop.
5. **Friends & group** — Bonus coins when Roblox friends are in the same server; join the community group for supporter perks *(rates match live config when published).*
6. **Loading** — Clearer tips and a softer boot while the world streams in.

**Approximate combined size:** ~1,150 characters (paragraph + bullets + numbering), suitable for a modal with scroll or a blog section — not for the 255 shout.

---

## Alignment note (docs cross-check)

- **Tone and claims** match `docs/StorePageCopy_Phase4.md` (POLA-370): same Phase 4 pillars—onboarding, achievements/trophy case, milestones, HUD/notifications, friends, group, loading. This file adds **explicit character budgets** for shout vs modal and a **ready-to-paste shout** line.
- **`docs/marketing/WhatsNewBullets.md` (POLA-309)** also lists **return / streak welcome** copy and a **conditional** “sound & mix” bullet for publishers who ship that pass in a given build. Those lines are **not repeated here** so we do not imply an audio pass unless the publish includes it; streak framing is already covered under **Guided first runs** / daily streak above, consistent with the store pack.
- **POLA-95:** Do not tell players that game passes or developer products are “live” or “wired to real IDs” until Dashboard SKUs and configs are confirmed; none of the copy above claims paid SKU wiring.
