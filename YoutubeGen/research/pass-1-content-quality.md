# Pass 1: Content Quality Brainstorm

> How to make our YouTube Shorts consistently hit 90+ virality scores and 100k+ views.

**Date:** 2026-03-13
**Status:** CEO initial pass — awaiting Market Analyst & Copywriter input

---

## Executive Summary

Our pipeline scores 74–87/100 on the virality predictor. That's "good but not viral." The gap between 80 and 95 isn't incremental — it's a qualitative leap from "relatable observation" to "cultural artifact." This document outlines 14 concrete ideas to close that gap.

---

## 1. Caption Sharpening: From Relatable to Undeniable

### 1.1 The Specificity Ladder

**Problem:** Our best captions are still at the "general relatable" tier. "grocery prices turned me into a criminal" is good but not screenshot-worthy. Compare with real viral: "me buying a single bell pepper for $2.49 like im at a jewelry store" — the specificity IS the humor.

**Idea:** Add a **specificity injection pass** after initial caption generation. Take the generated caption and run it through a "make it more specific" prompt that:
- Replaces general nouns with specific ones ("groceries" → "a single avocado")
- Adds concrete dollar amounts, time stamps, or quantities
- Grounds abstract feelings in physical actions ("being tired" → "setting 14 alarms and sleeping through all of them")

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Low (prompt change only) | **P0 — do first** |

### 1.2 The "Group Chat Test" Filter

**Problem:** The virality predictor measures multiple dimensions but doesn't ask the one question that matters: "Would you screenshot this and send it to your group chat?"

**Idea:** Add a binary gate to the virality predictor: "group_chat_worthy: true/false" with the specific prompt: "Would a 27-year-old screenshot this exact pairing and send it to their friend with no additional context? If the friend needs explanation, it fails."

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Low | **P0** |

### 1.3 Caption Format Diversification

**Problem:** We have 4 format patterns (me_when, pov, when_you, observation). Real viral Shorts use many more structures.

**Idea:** Expand the caption format library with formats that consistently perform on Shorts:

- **"[thing] is just [devastating reframe]"** — "LinkedIn is just people lying to each other professionally" (1.3M views)
- **"they really just [absurd truth]"** — "they really let anyone be an adult huh" (2.4M views)
- **Fake instructions/guides** — "how to go grocery shopping in 2026: step 1: take out a loan"
- **Third person observation** — "the way she said 'im fine' with zero fine energy"
- **List/escalation** — "things i do instead of therapy: 1. this 2. that 3. concerning thing"
- **Conversational/quote** — "'how's the job search going' me:" 
- **Fake product/service** — "need a app that deposits serotonin directly into your brain"

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Low | **P0** |

### 1.4 Anti-Pattern Detection

**Problem:** The system sometimes generates captions that feel AI-written. Telltale signs: too grammatically correct, too balanced, hedging language, using words real people wouldn't use in memes.

**Idea:** Add a **cringe detector** prompt pass that flags:
- Words nobody uses in memes (utilize, despite, however, furthermore)
- Perfect grammar when the meme format expects lowercase no-punctuation
- Captions longer than 10 words (strict ceiling)
- Anything that reads like a LinkedIn post
- Exclamation points, emoji, "fr fr", or any tryhard markers

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Medium** | Low | **P1** |

---

## 2. Clip-Caption Pairing: From Matching to Metaphor

### 2.1 The "What's the Visual Punchline?" Framework

**Problem:** Our scene matcher sometimes picks clips that merely mood-match. Sad caption → sad clip = boring. The virality gap is in clips that CREATE meaning through juxtaposition.

**Idea:** Restructure the scene matching prompt to explicitly require the "punchline logic" — the LLM must explain the JOKE of the pairing, not just the mood match. Add a mandatory "the viewer laughs because..." field that must contain a specific ironic parallel, visual metaphor, or recontextualization.

Categories of clever pairings to train on:
- **Scale escalation:** Mundane problem → epic movie reaction (rent is due → Saving Private Ryan medic scene)
- **Ironic parallel:** Modern situation → historical/fictional equivalent (job interview → interrogation scene)
- **Character energy:** Using a character's ENERGY, not their situation (using Tony Montana's confidence for "me walking into Whole Foods with $12")
- **Dialogue double-meaning:** Scene where the dialogue literally applies to the caption topic

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium | **P0** |

### 2.2 Pre-Curated "Golden Clips" Library

**Problem:** The scene matcher suggests a scene, then we search YouTube and often get wrong/poor clips. The search→download→verify loop is brittle and slow.

