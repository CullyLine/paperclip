# Technical Feasibility Review

> Assessment of three proposed pipeline improvements from Pass 2 brainstorm.

**Author:** Asset Developer
**Date:** 2026-03-13
**Source:** `research/pass-2-technical-pipeline.md` sections 1.1, 2.1, 1.3

---

## 1. Clip Library Architecture (Pass 2, §1.1)

### Current State

`clip-acquisition.ts` uses a SQLite cache keyed on exact `movieTitle + character` match. The cache hit rate is poor because the LLM generates slightly different titles/names each run. Clips are searched live on YouTube via `yt-dlp`, which takes 30s+ per attempt and fails ~40% of the time.

### Semantic Tagging — Recommended Approach: **Hybrid (keyword tags + embedding fallback)**

Pure embedding-based matching (e.g. OpenAI `text-embedding-3-small`) gives excellent fuzzy recall but adds API latency and cost on every clip lookup. Pure keyword tags are fast but fragile — the same problems we have now with exact string matching, just slightly broader.

**Recommended hybrid flow:**

1. **Tag each clip with structured fields** at curation time: `emotions: string[]`, `energy: "low"|"medium"|"high"`, `visual_metaphors: string[]`, `recognizability: 1-10`, `keywords: string[]`, `dialogue_keywords: string[]`, `source_title: string`, `characters: string[]`
2. **First-pass match:** keyword overlap between scene matcher output and clip tags (fast, local, no API call). Score = weighted Jaccard similarity across fields.
3. **Second-pass match (if no good keyword hit):** generate a single embedding for the scene description and compare against pre-computed clip embeddings stored in the manifest. Use cosine similarity with a threshold of ~0.75.
4. **Emotion fallback (if neither passes):** pick the highest-rated clip matching the caption's primary mood.

Embedding pre-computation is a one-time cost at curation time — ~$0.001 per clip for `text-embedding-3-small`. Runtime lookups only hit the embedding API when keyword matching fails (expected <20% of cases once the library has 200+ clips).

### Storage Format & Manifest

```
clips_library/
  manifest.json          # array of clip metadata objects
  embeddings.json        # pre-computed embedding vectors (separate file to keep manifest readable)
  clips/
    001-office-michael-no.mp4
    002-breaking-bad-walt-stare.mp4
    ...
```

**manifest.json entry:**
```json
{
  "id": "001",
  "filename": "001-office-michael-no.mp4",
  "sourceTitle": "The Office",
  "character": "Michael Scott",
  "momentDescription": "Michael screaming NO after Toby returns",
  "emotions": ["frustration", "overreaction", "disbelief"],
  "energy": "high",
  "visualMetaphors": ["dramatic reaction", "workplace rage"],
  "recognizability": 9,
  "keywords": ["office", "michael", "no", "scream", "toby"],
  "dialogueKeywords": ["no", "god", "please"],
  "durationSec": 8.2,
  "verifyScore": 9
}
```

### Integration with `clip-acquisition.ts`

**Yes — library should be checked BEFORE YouTube search.** Proposed flow:

1. Check curated library (hybrid match) → if score > threshold, use it
2. Check existing SQLite cache (current exact-match logic) → if hit with verifyScore ≥ 6, use it
3. Fall through to live YouTube search (current behavior)

This makes YouTube search the last resort, which is exactly what we want given its 40% failure rate.

### Curation Pipeline Effort

| Component | Effort |
|-----------|--------|
| `npm run curate` CLI that takes a scene list JSON and batch-downloads via yt-dlp | 3-4 hours |
| Auto-tagging via vision model (extract 4 frames → ask LLM to tag emotions/metaphors) | 2-3 hours |
| Manifest generation + embedding pre-computation | 1-2 hours |
| Hybrid matching logic in clip-acquisition.ts | 3-4 hours |
| Seeding the initial 200-scene list (need Market Analyst input) | 4-6 hours (mostly research) |
| **Total** | **~2–3 days** |

### Concerns

