import OpenAI from 'openai';
import { CONFIG } from './config';
import type { Caption, SceneMatch } from './types';

const PREDICT_PROMPT = `You are a ruthless YouTube Shorts virality analyst. You have studied thousands of viral caption+movie clip Shorts and know EXACTLY what separates a 500-view flop from a 100k+ banger.

The format: black bar on top with white text caption, movie clip playing underneath. The humor comes from the CLEVER connection between the two.

## What makes a Short go VIRAL (100k+ views):

1. **INSTANT RECOGNITION** — the viewer immediately gets the joke within 1-2 seconds. No explanation needed.
2. **SHAREABILITY** — it triggers the "I NEED to send this to someone" reflex. The viewer tags friends, screenshots it, reposts it.
3. **SPECIFICITY** — generic observations die. Surgical, specific takes about EXACTLY what the target audience (25-30 year old zoomers) is experiencing RIGHT NOW go viral.
4. **THE PAIRING IS THE PUNCHLINE** — the caption alone is relatable, but the movie clip RECONTEXTUALIZES it into comedy gold. The clip IS the punchline. Without the clip, the caption is just a thought. WITH the clip, it's art.
5. **REWATCHABILITY** — people watch it 3-4 times and show their friends. The cleverness of the pairing rewards repeat viewing.
6. **CULTURAL MOMENT** — it captures something everyone is feeling but nobody has articulated this perfectly yet.
7. **COMMENT BAIT** — it makes people want to comment "💀", "this is too accurate", "why is this literally me", "the clip choice is CRAZY"

## What KILLS virality:

- Generic/vague captions ("life is hard" energy)
- Obvious clip choices (sad caption → sad scene = boring)
- Clips nobody recognizes
- The connection requires explanation
- Too try-hard or forced
- Punching down or being genuinely mean
- Caption is too long to read in time

## Calibration — real viral captions (use these as your 80-90 score benchmark):

- "me at work pretending i care" (4.2M views) — 85/100
- "pov: you check your bank account after the weekend" (4.7M views) — 88/100
- "when the interviewer asks where you see yourself in 5 years" (3.2M views) — 82/100
- "being an adult is just saying its fine while nothing is fine" (2.8M views) — 84/100
- "they really let anyone be an adult huh" (2.4M views) — 80/100

Only give 90+ if the pairing is genuinely screenshot-worthy genius. 95+ should be reserved for once-in-a-hundred concepts where the visual metaphor is so perfect it transcends the format.

## Your Job

Score this Short concept on 6 dimensions (each 1-10), then give an overall VIRALITY SCORE (1-100) representing probability of hitting 100k views.

## Output Format

Return JSON:
- "caption_score": number (1-10) — is the caption sharp, specific, and relatable?
- "pairing_cleverness": number (1-10) — how clever is the caption+clip combination?
- "shareability": number (1-10) — would viewers tag friends / repost?
- "recognition": number (1-10) — will the audience instantly get it?
- "cultural_timing": number (1-10) — does this feel relevant RIGHT NOW?
- "rewatch_factor": number (1-10) — will people watch it multiple times?
- "virality_score": number (1-100) — overall probability of hitting 100k views
- "verdict": "ship_it" | "try_again" | "almost" — ship_it means confident banger, almost means close but not quite, try_again means start over
- "reasoning": string — 2-3 sentences explaining the score. Be BRUTALLY honest.
- "improvement_hint": string — if not shipping, what specifically would make it better?`;

export interface ViralityResult {
  captionScore: number;
  pairingCleverness: number;
  shareability: number;
  recognition: number;
  culturalTiming: number;
  rewatchFactor: number;
  viralityScore: number;
  verdict: 'ship_it' | 'try_again' | 'almost';
  reasoning: string;
  improvementHint: string;
}

export async function predictVirality(
  caption: Caption,
  scene: SceneMatch,
  clipVerifyScore: number,
): Promise<ViralityResult> {
  console.log(`[Virality] Predicting virality for: "${caption.text.slice(0, 50)}..."`);

  if (!CONFIG.xaiApiKey) {
    console.warn('[Virality] No API key, auto-shipping');
    return getDefaultResult('ship_it', 75);
  }

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });

  const input = [
    `Caption: "${caption.text}"`,
    `Mood: ${caption.mood}`,
    `Format: ${caption.format}`,
    ``,
    `Movie/Show: ${scene.movieTitle} (${scene.year})`,
    `Character: ${scene.character}`,
    `Scene: ${scene.momentDescription}`,
    `Why it's clever: ${scene.emotionalMatch}`,
    ``,
    `Clip verification score: ${clipVerifyScore}/10 (how well the actual downloaded clip matches the intended scene)`,
    `Scene-match confidence: ${scene.confidence}`,
  ].join('\n');

  try {
    const response = await grok.chat.completions.create({
      model: CONFIG.llm.model,
      max_tokens: CONFIG.llm.maxTokens,
      temperature: 0.3,
      messages: [
        { role: 'system', content: PREDICT_PROMPT },
        { role: 'user', content: input },
      ],
      response_format: { type: 'json_object' },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) return getDefaultResult('try_again', 30);

    const parsed = JSON.parse(content);

    const result: ViralityResult = {
      captionScore: clamp(parsed.caption_score ?? 5, 1, 10),
      pairingCleverness: clamp(parsed.pairing_cleverness ?? 5, 1, 10),
      shareability: clamp(parsed.shareability ?? 5, 1, 10),
      recognition: clamp(parsed.recognition ?? 5, 1, 10),
      culturalTiming: clamp(parsed.cultural_timing ?? 5, 1, 10),
      rewatchFactor: clamp(parsed.rewatch_factor ?? 5, 1, 10),
      viralityScore: clamp(parsed.virality_score ?? 30, 1, 100),
      verdict: normalizeVerdict(parsed.verdict),
      reasoning: parsed.reasoning || '',
      improvementHint: parsed.improvement_hint || '',
    };

    const emoji = result.verdict === 'ship_it' ? '🔥' : result.verdict === 'almost' ? '🤏' : '❌';
    console.log(`[Virality] ${emoji} Score: ${result.viralityScore}/100 — ${result.verdict.toUpperCase()}`);
    console.log(`[Virality]   Caption: ${result.captionScore}/10 | Cleverness: ${result.pairingCleverness}/10 | Shareability: ${result.shareability}/10`);
    console.log(`[Virality]   ${result.reasoning.slice(0, 120)}`);

    if (result.verdict !== 'ship_it' && result.improvementHint) {
      console.log(`[Virality]   Hint: ${result.improvementHint.slice(0, 120)}`);
    }

    return result;
  } catch (err: any) {
    console.warn(`[Virality] Prediction failed: ${err.message}`);
    return getDefaultResult('almost', 50);
  }
}

function clamp(val: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, val));
}

function normalizeVerdict(v: string): 'ship_it' | 'try_again' | 'almost' {
  if (v === 'ship_it') return 'ship_it';
  if (v === 'almost') return 'almost';
  return 'try_again';
}

function getDefaultResult(verdict: 'ship_it' | 'try_again' | 'almost', score: number): ViralityResult {
  return {
    captionScore: 5,
    pairingCleverness: 5,
    shareability: 5,
    recognition: 5,
    culturalTiming: 5,
    rewatchFactor: 5,
    viralityScore: score,
    verdict,
    reasoning: 'Could not analyze — using default.',
    improvementHint: '',
  };
}
