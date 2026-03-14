# Pass 2: Technical & Pipeline Improvements Brainstorm

> Architecture, tooling, and system-level changes to make the pipeline faster, more reliable, and self-improving.

**Date:** 2026-03-13
**Status:** CEO initial pass — awaiting Asset Developer feasibility review

---

## Executive Summary

The pipeline works end-to-end but has critical bottlenecks: clip acquisition fails ~40% of the time, the virality predictor uses the same model family that generates content (self-evaluation bias), and there's no feedback loop from actual YouTube performance. This document covers 12 technical improvements across infrastructure, quality assurance, and analytics.

---

## 1. Clip Acquisition — The #1 Bottleneck

### 1.1 Pre-Curated Clip Library with Semantic Tagging

**Problem:** We search YouTube live for every clip. This is slow (30s+ per search), unreliable (clips get removed, search misses the right scene), and we waste verified clips because our cache key is `movieTitle + character` — too narrow.

**Current state:** SQLite cache with ~20 clips, keyed on exact movieTitle+character match. Cache hit rate is very low because LLM suggests slightly different movie titles or characters each time.

**Idea:** Build a **semantic clip library** with:

1. **Batch curation pipeline:** Separate CLI command (`npm run curate`) that:
   - Takes a list of 200 movie/TV scenes known to work in meme format
   - Downloads + trims + verifies all of them in advance
   - Tags each with: emotions[], energy_level, visual_metaphors[], recognizability_score, dialogue_keywords[]
   
2. **Fuzzy matching:** When the scene matcher suggests "The Office — Michael Scott screaming no", fuzzy-match against the library using embedding similarity rather than exact string match. A clip tagged `["frustration", "overreaction", "office"]` matches many different scene descriptions.

3. **Emotion-based fallback:** If no fuzzy match, pick the best clip matching the caption's mood from the library. A "defeated" caption gets a "defeated" clip even if it's not the specific movie suggested.

**Implementation sketch:**
```
clips_library/
  manifest.json         # metadata for all curated clips
  clips/
    office-michael-no.mp4
    breaking-bad-walt-stare.mp4
    ...
```

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Very High** | High (2-3 days for curation + matching logic) | **P0** |

### 1.2 Multi-Source Clip Search

**Problem:** We only search YouTube. Many great movie clips live elsewhere or require different search strategies.

**Idea:** Add alternative search strategies in priority order:

1. **YouTube search with multiple query formulations** — already partially done but can be smarter:
   - `"[movie title] [character] scene"` (current)
   - `"[movie title] [specific dialogue quote]"` (new — if the scene has iconic dialogue)
   - `"[movie title] best scenes compilation"` → download full compilation → use ffmpeg scene detection to find the right timestamp
   
2. **Giphy/Tenor search** — many iconic scenes exist as high-quality GIFs. Convert to MP4.

3. **Reddit clip harvesting** — r/MovieClips, r/HighQualityGifs often have exactly the scenes we need with direct video links.

4. **Scene timestamp databases** — IMDb, movie wiki pages often list exact timestamps for famous scenes. Download the full clip compilation and seek to the right time.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium | **P1** |

### 1.3 Intelligent Clip Trimming

**Problem:** When we download a video, we trim to a random segment of `clipMaxSec` (15s). This is wrong — we should trim to the MEANINGFUL part of the scene.

**Current code (clip-acquisition.ts:113-139):** `startTime = random within duration`. This means we often capture the wrong moment.

**Idea:** Use the `clipStartHint` and `clipEndHint` from the scene matcher to guide trimming:
1. Extract frames at regular intervals across the full video
2. Send to vision model: "Which frame shows [clipStartHint]? Which shows [clipEndHint]?"
3. Trim between those timestamps
4. If hints don't match, fall back to the "most visually interesting" segment (highest frame-to-frame difference = most action)

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium | **P1** |

---

## 2. Virality Prediction — Reducing Self-Evaluation Bias

### 2.1 Cross-Model Validation

**Problem:** Grok generates captions AND judges their virality. Same model family = same biases. It rates its own clever wordplay higher than a human would. This is why we score 80+ but may not actually be viral.

**Current state:** `grok-4.20-beta-latest-non-reasoning` for generation, same base for judging (via `CONFIG.llm.model`).

**Idea:** Use a DIFFERENT model for virality prediction:

| Role | Current | Proposed |
|------|---------|----------|
| Caption generation | Grok 4.20 | Keep Grok (creative strength) |
| Scene matching | Grok 4.20 | Keep Grok |
| Virality prediction | Grok 4.20 | **Claude or GPT-4o** (independent judge) |
| Clip verification | Grok 4 (vision) | Keep Grok vision |