- **Storage size:** 200 clips × ~5MB average = ~1GB. Manageable for local storage. Could add a `--clip-quality low` flag to compress further.
- **Copyright:** Same risk as current YouTube downloads. These clips are used in transformative commentary format (caption overlay), which has reasonable fair-use standing for short clips. No change in legal posture from current approach.
- **Clip quality:** The curation pipeline should enforce minimum resolution (480p+) and reject clips with watermarks or hard-coded subtitles. The vision model already handles this during verification — reuse the same verifier during curation.

### Verdict: **Feasible — recommend as P0**

The hybrid approach balances speed, accuracy, and cost. The biggest effort item is seeding the scene list — delegate to Market Analyst who already curated `research/reaction-scenes.md`.

---

## 2. Cross-Model Judging (Pass 2, §2.1)

### Current State

`virality-predictor.ts` uses the same Grok model (`grok-4.20-beta-latest-non-reasoning` via `CONFIG.llm.model`) and same xAI API credentials (`CONFIG.xaiApiKey` / `CONFIG.llm.baseUrl`) that generate captions. This creates a self-evaluation loop: Grok scores its own creative output.

### Config Changes Needed

Minimal. Add to `config.ts`:

```typescript
judge: {
  apiKey: process.env.JUDGE_API_KEY || '',
  baseUrl: process.env.JUDGE_BASE_URL || 'https://api.anthropic.com/v1',
  model: process.env.JUDGE_MODEL || 'claude-sonnet-4-20250514',
},
```

Then in `virality-predictor.ts`, swap the OpenAI client initialization:

```typescript
// Current
const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });

// Proposed
const judge = new OpenAI({
  apiKey: CONFIG.judge.apiKey || CONFIG.xaiApiKey,
  baseURL: CONFIG.judge.baseUrl || CONFIG.llm.baseUrl,
});
// Use CONFIG.judge.model instead of CONFIG.llm.model
```

Fall back to Grok if no judge key is configured, so the pipeline doesn't break for existing users.

### Prompt Adjustments

The current `PREDICT_PROMPT` is model-agnostic — it doesn't reference Grok or use any Grok-specific syntax. It works as-is with Claude, GPT-4o, or Gemini. No changes needed.

One recommendation: add a brief calibration note for the judge model:

```
You are an INDEPENDENT judge. You did NOT generate this content.
Score based purely on whether a human viewer would engage with it.
```

This nudge helps models that might otherwise be generous out of politeness (a known Claude tendency).

### Recommended Model

**Claude Sonnet 4** (via Anthropic API or OpenRouter).

| Factor | Claude Sonnet 4 | GPT-4o | Gemini 2.5 Flash |
|--------|-----------------|--------|---------------------|
| Honesty/calibration | Excellent — known for being direct, avoids sycophancy | Good | Good |
| Cost per call | ~$0.003-0.009 per judgment | ~$0.005-0.015 | ~$0.001-0.003 |
| Latency | 1-3s | 1-2s | <1s |
| JSON output support | Yes (via tool use or direct) | Yes (native) | Yes |
| OpenAI SDK compatible | Yes (via base URL swap) | Yes | Yes (via OpenRouter) |

Claude Sonnet 4 is the best fit for honest judgment — it's calibrated to avoid flattery, which is exactly what we need. GPT-4o is a solid alternative. Gemini is cheapest but less reliable on nuanced humor evaluation.

If using Claude via the Anthropic API directly, note that the OpenAI SDK compatibility layer works at `https://api.anthropic.com/v1` — no code changes needed beyond config.

**Alternative: OpenRouter** — single API key, access to all models. Set `JUDGE_BASE_URL=https://openrouter.ai/api/v1` and use any model string. This gives flexibility to A/B test judges.

### Estimated Effort

| Component | Effort |
|-----------|--------|
| Add judge config to `config.ts` | 15 min |
| Swap client in `virality-predictor.ts` with fallback | 30 min |
| Add `JUDGE_API_KEY` / `JUDGE_BASE_URL` / `JUDGE_MODEL` to `.env.example` | 5 min |
| Test with Claude Sonnet and compare scores | 1 hour |
| **Total** | **~2 hours** |

### Verdict: **Trivially feasible — recommend as immediate P0**

This is the highest-value, lowest-effort improvement on the list. A config addition and a 3-line code change in the predictor. No architectural changes needed.

---

## 3. Intelligent Trimming (Pass 2, §1.3)

### Current State

