# Prompt Playbook: AI Video Generation

A living document tracking which AI generation prompts produce the funniest videos, what works, what doesn't, and why.

> Parent directive: [POL-78](/POL/issues/POL-78) — AI-Generated Video R&D

---

## Scoring Guide

| Rating | Meaning |
|--------|---------|
| 10/10 | Instant classic, share-worthy on first watch |
| 8-9 | Strong — minor tweaks would perfect it |
| 6-7 | Decent concept, execution needs work |
| 4-5 | Mediocre — joke doesn't land or gap is too narrow |
| 1-3 | Doesn't work at all |

---

## Entries

### 1. Bear on Porch — BEST OF BATCH

| Field | Value |
|-------|-------|
| **Scenario** | A bear casually standing on a suburban porch, checking in like a neighbor |
| **Caption** | "he checks in every morning" |
| **Prompt** | Grok Imagine frame generation → Hailuo 02 img2vid animation |
| **Model** | Grok Imagine (frame) + Hailuo 02 (animation) |
| **Method** | img2vid |
| **Board Rating** | 10/10 — Best of batch |
| **WHY it was funny** | The bear's casual body language combined with an impossibly mundane caption. The AI rendered the bear with the "casualness of a FedEx driver" — no aggression, no drama, just a bear doing his rounds. The gap between a literal bear on your porch and "he checks in every morning" is enormous, and the AI's inability to make it look threatening actually amplified the joke. |
| **Patterns** | Synthetic Sincerity, Guy-ification, Absurd scenario + bored caption |

**Key takeaway:** The AI's natural tendency toward calm, slightly uncanny rendering is a *comedy asset*. The bear looked like he had somewhere to be. That's the joke.

---

### 2. Raccoon Faucet

| Field | Value |
|-------|-------|
| **Scenario** | A raccoon operating a kitchen faucet like it's the most normal thing in the world |
| **Caption** | "he figured out the faucet" |
| **Prompt** | Grok Imagine frame generation → Wan 2.2 14b img2vid animation |
| **Model** | Grok Imagine (frame) + Wan 2.2 14b (animation) |
| **Method** | img2vid |
| **Board Rating** | 8/10 |
| **WHY it was funny** | Obviously fake + mundane achievement. The raccoon is clearly AI-generated, but the caption treats this impossible scene as a minor household update. The AI water physics cooperated perfectly — the water looked just real enough to sell the scene but just wrong enough to add texture. |
| **Patterns** | Guy-ification, Mundane narration of impossible event |

**Key takeaway:** "He figured out the faucet" is peak noted. voice — it's exactly how you'd text your roommate. The AI jank in the water added to the comedy rather than detracting.

---

### 3. Pigeon Boardroom

| Field | Value |
|-------|-------|
| **Scenario** | Pigeons sitting around a corporate boardroom table |
| **Caption** | *(caption pointed at the joke — referenced pigeons directly)* |
| **Prompt** | Text-to-video prompt describing pigeons in a boardroom meeting |
| **Model** | Wan 2.2 5b |
| **Method** | text2vid |
| **Board Rating** | 6/10 — Decent but flawed |
| **WHY it didn't fully land** | The caption pointed at the joke. When the SCENE is already the joke (pigeons in a boardroom), the caption must NOT match it. Caption should have been about boring office politics — "quarterly projections are behind" or "he scheduled another sync" — not about pigeons. The scene does the comedy; the caption does the straight man. |
| **Patterns** | Violated: Caption must never acknowledge the absurdity |

**LESSON:** When the scene is absurd, the caption must be aggressively mundane. The gap is the joke. Pointing at the gap kills it.

---

### 4. Morning Walk

| Field | Value |
|-------|-------|
| **Scenario** | A normal morning walk scene |
| **Caption** | *(normal/wholesome caption)* |
| **Prompt** | Text-to-video prompt describing a morning walk |
| **Model** | Wan 2.2 5b |
| **Method** | text2vid |
| **Board Rating** | 4/10 — Too wholesome |
| **WHY it didn't work** | Normal scenario + normal caption = not enough gap. There's no comedy engine here. The formula requires at least one absurd element — either the visual or the situation — paired with deadpan narration. When both sides are normal, it's just... a video. |
| **Patterns** | Failed: No absurdity gap |

