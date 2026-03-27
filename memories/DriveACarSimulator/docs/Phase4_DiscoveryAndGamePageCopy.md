# Phase 4 — Discovery & game-page copy (Creator updates)

**Purpose:** Single playbook for **weekly Roblox Creator Dashboard updates** and **store/discovery alignment** (Phase 4 polish).  
**Related:** `docs/GamePageAndDiscoveryCopy.md` (title, description delta, keyword list, social one-liners), `GamePageContent.md` (master store page), `docs/marketing/WhatsNewBullets.md` (What’s New lines).

---

## 1. When to use this doc

- Before each **weekly publish**, draft the Creator **Update** post here, then paste into Dashboard.
- Keep **one honest line** between what players see in-session and what the page/update promises (see §5–§6).

---

## 2. Canonical sources (do not fork)

| File | Role |
|------|------|
| `GamePageContent.md` | Master title, 997-char description, tags, thumbnails |
| `docs/GamePageAndDiscoveryCopy.md` | Phase 4 keyword additions, social one-liners, discovery notes |
| `docs/marketing/WhatsNewBullets.md` | Bullet library for news / Discord / description inserts |

---

## 3. Tone guardrails

- **No competitor game names.**
- **No false urgency** (“last chance forever”, fake countdowns) unless a real time-limited event exists in-game.
- **Tuning / balance** copy: keep **0–2 short bullets**, factual; avoid apologizing or over-hyping.

---

## 4. Title pattern reference (store page)

Primary store title remains **`Drive a Car Simulator`** unless experiments prove a subtitle helps *qualified* CTR — see `docs/GamePageAndDiscoveryCopy.md` §1. Weekly **Creator update titles** use §5 below (different channel, same brand).

---

## 5. Weekly Creator update — title patterns (SEO + clarity)

Pick **one** pattern; pair it with a **specific feature or area** (not generic hype).

| Pattern | Use when | Example shape |
|---------|----------|----------------|
| **Update** | Shipped a concrete change players can notice | “Update: [Feature] — [one benefit]” |
| **Polish** | UX, juice, audio, HUD, onboarding, notifications | “Polish: [Area] — [player-visible improvement]” |
| **Event** | Limited-time or seasonal content (only if true) | “Event: [Name] — [dates or scope]” |

**Bad:** “Huge amazing update!!!”  
**Good:** “Polish: notification lane — achievements and milestones queue more cleanly on mobile.”

**First bullet** under the title should state **player benefit** (what changed for their session), not internal milestone names.

---

## 6. Discovery keywords (natural in first two lines)

Weave **at least one** of these into the **first two lines** of the update body **in a natural sentence** (not comma-stuffed lists):

`hatch`, `rebirth`, `pet`, `simulator`, `leaderboard` (plus broader terms from `docs/GamePageAndDiscoveryCopy.md` §3 where relevant: `achievements`, `worlds`, `eggs`, `drive`, `coins`, etc.).

Algorithms and readers both punish **keyword stuffing** — one clear phrase beats five tags.

---

## 7. Tuning / balance section

- **Optional** subsection for balance notes.
- **0–2 bullets max.** Honest, short. If nothing material changed, **omit** this section.

---

## 8. Checklist — paste into the ticket comment when you publish

Copy this block into the Paperclip issue (or internal changelog) when a weekly Creator update goes live:

```markdown
## Weekly Creator update checklist (Phase 4)

- [ ] Title uses **pattern** from §5 (Update / Polish / Event) + **specific feature name**, not generic hype.
- [ ] First bullet is **player benefit** (what changed for their session).
- [ ] Tuning section is honest (**0–2** bullets max).
- [ ] First **2 lines** of body include at least one **discovery keyword** from §6 (natural: hatch, rebirth, pet, simulator, leaderboard).
- [ ] No competitor game names; no false urgency.
```

---

## 9. Files on disk

| Path | Role |
|------|------|
| `docs/Phase4_DiscoveryAndGamePageCopy.md` | This playbook (POLA-361). |
| `docs/Phase4_ThumbnailAndShortHookBank.md` | Index: thumbnails + short hooks + links to `GamePageContent.md` §4 (POLA-661). |
