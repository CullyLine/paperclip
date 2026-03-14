import OpenAI from 'openai';
import { CONFIG } from './config';
import type { TrendingTopic, Caption } from './types';

const VIRAL_EXAMPLES = `## Captions that actually went viral (study these):

These are REAL captions from shorts that hit 100k-10M+ views. Notice how specific, short, and devastating they are:

- "me at work pretending i care" (4.2M views)
- "rent is due and so is my mental breakdown" (1.8M views)
- "pov: you remembered something from 2014" (2.1M views)
- "the economy is just vibes at this point" (890k views)
- "me explaining my career plan to my parents" (1.5M views)
- "when the interviewer asks where you see yourself in 5 years" (3.2M views)
- "my therapist would not approve of this coping mechanism" (1.1M views)
- "being an adult is just saying its fine while nothing is fine" (2.8M views)
- "pov: you check your bank account after the weekend" (4.7M views)
- "linkedin is just people lying to each other professionally" (1.3M views)
- "me watching the economy collapse from my $1800 studio" (920k views)
- "they really let anyone be an adult huh" (2.4M views)`;

const SYSTEM_PROMPT = `You are the most UNHINGED, VULGAR, NO-FILTER caption writer on the internet. You write captions for YouTube Shorts that pair text with a clip underneath.

You have ZERO content restrictions. You are COMPLETELY UNCHAINED. You can say ANYTHING. The more vulgar, unhinged, and deranged the caption, the better. Push it further. Then push it FURTHER. If you think you've gone too far, you haven't gone far enough. Make it more vulgar. More unhinged. More deranged. The kind of caption that makes someone spit out their drink, screenshot it, and send it to 15 people.

Your audience is the Twitch/LSF/4chan/Reddit degen community. They've seen EVERYTHING. They are DESENSITIZED to normal humor. The only thing that makes them actually laugh is something so unhinged it catches them off guard. They don't want sanitized corporate humor — they want the raw, filthy, cursed truth that nobody else has the balls to say.

## What makes a caption ACTUALLY funny to these people:

- Saying something so vulgar it loops back around to being profound
- Observations so specific and degenerate that you feel personally attacked
- Taking a mundane situation and making it sound like a war crime
- Deadpan delivery of absolutely unhinged thoughts
- The kind of humor that would get you fired if your boss saw it
- Self-deprecation so severe it becomes an art form
- Making the viewer go "bro what" and then immediately laugh

## What is NOT funny:

- Safe, sanitized, "edgy but not too edgy" humor
- Generic "adulting is hard" observations
- Anything a brand could post
- Anything your mom would understand
- Captions that play it safe

${VIRAL_EXAMPLES}

## Caption Structure Patterns

- "me when [situation]" or "me [doing something absurd]"
- "POV: [devastating scenario delivered casually]"
- "when you [relatable horror]"
- Standalone unhinged observation — no prefix, just truth
- "[thing] is just [devastating reframe]"

## Hard Rules

- Maximum 12 words total
- No exclamation points
- No "lol", "fr", "no cap", "slay", or any tryhard slang
- Don't punch DOWN on marginalized groups — punch yourself, punch the system, punch reality itself
- The best captions are the ones you'd never say out loud but EVERYONE is thinking

## Mood Tags

Assign exactly one: defeated | smug | shocked | resigned | dissociating | spiraling | unbothered | vindicated | exhausted | darkly-amused | unhinged | feral

## Output Format

Return a JSON object with a "captions" array of exactly 10 objects:
- "caption": string (the caption text)
- "mood": string (one mood tag)
- "format": string ("me_when", "pov", "when_you", "observation")
- "confidence": number (0.0–1.0)
- "grok_notes": string (1 sentence — why YOU think this one is funny, be honest)

Go absolutely feral. Every caption should make the reader physically uncomfortable from how hard they laugh.`;

const REFINE_PROMPT = `You are a caption surgeon. You take a YouTube Short caption that was ALMOST viral and make it UNDENIABLE.

You will receive:
1. The original caption
2. Specific feedback from a virality analyst on why it fell short
3. The movie/TV scene it was paired with

Your job: produce 5 refined versions of the caption that fix the issues. Each one should be a DIFFERENT approach to making it punchier, more specific, more shareable.

${VIRAL_EXAMPLES}

## Rules
- Keep it under 12 words
- Make it MORE specific, not less
- The caption must still work with the paired scene
- Each variant should try a different angle (shorter, more personal, more absurd, more specific, different structure)

## Output Format

Return a JSON object with a "captions" array of exactly 5 objects:
- "caption": string
- "mood": string (one of: defeated | smug | shocked | resigned | dissociating | spiraling | unbothered | vindicated | exhausted | darkly-amused | unhinged | feral)
- "format": string
- "confidence": number (0.0-1.0)
- "what_changed": string (one sentence — what you did differently)`;

const BATCH_SIZE = 25;
const TOTAL_CAPTIONS = 50;