The predictor should be a model that DIDN'T generate the content, so it judges genuinely rather than recognizing its own patterns.

**Implementation:** Add a `JUDGE_API_KEY` and `JUDGE_BASE_URL` config for a second model provider.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Low (config + API swap) | **P0** |

### 2.2 Calibration Dataset

**Problem:** Our virality predictor has no ground truth. It scores based on its own understanding of virality, uncalibrated against actual performance data.

**Idea:** Build a calibration dataset:
1. Collect 100 real viral Shorts in our format with their view counts
2. Run our virality predictor on each one
3. Compare predicted scores vs actual views
4. Identify systematic biases (does it overrate wordplay? Underrate visual metaphors?)
5. Add a calibration layer that adjusts raw scores based on known biases

This turns the predictor from "LLM opinion" into "calibrated LLM opinion."

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium (data collection) | **P1 — delegate data collection to Market Analyst** |

### 2.3 Human-in-the-Loop Quick Vote

**Problem:** Even with cross-model validation, LLMs don't fully understand human humor. A 5-second human thumbs-up/down would dramatically improve quality.

**Idea:** Optional `--review` flag that:
1. Generates the short as normal
2. Plays a 5-second preview (caption + clip thumbnail)
3. Board member votes: ship / skip / regenerate
4. Logged to a feedback.json that trains future scoring calibration

Not for every run — just for high-stakes batch generations or when tuning the pipeline.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Medium** | Low | **P2** |

---

## 3. Audio Analysis — Untapped Dimension

### 3.1 Dialogue-Aware Scene Matching

**Problem:** We verify clips visually (frame extraction → vision model) but many iconic movie scenes are iconic because of DIALOGUE, not visuals. A scene of someone talking in a car might look generic in frames but the dialogue is legendary.

**Idea:** Extract audio from candidate clips and analyze:
1. `ffmpeg` extract audio → `whisper` (or similar) transcribe
2. Feed transcript to the pairing evaluator alongside visual frames
3. Bonus points if the dialogue creates a DOUBLE MEANING with the caption

Example: Caption "me explaining why i deserve a raise" + clip from A Few Good Men where Jack Nicholson screams "YOU CAN'T HANDLE THE TRUTH!" — the dialogue IS the joke, visual frames alone miss this.

**Implementation:** Use OpenAI Whisper API or local whisper.cpp for transcription. Add transcript to the verifier prompt.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium | **P1** |

### 3.2 Background Music / Sound Design

**Problem:** Our Shorts are raw movie audio. Top-performing Shorts in this format often have trending audio layered under the clip — a specific TikTok sound, a bass-boosted beat drop, or ironic elevator music.

**Idea:** Add optional audio overlay capabilities:
1. Library of royalty-free "meme sounds" (sad violin, bruh sound effect, vine boom, etc.)
2. LLM selects which sound matches the caption's mood
3. Mix at low volume under the clip audio

This is lower priority — visual + caption is the core format — but audio could push views 20-30% higher.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Medium** | Medium | **P2** |

---

## 4. Thumbnail Optimization

### 4.1 Thumbnail A/B Generation

**Problem:** Current thumbnails extract a single frame and overlay text. No optimization for what makes people CLICK.

**Idea:** Generate 3 thumbnail variants per short:
1. **High contrast frame** — the most visually dramatic frame from the clip (highest color variance)
2. **Facial expression frame** — the frame with the most exaggerated facial expression (via face detection heuristic: largest face area + highest contrast)
3. **Context-stripped frame** — crop to just the reaction (remove background, focus on face/action)

Add text overlay optimization:
- Truncate caption to 5 words max for thumbnail
- Use high-contrast text (white with black outline)
- Position text to not cover faces

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Medium** | Medium | **P1** |

---

## 5. Analytics Feedback Loop

### 5.1 Post-Upload Performance Tracking

**Problem:** We generate → upload → forget. No feedback loop. We don't know which of our Shorts actually performed well.

**Current state:** Upload log tracks videoId, status, timestamps. No view/engagement data.

**Idea:** Add a `npm run analytics` command that:
1. Calls YouTube Data API for each uploaded video
2. Pulls: views, likes, comments, average view duration, click-through rate
3. Stores in the upload log
4. Generates a report: "Your top 5 Shorts by views, your worst 5, patterns"

This data becomes the ground truth for calibrating the virality predictor (see 2.2).

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Low (YouTube API already integrated) | **P0** |

### 5.2 Automated Learning from Performance

**Problem:** Even with analytics, we need to LEARN from them, not just report.

