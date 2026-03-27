# Parental controls — compliance blurbs (Phase 4)

**Purpose:** Short, parent-facing copy for the **Roblox game page**, a **Discord** pinned intro, and a future **in-game** tooltip. Tone is neutral and supportive; it does not promise legal outcomes or create duties beyond pointing to Roblox’s own resources.  
**Parent:** [POLA-104](/pola/issues/6802628e-70f5-4106-a13e-2342ef950399) · **Ticket:** POLA-456

**Official reference (Roblox):** [Account Restrictions and Parental Controls](https://en.help.roblox.com/hc/en-us/articles/360000236703-Account-Restrictions-and-Parental-Controls) — use this link wherever you mention parental controls; we do not substitute for Roblox’s help content.

**Disclaimer:** This document is **informational only**. It is **not** legal advice, and we **do not** guarantee specific account or safety outcomes. Parents and guardians remain responsible for account settings on Roblox.

**Community expectations in this experience:** [`CommunityRules_Phase4.md`](CommunityRules_Phase4.md) (paste packs) · [`CommunityRules.md`](CommunityRules.md) (baseline expectations).

---

## 1. Roblox game page / description — paragraph for parents

If you’re deciding whether this experience is right for your family, **Roblox** (not individual games) provides **account restrictions and parental controls**—including who can chat, which experiences are allowed, and how purchases work. We design **Drive a Car Simulator** for broad audiences and expect respectful play aligned with our community rules ([`CommunityRules_Phase4.md`](CommunityRules_Phase4.md)); for platform-level safety tools, follow Roblox’s guide: [Account Restrictions and Parental Controls](https://en.help.roblox.com/hc/en-us/articles/360000236703-Account-Restrictions-and-Parental-Controls).

---

## 2. Discord — pinned message (short paragraph)

**Parents & caregivers:** This server is about **Drive a Car Simulator** on Roblox. In-game behavior should match our **community rules** ([`CommunityRules_Phase4.md`](CommunityRules_Phase4.md)). **Chat limits, privacy, and spending** are managed in **your Roblox account settings**, not by this Discord—see Roblox’s overview here: [Account Restrictions and Parental Controls](https://en.help.roblox.com/hc/en-us/articles/360000236703-Account-Restrictions-and-Parental-Controls). This pin is informational, not legal advice.

---

## 3. In-game tooltip — body (under 200 characters)

**Paste-ready line:**

```
Parents: Roblox lets you set chat, privacy, and spending on your child’s account—see Roblox Help, Parental controls. We don’t run those settings. Info only; rules: Community menu.
```

| Check | Value |
|--------|--------|
| **Character count** | 179 / 200 (including spaces; UTF-8) |
| **Wire note** | Reserve **`MicrocopyConfig.ParentalControlsTooltipBody`** (or Settings/legal row) when a parent-facing surface ships; no key exists today—**copy-only** until UI affordance is approved. |

**Rationale:** Keeps the official topic name findable on Roblox without embedding a long URL in tiny UI; the game page and Discord blocks above carry the full link. If engineering later supports a **Learn more** button, pair this body with the same help URL as a secondary action.

---

## 4. QA checklist

- [ ] Game-page paragraph + Discord pin both link to Roblox’s **parental controls** article (same URL as this doc’s header).
- [ ] No wording implies we guarantee moderation outcomes, refunds, or legal results.
- [ ] Community expectations cross-linked to **`CommunityRules_Phase4.md`** / **`CommunityRules.md`** at least once per surface (above sections satisfy this).