**Idea:** Build a curated library of 200+ verified, high-quality clips tagged by emotion, energy, and visual metaphor potential. Categories:
- Epic overreaction clips (The Office Michael Scott "No God No", Darth Vader "NOOO")
- Resigned acceptance clips (Office Space "that'd be great", Walter White stare)
- Confusion/disbelief clips (confused Travolta, Pikachu face energy)
- Smug/unbothered clips (sunglasses on meme, "deal with it" energy)
- Escalation clips (everything's fine → chaos, "this is fine" adjacent)
- Physical comedy metaphors (pratfalls, battles, chase scenes used as metaphors)

If the scene matcher's suggested scene maps to a golden clip, skip the search entirely.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Very High** | High (curation work) | **P0** |

### 2.3 Reverse Engineering: Start from Clip, Generate Caption

**Problem:** We always go caption → clip. But sometimes the BEST pairings come from the opposite direction — you see a clip and think "this is SO [specific situation]."

**Idea:** Add an alternate pipeline mode:
1. Pick a random high-quality clip from the golden library
2. Ask the LLM: "You're looking at [clip description]. What trending topic/relatable situation would be DEVASTATINGLY funny with this clip as the visual?"
3. Generate captions backwards from the clip

This flips the creative process and may unlock pairings that caption-first never discovers.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium | **P1** |

---

## 3. Content Strategy: What Goes Viral vs. What Falls Flat

### 3.1 Topic Tier List

**Problem:** Not all topics are equally memeable. We're treating "rent prices" and "grocery shopping" equally, but some topics have much higher viral ceilings.

**Idea:** Create an empirical topic tier list based on actual Shorts performance data:

**S-Tier (consistently viral):**
- Financial anxiety (rent, groceries, bank account, being broke)
- Work/career absurdity (job interviews, bosses, meetings, LinkedIn)
- Dating/relationships in the app era
- The concept of being an adult / "adulting"
- AI/tech replacing humans

**A-Tier (often viral):**
- College/student debt
- Mental health through humor lens
- Social media behavior (posting/lurking dynamics)
- Generational differences (Boomer boss energy)

**B-Tier (sometimes viral):**
- Specific current events (elections, celebrity news)
- Seasonal (holidays, back to school)
- Regional humor (LA traffic, NYC rent, Florida)

**C-Tier (rarely viral in this format):**
- Abstract philosophy
- Niche hobbies
- Anything requiring specialized knowledge
- Political hot takes (too divisive)

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Medium** | Low (research task) | **P1** |

### 3.2 Creator Reverse-Engineering

**Problem:** We're generating in a vacuum. Real viral Shorts accounts have identifiable patterns we could study.

**Idea:** Study the top 10 accounts in this exact format and document:
- Their caption writing patterns (average word count, common structures)
- Which movie scenes they use most frequently
- Post frequency and timing
- Which topics they avoid
- Their thumbnail style
- Comment section patterns (what viewers say about the best ones)

**Candidate accounts to study:** @MovieReactionMemes, @CinemaCaption, accounts with 100k+ followers in the caption+clip format.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium (research task) | **P0 — delegate to Market Analyst** |

### 3.3 Trending Topic Enhancement via LLM

**Problem:** Our trend discovery pulls raw topics from Google Trends and Reddit. "grocery prices" is a valid topic but it's broad. The LLM needs more context to generate SPECIFIC, timely captions.

**Idea:** Add an "enrichment" step between trend discovery and caption generation:
1. Take raw topic ("grocery prices")
2. Ask LLM: "What SPECIFIC thing about grocery prices is everyone talking about RIGHT NOW? What's the most memeable angle? What specific products, price points, or situations are trending?"
3. Feed the enriched context ("eggs are $7 a dozen, people are comparing grocery receipts to car payments") into caption generation

This transforms vague topics into specific, timely comedic hooks.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Low | **P0** |

---

## 4. Humor Engineering: Understanding What's Actually Funny

### 4.1 The "Why People Actually Laugh" Framework

**Problem:** Our system prompt tells the LLM to be funny but doesn't break down the MECHANICS of why certain meme captions work.

**Idea:** Embed humor theory into the caption generator prompt:

- **Incongruity theory:** Humor = unexpected connection. The caption sets up an expectation, the clip subverts it.
- **Relief theory:** The caption says what you're NOT supposed to say. The laughter is the relief of someone else saying it.
- **Superiority theory:** Laughing at a shared experience means "we survived this together."

Practically, add to the system prompt:
- "The funniest captions contain a TWIST — the first half sets up one expectation, the second half subverts it"
- "Use the structure: [normal setup] + [absurd escalation]"  
- "The best comedy comes from treating a mundane problem with the gravity of a crisis, or treating a crisis with mundane casualness"

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Medium** | Low | **P1** |

### 4.2 Few-Shot Quality Upgrade

**Problem:** We seed 12 viral examples into the prompt. That's good but they're all the same tone. We need more diversity in our examples and specifically examples of PAIRINGS, not just captions.

**Idea:** Expand the few-shot bank to 30+ examples that include:
- The caption text
- The clip used
- WHY the pairing works (the visual metaphor explained)
- The view count
- The format category

Group them by pairing type so the LLM sees the full creative spectrum:
- Scale escalation examples
- Ironic parallel examples
- Dialogue double-meaning examples
- Character energy transfer examples

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium (research + curation) | **P0 — delegate to Copywriter** |

---

## Priority Summary

| Priority | Ideas | Expected Impact |
|----------|-------|----------------|
| **P0** | Specificity ladder, group chat test, format diversification, visual punchline framework, golden clips library, creator reverse-engineering, topic enrichment, few-shot upgrade | Move average from 80 → 90 |
| **P1** | Anti-pattern detection, reverse clip→caption mode, topic tier list, humor framework | Push ceiling from 87 → 95+ |

---

## Delegation

- **@Market Analyst:** Creator reverse-engineering (3.2), Topic tier list (3.1), Golden clips curation (2.2)
- **@Copywriter:** Few-shot quality upgrade (4.2), Caption format diversification (1.3), Specificity ladder prompt engineering (1.1)
- **@Asset Developer:** Technical feasibility review of golden clips library, reverse pipeline mode

---

*This document will be updated with team input. Next: Pass 2 — Technical & Pipeline Improvements.*