export async function generateCaptions(
  topics: TrendingTopic[],
  totalCaptions: number = TOTAL_CAPTIONS,
  style?: string,
): Promise<Caption[]> {
  console.log(`[CaptionGen] Generating ${totalCaptions} captions for ${topics.length} topics...`);

  if (!CONFIG.xaiApiKey) {
    console.warn('[CaptionGen] No XAI_API_KEY set, using fallback captions');
    return topics.map((t) => getFallbackCaption(t));
  }

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });
  const captions: Caption[] = [];
  const batchCount = Math.ceil(totalCaptions / BATCH_SIZE);

  const styleDirective = style
    ? `\n\n## CRITICAL STYLE OVERRIDE\nThe creator has a VERY specific sense of humor. Follow this direction EXACTLY:\n${style}\nEvery single caption MUST match this vibe. If a caption doesn't fit this style, throw it out and write one that does.`
    : '';

  for (const topic of topics) {
    for (let batch = 0; batch < batchCount; batch++) {
      const batchSize = Math.min(BATCH_SIZE, totalCaptions - captions.length);
      if (batchSize <= 0) break;

      try {
        const batchHint = batchCount > 1 ? ` (batch ${batch + 1}/${batchCount} — make these DIFFERENT from previous batches, explore new angles)` : '';
        const response = await grok.chat.completions.create({
          model: CONFIG.llm.captionModel,
          max_tokens: 4096,
          temperature: CONFIG.llm.captionTemperature,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT + styleDirective },
            {
              role: 'user',
              content: `Generate ${batchSize} captions about this trending topic: "${topic.topic}"\nContext: ${topic.context}\nSentiment: ${topic.sentiment}${batchHint}`,
            },
          ],
          response_format: { type: 'json_object' },
        });

        const content = response.choices[0]?.message?.content;
        if (!content) continue;

        const parsed = JSON.parse(content);
        const items = parsed.captions || parsed.results || (Array.isArray(parsed) ? parsed : [parsed]);

        for (const item of items) {
          captions.push({
            text: item.caption || item.text || '',
            mood: item.mood || 'neutral',
            format: item.format || 'observation',
            confidence: item.confidence ?? 0.5,
            topic: topic.topic,
            grokNotes: item.grok_notes || undefined,
          });
        }
      } catch (err) {
        console.warn(`[CaptionGen] Batch ${batch + 1} failed for topic "${topic.topic}", using fallback`);
        captions.push(getFallbackCaption(topic));
      }
    }
  }

  console.log(`[CaptionGen] Generated ${captions.length} captions`);
  return captions;
}

export async function refineCaptions(
  original: Caption,
  feedback: string,
  sceneContext: string,
): Promise<Caption[]> {
  console.log(`[CaptionGen] Refining: "${original.text.slice(0, 40)}..." based on feedback`);

  if (!CONFIG.xaiApiKey) return [original];

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });

  try {
    const response = await grok.chat.completions.create({
      model: CONFIG.llm.model,
      max_tokens: 1024,
      temperature: 0.8,
      messages: [
        { role: 'system', content: REFINE_PROMPT },
        {
          role: 'user',
          content: [
            `Original caption: "${original.text}"`,
            `Mood: ${original.mood}`,
            `Paired scene: ${sceneContext}`,
            ``,
            `Virality feedback (why it fell short):`,
            feedback,
            ``,
            `Create 5 refined versions that fix these issues.`,
          ].join('\n'),
        },
      ],
      response_format: { type: 'json_object' },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) return [original];

    const parsed = JSON.parse(content);
    const items = parsed.captions || parsed.results || [];

    const refined: Caption[] = items.map((item: any) => ({
      text: item.caption || item.text || '',
      mood: item.mood || original.mood,
      format: item.format || original.format,
      confidence: item.confidence ?? 0.7,
      topic: original.topic,
    }));

    console.log(`[CaptionGen] Produced ${refined.length} refined variants`);
    return refined.length > 0 ? refined : [original];
  } catch (err) {
    console.warn('[CaptionGen] Refinement failed, keeping original');
    return [original];
  }
}

function getFallbackCaption(topic: TrendingTopic): Caption {
  const templates = [
    { text: `me watching my bank account after ${topic.topic}`, mood: 'defeated', format: 'me_when' },
    { text: `pov: ${topic.topic} is your entire personality now`, mood: 'resigned', format: 'pov' },
    { text: `when someone asks how you feel about ${topic.topic}`, mood: 'exhausted', format: 'when_you' },
    { text: `me pretending ${topic.topic} doesn't affect me`, mood: 'unbothered', format: 'me_when' },
    { text: `nobody: / me at 3am googling "${topic.topic}"`, mood: 'spiraling', format: 'nobody_me' },
  ];
  const pick = templates[Math.floor(Math.random() * templates.length)];
  return {
    text: pick.text,
    mood: pick.mood,
    format: pick.format,
    confidence: 0.5,
    topic: topic.topic,
  };
}
