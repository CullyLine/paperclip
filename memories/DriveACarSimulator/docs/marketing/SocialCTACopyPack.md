# Drive a Car Simulator — Social / Community CTA Copy Pack

**Issue:** POLA-301 (Phase 4 prep)  
**Role:** Game page, Settings, and Menu surfaces — **Discord / group / community** calls-to-action. Tone: **reward-forward, elite-aspirational** (matches `MicrocopyConfig` + Phase 4 whale-term policy: flex **systems and perks**, not player insults).

**Usage:** Paste into Creator Dashboard fields and pre-built UI labels as needed. **Copy-only deliverable** — wiring lives in configs (`GroupRewardConfig`, etc.).

---

## Roblox-safety quick reference

| Surface | Typical policy posture | Guidance |
|--------|-------------------------|----------|
| **Creator Dashboard → Experience → Social links** | Official slots for Discord, X, YouTube, etc. | **Preferred** place for Discord and other off-platform URLs. Use Roblox-provided fields rather than raw URLs in the long description when possible. |
| **Game description (997-char block)** | Avoid cluttering with multiple raw URLs; algorithm and moderation both favor clean copy. | Lead with **value** (“codes, patch notes, VIP drops”). Put **one** canonical group or social pointer if required; mirror `GamePageContent.md` structure. |
| **In-game UI (Settings / Menu)** | Prefer **on-platform** CTAs: **Join group**, **Favorite**, **Follow creator** — no obligation to show `discord.gg` in-frame. | Use **group-first** lines here; Discord can be “see game page / community links” if you need a single line without a URL. |
| **Group ID `0` in config** | Until a real group ships, copy should not promise a specific group perk number. | Swap placeholders `{GROUP}` / `{CREATOR}` when IDs are final. |

**Roblox-safe (in-game, no off-platform URL required):** lines that only reference **group join**, **favorite**, or **in-experience** actions.  
**Requires Dashboard / description slot (URL):** lines that name **Discord** with a link — place the actual URL in **Social links**, not necessarily in every in-game label.

---

## 1. Live game page — short CTA block (description or “Community” subsection)

**Primary (2 lines max)**

1. Join the crew — **group members** get bonus coins on every run + first-join loot.  
2. New codes and update drops hit **socials** first — don’t miss the next patch.

**Alternate A**

1. Want the meta first? Our **community** posts codes, sneak peeks, and patch notes before they trend.  
2. Roll with the **group** for a permanent coin edge — stack it with VIP if you’re going big.

**Alternate B**

1. **Favorite** + **follow** so you never lose the highway when we ship a content bomb.  
2. Group link in **Social** — tap through for perks that stack with your best runs.

---

## 2. Live game page — one-line “social strip” (thumbnail caption / Shorts bio / link-in-bio)

**Primary**

- Drive. Stack coins. **Join the group** — perks stack with your grind.

**Alternate**

- Codes drop fast. **Community + group** = first in line for the next buff.

---

## 3. In-game **Settings** — community row / footer (group-first, optional Discord nod without URL)

**Primary (2 lines max)**

1. **Join our Roblox group** for a coin bonus and welcome rewards — link opens the official page.  
2. More loot paths? Check **Creator social links** on the game page for Discord and updates.

**Alternate A**

1. Group perks are **always on** — join once, earn more every run.  
2. Full patch notes and code drops: use the game page **Social** section.

**Alternate B**

1. Not in the group yet? You’re leaving **bonus coins** on the table every run.  
2. Tap **Join group** above — then come back and claim when you’re in.

---

## 4. In-game **Menu / hub** — compact CTA (banner-sized or button subtext)

**Primary (2 lines max)**

1. **Go elite:** group bonus + VIP = maximum coin velocity.  
2. Tap **Join group** — takes seconds, pays every session.

**Alternate A**

1. **Stack advantages** — group perk, game pass, streak. That’s the top-lobby setup.  
2. Join the group from the prompt — rewards wait after you rejoin.

**Alternate B**

1. Codes and chaos drop where our **community** posts first.  
2. Group link is one tap — grab your **+coin** edge before the next run.

---

## 5. Discord-specific (Creator Dashboard social label + optional description mention)

Use the **Dashboard Discord field** for the actual invite. Keep in-game text **optional** and URL-free if you want maximum Roblox UI safety.

**Primary label ideas (short)**

- **Discord:** Patch notes, codes, and vibe checks — members see it first.  
- **Alternate:** **Server:** Ask questions, flex builds, catch code leaks early.

**One-line description teaser (no raw URL in body if avoiding links)**

- We announce codes and updates in our **Discord** (linked under **Social** on this page).

---

## 6. Group join — aligns with `GroupRewardConfig` banner tone

Existing config lines are the baseline; these are **marketing alternates** for A/B or future UI.

**Primary**

- Join our group for **+5% coins** + a free pet!  
- Tap Join to open the group page, then rejoin to claim rewards.

**Alternate**

- **Group drivers** earn more every run — join, rejoin, claim.  
- One join, permanent **coin edge**. Your haul deserves the multiplier.

---

## Maintenance

| When | Action |
|------|--------|
| `GroupRewardConfig.groupId` finalized | Replace placeholder language with real group name if marketing approves. |
| Discord invite rotates | Update **Dashboard** only; in-game copy can stay generic. |
| New social (e.g. TikTok) | Add a row to §2 / §5; keep in-game surfaces group-first unless policy review says otherwise. |

---

## File on disk

| Path | Role |
|------|------|
| `docs/marketing/SocialCTACopyPack.md` | This pack (POLA-301). |
| `docs/GamePageAndDiscoveryCopy.md` | Phase 4 discovery / shorts alignment. |
| `DACReplicatedStorage/Config/GroupRewardConfig.luau` | In-game group banner strings (engineering source of truth). |
