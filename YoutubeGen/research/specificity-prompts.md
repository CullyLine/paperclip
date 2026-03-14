# Specificity Injection Prompt Templates

> Prompt engineering for the specificity pass in the YoutubeGen caption pipeline.
> Addresses Pass 1, Section 1.1: replacing generic captions with screenshot-worthy specifics.

---

## The Core Principle

The difference between a 74-score caption and a 95-score caption is almost always specificity.

> **Generic:** "grocery prices turned me into a criminal"
> **Specific:** "me buying a single bell pepper for $2.49 like i'm at a jewelry store"

The specific version is funnier because:
1. "$2.49" is a real number (not vague "expensive")
2. "single bell pepper" is a precise, almost absurd unit
3. "jewelry store" is the exact right comparison (precious, hushed, small quantities)

Specificity IS the joke. The generic version describes the feeling; the specific version creates the image.

---

## Prompt Template A: Full Specificity Injection Pass

Use this after initial caption generation. Feed the generated caption as `{CAPTION}` and the topic as `{TOPIC}`.

```
SPECIFICITY INJECTION PASS

You are a viral meme caption editor. Your job is to make a caption MORE specific without making it longer.

ORIGINAL CAPTION: {CAPTION}
TOPIC: {TOPIC}

Apply these rules in order:

1. REPLACE GENERAL NOUNS with specific ones
   - "groceries" → "a single avocado" or "eggs" or "cereal that costs $8"
   - "expensive" → "$4.79" or "$2.49" or "more than my hourly wage"
   - "tired" → "setting 14 alarms and sleeping through all of them"
   - "stressed" → "jaw clenched since Tuesday"
   - "broke" → "$47 in checking" or "declined at Chipotle"

2. ADD CONCRETE QUANTITIES, PRICES, OR TIMESTAMPS where they fit naturally
   - Not all captions need numbers — only add if it genuinely increases the comedy
   - Good: "$47" instead of "not much money"
   - Bad: "3.7 out of 5 stars" (too precise, reads as calculated)

3. GROUND ABSTRACT FEELINGS in physical, observable actions
   - "being anxious" → "refreshing my email 40 times"
   - "being disappointed" → "staring at the ceiling at 2am"
   - "enjoying yourself" → "cancelling plans to lie down and look at my phone"

4. REPLACE VAGUE COMPARISONS with specific ones
   - "like a rich person" → "like I'm at a farmers market in Malibu"
   - "like it's serious" → "like I'm testifying before Congress"
   - "carefully" → "like a bomb technician"

5. LENGTH CHECK: Output must be no longer than the input. If you added specificity, cut something else. 10 words maximum.

Output ONLY the revised caption. No explanation. No alternatives. One line.
```

---

## Prompt Template B: Specificity Audit (Binary Gate)

Use this as a quality gate to flag captions that NEED a specificity pass.

```
SPECIFICITY AUDIT

Caption: {CAPTION}

Answer YES or NO to each:
1. Does this caption contain at least one specific noun (not "food", "money", "work" — a precise version)?
2. Does this contain at least one concrete detail (a number, a brand, a specific place, a time)?
3. Would this caption work as a visual image WITHOUT the clip? (Specific = yes. Generic = no.)

Score: [count of YES answers]

0-1: NEEDS SPECIFICITY PASS — route to Prompt Template A
2: ACCEPTABLE — proceed with caution
3: SPECIFIC ENOUGH — proceed

Return ONLY the score (0, 1, 2, or 3) and the routing decision.
```

---

## Prompt Template C: Specificity by Category

Targeted specificity injection for each S-Tier topic. Use when the topic is known.

```
CATEGORY-SPECIFIC SPECIFICITY PASS

Topic category: {CATEGORY}
Original caption: {CAPTION}

Apply the category substitution rules below, then return the revised caption:

FINANCIAL ANXIETY:
- "expensive" → "$[plausible specific price]" (e.g., $4.79, $11, $340)
- "broke" → "$[small amount] in my [account type]" (e.g., $23 in checking)
- "groceries" → specific item (avocado, eggs, bell pepper, cheese)
- "bills" → specific bill (rent, electric, Spotify they forgot to cancel)

WORK/CAREER:
- "bad meeting" → "45-minute meeting that could have been a Slack message"
- "my boss" → "my manager who cc's their manager on everything"
- "working late" → "answering emails at 11:47pm"
- "job hunting" → "applying to 'entry level' jobs requiring 5 years experience"

DATING/RELATIONSHIPS:
- "texting" → specific behavior ("left on read for 3 hours then sent a meme")
- "ghosted" → "watched my story then never responded"
- "going on a date" → the specific platform ("we matched on [app] in 2024 and finally met")
- "relationship problems" → specific observable behavior

ADULTING:
- "doing adult things" → specific task ("making a dentist appointment and actually going")
- "responsibilities" → "renewing my registration / filing my taxes / calling my insurance"
- "being tired" → "setting 7 alarms and sleeping through all of them"
- "self care" → "lying on the floor of my bathroom for 20 minutes"

Return ONLY the revised caption. One line.
```

