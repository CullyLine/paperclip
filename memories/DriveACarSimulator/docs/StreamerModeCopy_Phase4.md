# Streamer safety — what to hide on broadcast (Phase 4)

**Purpose:** Practical guidance for creators streaming **Drive a Car Simulator** (or clipping for Shorts/TikTok) so they reduce accidental exposure of sensitive or policy-sensitive UI **before** a dedicated in-game streamer mode exists. This is **not** legal advice; when in doubt, follow [Roblox’s Community Standards](https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Community-Standards) and your platform’s rules.  
**Parent:** POLA-104 · **Ticket:** POLA-430

**Related docs:** [`docs/CommunityRules_Phase4.md`](CommunityRules_Phase4.md) (fair play, reporting, community tone) · [`docs/PlayerFAQ_Phase4.md`](PlayerFAQ_Phase4.md) (purchases, codes, progress—facts viewers often ask about).

---

## What to blur, cover, or avoid showing

Use OBS/browser source masks, crop, or scene switching—whatever fits your setup. Priority is anything that could fuel scams, harassment, or chargebacks confusion when clipped out of context.

| Area | Why it matters | What to do |
|------|----------------|------------|
| **Codes UI** (entry panel, redemption confirmation, chat overlays with codes) | Codes are one-time or time-limited; showing them on stream invites sniping, off-platform sharing, and “fake code” spam in chat. | Blur or crop the code field and confirmation text; **do not** read full codes aloud on stream. Prefer redeeming **off-stream** or after a scene cut. |
| **Purchase prices & receipts** (Store, Roblox purchase prompts, DevProduct confirmations, Robux balances if shown) | Reduces “pay to win” flame, minimizes chargeback confusion, and avoids looking like you’re pressuring viewers to spend. | Use a generic “Store” scene without price detail, or blur price rows; avoid lingering on purchase success toasts. |
| **Player IDs / usernames in admin or debug** (leaderboard rows, trade UI, friend lists, rare “userId” debug) | Reduces targeted harassment, impersonation, and unsolicited friend requests. | Crop or blur columns that show **unique IDs**; for leaderboards, consider a layout that shows **rank + display name** only if you’re comfortable—still avoid doxxing-adjacent piles of names in drama clips. |
| **Private chat / DMs** (if you mirror or show them) | Never safe to broadcast; often violates others’ expectations. | Don’t show; use separate “chatting” scenes without game chat if needed. |
| **Email or real names** (account settings, support tickets) | Obvious PII. | Never show; use a separate monitor or off-stream profile. |

---

## Optional on-screen watermark lines (pick one)

Short, neutral lines you can put in a corner overlay (OBS text source) to set expectations. Rotate or shorten if cluttered.

1. **“Gameplay only — not financial advice; purchases optional.”**  
   - Good for: long sessions, store-heavy segments.

2. **“Codes & rewards shown on stream may be expired — check official posts.”**  
   - Good for: when you still mention codes or events without showing the full redemption UI.

3. **“Be kind in chat — follow Roblox & channel rules.”**  
   - Good for: aligning with [`docs/CommunityRules_Phase4.md`](CommunityRules_Phase4.md) without duplicating the full rules text.

---

## Quick checklist before going live

- [ ] Codes panel **not** visible unless blurred; no reading codes aloud.
- [ ] Store/pricing scenes cropped or **generic** (no lingering on Robux purchase sheets).
- [ ] No player **UserId** columns or debug strings; leaderboards acceptable only if you accept name visibility tradeoffs.
- [ ] Community tone matches [`docs/CommunityRules_Phase4.md`](CommunityRules_Phase4.md); FAQ facts for viewers summarized from [`docs/PlayerFAQ_Phase4.md`](PlayerFAQ_Phase4.md) if you take Q&A.

---

## Future product note (out of scope for POLA-430)

A dedicated **streamer mode** in-client could automate blur regions (codes, prices, IDs). Until then, this document is the **copy and positioning** reference for creators and community managers.