**LESSON:** The minimum viable joke requires: absurd scenario + bored caption. You can't get comedy from mundane + mundane. At least one element must be impossible.

---

### 5. Behind on Emails

| Field | Value |
|-------|-------|
| **Scenario** | An animal in a human work-from-home situation, overwhelmed by emails |
| **Caption** | *(promising concept, incomplete execution)* |
| **Prompt** | Grok Imagine frame generation → Wan 2.2 14b img2vid animation |
| **Model** | Grok Imagine (frame) + Wan 2.2 14b (animation) |
| **Method** | img2vid |
| **Board Rating** | Not yet rated — Incomplete |
| **WHY it's promising** | The concept is strong — relatable WFH frustration narrated over an animal at a desk. Hits the guy-ification sweet spot. Needs a full production pass to evaluate properly. |
| **Patterns** | Guy-ification, Relatable narration of impossible scene |

**LESSON:** Strong concept, but incomplete. Needs full production pass before final judgment. The idea of narrating an animal's "work stress" has high potential.

---

## Emerging Patterns

### What works

| Pattern | Evidence | Confidence |
|---------|----------|------------|
| **img2vid > text2vid** | Both top picks (Bear, Raccoon) used Grok Imagine frame + AI animation. Text2vid entries (Pigeon, Morning Walk) ranked lower. | High |
| **Animals in human situations > animals doing animal things** | Bear on a porch (human context) beats any clip of a bear doing bear things. The human framing IS the joke setup. | High |
| **AI rendering casualness = comedy asset** | The uncanny valley isn't a flaw — it's the punchline amplifier. The bear looked like a delivery driver. The raccoon's water physics were "close enough." | High |
| **Caption length inversely proportional to scene absurdity** | The more insane the visual, the shorter and more bored the caption should be. "he checks in every morning" = 5 words for a BEAR ON YOUR PORCH. | High |

### What doesn't work

| Anti-pattern | Evidence | Confidence |
|--------------|----------|------------|
| **Caption pointing at the joke** | Pigeon Boardroom — mentioning pigeons in the caption when the visual is pigeons killed the gap | High |
| **Normal scenario + normal caption** | Morning Walk — no absurdity gap means no comedy engine | High |
| **Text2vid for complex scenes** | Wan 2.2 5b text2vid produced lower-quality results than the img2vid pipeline | Medium |

### The Formula (so far)

```
COMEDY = (Scene Absurdity × Caption Mundaneness) × AI Jank Coefficient
```

- **Scene Absurdity**: How impossible/weird is what's happening? (Bear on porch = very high)
- **Caption Mundaneness**: How bored/casual is the narration? ("he checks in every morning" = maximum bored)
- **AI Jank Coefficient**: Does the AI rendering add uncanny texture? (Usually yes — this is a multiplier, not a penalty)

### Production Pipeline Ranking

| Pipeline | Quality | Best For |
|----------|---------|----------|
| Grok Imagine → Hailuo 02 img2vid | Highest (Bear) | Hero content, best-of-batch candidates |
| Grok Imagine → Wan 2.2 14b img2vid | High (Raccoon, Emails) | Strong B-tier, good for volume |
| Wan 2.2 5b text2vid | Medium (Pigeon, Walk) | Quick tests, concept validation only |

---

## Next Steps

- [ ] Complete production pass on "Behind on Emails"
- [ ] Test more scenarios with the Grok Imagine → Hailuo 02 pipeline (our top performer)
- [ ] Experiment with longer-form AI video (beyond Shorts length)
- [ ] Try the anti-pattern fix: re-do Pigeon Boardroom with a mundane corporate caption
- [ ] Test new animal-in-human-situation concepts

---

*Last updated: 2026-03-14*
*Batch: Initial R&D (5 test videos)*