---

## Before/After Examples

These 10 pairs demonstrate the transformation. Use for training data or system prompt injection.

---

**Example 1 — Financial Anxiety**
- **Before:** `me checking my account after the weekend`
- **After:** `me checking my account and finding $23 and a pending charge i don't recognize`
- **What changed:** "$23" makes the number real; "pending charge i don't recognize" adds a second punch of dread.

---

**Example 2 — Grocery Prices**
- **Before:** `grocery prices are getting out of hand`
- **After:** `buying a single bell pepper for $2.49 like i'm at a jewelry store`
- **What changed:** Single specific item, specific price, specific comparison. Classic specificity transformation.

---

**Example 3 — Job Hunting**
- **Before:** `job hunting is so exhausting`
- **After:** `applying to entry level jobs that want 5 years experience and a master's degree`
- **What changed:** Named the specific absurdity (contradictory requirements) instead of describing the feeling.

---

**Example 4 — Being Tired**
- **Before:** `when you're so tired in the morning`
- **After:** `setting 9 alarms between 6 and 7:15am and sleeping through all of them`
- **What changed:** Specific number (9), specific time range (6-7:15am), specific behavior (sleeping through all of them).

---

**Example 5 — Self Care Failure**
- **Before:** `me trying to practice self care`
- **After:** `my self care routine: lie on the bathroom floor for 25 minutes and then order food`
- **What changed:** "25 minutes" makes it measurable and therefore absurd; "order food" is the specific self-destructive pivot.

---

**Example 6 — Social Media**
- **Before:** `being addicted to my phone`
- **After:** `refreshing instagram every 4 minutes hoping something changed`
- **What changed:** "4 minutes" (short enough to be compulsive, specific enough to be real), "hoping something changed" grounds the abstract addiction in the actual behavior.

---

**Example 7 — Work Meetings**
- **Before:** `having too many meetings`
- **After:** `a 45-minute call that was just 4 people agreeing to have another call`
- **What changed:** Specific duration (45 minutes), specific participant count (4 people), the punchline IS the specific outcome.

---

**Example 8 — Anxiety**
- **Before:** `when you have anxiety about something small`
- **After:** `spending 3 days dreading a 2-minute phone call`
- **What changed:** Opposing specific durations (3 days vs 2 minutes) creates the comedic contrast through numbers alone.

---

**Example 9 — Adulting Wins**
- **Before:** `when you do something responsible`
- **After:** `made a dentist appointment AND actually went. this is what thriving looks like`
- **What changed:** Specific task (dentist), the compound beat (making it AND going), the self-awarded "thriving" reframe.

---

**Example 10 — Dating Apps**
- **Before:** `modern dating is weird`
- **After:** `we matched in october, texted for 2 weeks, and never spoke again. it was a whole relationship`
- **What changed:** Specific month, specific duration, the "whole relationship" reframe elevates the absurdity with no extra words.

---

## Pipeline Integration

```
Caption Generation
       ↓
Specificity Audit (Template B)
       ↓
Score 0-1? → Specificity Injection (Template A or C)
       ↓
Score 2-3? → Proceed to virality scoring
       ↓
Final caption output
```

**Recommended:** Run ALL captions through the specificity pass regardless of audit score. The injection pass with a high-scoring caption will either improve it or leave it unchanged. The cost of the extra pass is minimal; the upside is real.

---

## Specificity Anti-Patterns

These patterns feel specific but aren't — avoid them:

| Fake Specificity | Why It Fails | Better Version |
|-----------------|-------------|----------------|
| "a lot of money" | Relative, no image | "$340" or "rent money" |
| "really tired" | Adverb intensifier, not specific | "slept through 7 alarms" |
| "very expensive" | Same | "$11 for a juice" |
| "some kind of" | Distancing language | Name the actual thing |
| "often" / "sometimes" | Frequency without image | "every Sunday night" |
| "things" | Category without content | Name 1-2 actual things |
| "feelings" | Abstract | Name the physical sensation |
| Numbers that end in 0 | Round numbers feel estimated | Prefer $47, $2.49, 14 alarms over $50, $2, 10 alarms |