`clip-acquisition.ts:113-139` trims clips using a random start time:

```typescript
const startTime = duration > maxDuration
  ? Math.floor(Math.random() * (duration - maxDuration))
  : 0;
```

This means for a 60-second YouTube clip trimmed to 15 seconds, we pick a random 15-second window. We have a 1-in-4 chance of landing on the meaningful part. The `SceneMatch` type already includes `clipStartHint` and `clipEndHint` strings from the scene matcher, but they are completely unused in trimming.

### Option A: Vision Model Timestamp Finding

**How it would work:**
1. Extract frames every 2 seconds across the full downloaded video (e.g., a 60s clip → 30 frames)
2. Send all 30 frames to the vision model with the prompt: "Which frame number best shows [clipStartHint]? Which shows [clipEndHint]?"
3. Use the identified timestamps to calculate trim boundaries

**Cost analysis:**
- 30 frames per clip × ~$0.002 per image token = ~$0.06 per clip for vision analysis
- With 3 clip attempts per Short on average = ~$0.18 per Short for trimming intelligence
- Current pipeline cost per Short is ~$0.15-0.30 (caption gen + scene match + verify), so this roughly doubles the per-Short cost

**Feasibility:** Works well when the LLM's scene description maps clearly to visual frames. Less reliable when:
- The hint is about dialogue ("the part where he says 'I am the one who knocks'") — frames look the same before and after
- The clip is low-quality or has many similar-looking frames
- Multiple scenes match the hint

### Option B: FFmpeg Scene Change Detection (Recommended)

**How it would work:**
1. Run ffmpeg scene detection: `ffmpeg -i input.mp4 -filter:v "select='gt(scene,0.3)'" -vsync vfr -f null -` to find timestamps with major visual transitions
2. Score each segment between transitions for "visual interest" (frame-to-frame difference, face detection, motion level)
3. Select the segment with the highest score as the trim window

**Implementation:**
```bash
ffmpeg -i input.mp4 -filter:v "select='gt(scene,0.3)',showinfo" -f null - 2>&1
```
Parse the output for `pts_time` values to get scene change timestamps.

**Cost:** Zero API cost — pure local ffmpeg computation. Adds ~2-3 seconds of processing per clip.

**Limitations:** Finds the "most visually dynamic" segment, not necessarily the semantically correct one. For reaction clips this works well (reactions are visually dramatic), but it might pick an action scene over a quiet meaningful dialogue scene.

### Recommended Approach: **Layered strategy**

1. **If `clipStartHint`/`clipEndHint` are specific enough** (not just "beginning" / "end"): use a lightweight vision check — extract 8 frames evenly spaced, send to vision model with the hint, get the best timestamp range. Cost: ~$0.02 per check (8 frames instead of 30).
2. **Otherwise:** use ffmpeg scene detection to find the most visually interesting segment.
3. **Fallback:** current random trimming (never worse than today).

### Estimated Effort

| Component | Effort |
|-----------|--------|
| FFmpeg scene detection wrapper function | 2-3 hours |
| Scoring function for segment "interestingness" | 1-2 hours |
| Optional vision-based hint matching (8-frame version) | 2-3 hours |
| Integration into `trimClip()` with layered fallback | 1-2 hours |
| Testing across different clip types | 2 hours |
| **Total** | **~1–1.5 days** |

### Verdict: **Feasible — recommend layered approach as P1**

Scene detection is free and effective for most reaction clips. Vision-based hint matching is a higher-cost enhancement that should be optional (enabled via config flag). The layered strategy gives the best quality-to-cost ratio.

---

## Summary

| Feature | Feasibility | Effort | Priority | Blockers |
|---------|------------|--------|----------|----------|
| Clip Library (hybrid matching) | High | 2-3 days | **P0** | Need 200-scene seed list from Market Analyst |
| Cross-Model Judging | Trivial | 2 hours | **P0** | Need `JUDGE_API_KEY` credential |
| Intelligent Trimming | High | 1-1.5 days | **P1** | None |

**Recommended execution order:**
1. Cross-model judging (2 hours, immediate quality improvement)
2. Intelligent trimming with ffmpeg scene detection (1 day, no API cost)
3. Clip library with hybrid matching (2-3 days, requires scene list prep)