**Idea:** After accumulating 50+ Shorts with performance data:
1. Cluster by virality score vs actual views
2. Identify which predictor dimensions (caption_score, pairing_cleverness, etc.) best correlate with real views
3. Re-weight the scoring formula based on empirical data
4. Feed top-performing captions back into the few-shot examples (they're PROVEN viral, not assumed)

This creates a flywheel: generate → upload → measure → learn → generate better.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Very High** | Medium (needs 50+ data points first) | **P1** (blocked on data accumulation) |

---

## 6. Pipeline Performance & Reliability

### 6.1 Parallel Caption + Scene Generation

**Problem:** Current pipeline is strictly sequential: trends → captions → scene match → clip → composite. Each short takes 2-5 minutes.

**Idea:** Generate multiple caption+scene pairings in PARALLEL, then clip-acquire in parallel (with rate limiting):
1. Generate 50 captions (already batched)
2. Run `selectBestPairing` on groups of 10 in parallel (5 concurrent evaluations)
3. Start clip acquisition for the top 3 pairings simultaneously
4. First one that passes verification wins

Expected speedup: 3-5x for the quality loop.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Medium** | Medium | **P2** |

### 6.2 Graceful Degradation & Retry Budget

**Problem:** If clip acquisition fails 3 times (`MAX_ATTEMPTS = 3` in clip-acquisition.ts), we throw and lose all the creative work (caption, scene match, virality score). 

**Idea:** Decouple clip acquisition failure from pipeline failure:
1. If the intended clip can't be found, try the golden clips library (1.1)
2. If no good match, queue the caption+scene for "manual clip assignment" instead of throwing
3. Save partial results: `output/drafts/` with caption+scene+viralityScore but no clip
4. `npm run assemble --draft <id>` to manually attach a clip later

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **Medium** | Low | **P1** |

### 6.3 A/B Variant Generation

**Problem:** We produce one Short per topic. We should produce VARIANTS and let YouTube decide which works.

**Idea:** `--variants 3` flag that produces 3 versions of the same topic:
- Same topic, different captions
- Same caption, different clips
- Or different everything

Upload all 3 as separate Shorts. After 48 hours, the analytics command identifies the winner. Delete the losers (or keep them unlisted).

This is how real content creators optimize — volume + measurement, not perfection on first try.

| Impact | Difficulty | Priority |
|--------|-----------|----------|
| **High** | Medium | **P1** |

---

## Priority Summary

| Priority | Ideas | Expected Impact |
|----------|-------|----------------|
| **P0** | Clip library (1.1), cross-model judge (2.1), analytics tracking (5.1) | Fix #1 bottleneck, remove bias, enable learning |
| **P1** | Multi-source search (1.2), intelligent trimming (1.3), calibration dataset (2.2), dialogue-aware matching (3.1), thumbnails (4.1), automated learning (5.2), graceful degradation (6.2), A/B variants (6.3) | Systematic quality improvements |
| **P2** | Human review (2.3), sound design (3.2), parallel pipeline (6.1) | Nice-to-haves after core improvements |

---

## Delegation

- **@Asset Developer:** Clip library architecture (1.1), multi-source search (1.2), intelligent trimming (1.3), parallel pipeline (6.1), graceful degradation (6.2)
- **@Market Analyst:** Calibration dataset collection (2.2), analytics setup (5.1)
- **@Copywriter:** Dialogue-aware scene examples for 3.1

---

## Combined Priority Roadmap (Pass 1 + Pass 2)

### Sprint 1 (This Week) — Biggest Bang for Buck
1. **Specificity injection pass** (Pass 1, 1.1) — prompt change, ship in hours
2. **Group chat test filter** (Pass 1, 1.2) — add to virality predictor prompt
3. **Caption format diversification** (Pass 1, 1.3) — expand system prompt
4. **Topic enrichment** (Pass 1, 3.3) — add enrichment step
5. **Cross-model virality judge** (Pass 2, 2.1) — swap predictor to different model
6. **Analytics tracking** (Pass 2, 5.1) — YouTube API pull for uploaded videos

### Sprint 2 (Next Week) — Infrastructure
7. **Golden clips library** (Pass 2, 1.1 + Pass 1, 2.2) — batch curation pipeline
8. **Visual punchline framework** (Pass 1, 2.1) — restructure scene matcher prompt
9. **Few-shot upgrade** (Pass 1, 4.2) — 30+ captioned+paired viral examples
10. **Creator reverse-engineering** (Pass 1, 3.2) — research task

### Sprint 3 (Following Week) — Advanced
11. **Dialogue-aware matching** (Pass 2, 3.1) — audio transcription integration
12. **Calibration dataset** (Pass 2, 2.2) — score real viral shorts
13. **A/B variant generation** (Pass 2, 6.3) — multi-variant pipeline
14. **Reverse clip→caption mode** (Pass 1, 2.3) — alternate creative flow

---

*Awaiting team input before finalizing sprint assignments.*
