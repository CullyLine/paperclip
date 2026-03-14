import OpenAI from 'openai';
import { CONFIG } from './config';
import type { Caption, SceneMatch, SceneAlternative } from './types';

const SYSTEM_PROMPT = `You are a genius at pairing captions with movie/TV clips for viral YouTube Shorts. The format: black bar with caption text on top, movie clip on bottom.

## THE MOST IMPORTANT THING

The pairing must be CLEVER. Not just mood-matching. CLEVER. The clip should create a VISUAL METAPHOR, DOUBLE MEANING, or IRONIC PARALLEL with the caption. The audience laughs because the connection is SMART — they see the clip and think "oh my god that's perfect."

## What makes a pairing CLEVER vs BORING:

BORING: Caption about being tired → clip of someone yawning
CLEVER: Caption about being tired → clip of a soldier crawling through mud in a war movie

BORING: Caption about rent being expensive → clip of someone looking at money
CLEVER: Caption about rent being expensive → clip of someone being held at gunpoint ("your money or your life" energy)

BORING: Caption about job interviews → clip of someone sitting in an office
CLEVER: Caption about job interviews → clip of an interrogation scene where the detective slams the table

BORING: Caption about groceries → clip of someone shopping
CLEVER: Caption about groceries → clip of someone staring at a ransom note (because that's what grocery receipts feel like)

The clip should make the viewer RECONTEXTUALIZE the scene. They know the movie scene, but the caption reframes it into something about modern life. That reframing IS the joke.

## Scene Selection Rules

1. **The connection must be CLEVER** — a visual pun, metaphor, ironic parallel, or recontextualization
2. **Widely recognizable** — ages 20–35 should recognize it without context
3. **The scene tells a story in 5-15 seconds** — a single reaction shot, a dramatic moment, a character doing something specific
4. **Dialogue in the clip can ADD to the joke** — if the character says something that doubles as commentary on the caption topic, that's GOLD
5. **No context required** — the clip must work on its own
6. **Findable on YouTube** — major movies/shows that have scene compilations uploaded

## Examples of GOD-TIER pairings:

- "me explaining to my boss why i was late" + The Godfather (someone pleading before Don Corleone)
- "my bank account after one weekend" + Saving Private Ryan (medic trying to save a dying soldier)
- "applying for a job that requires 5 years experience for entry level" + Squid Game (players looking at an impossible game)
- "me pretending to work while my boss walks by" + Mission Impossible (Tom Cruise sneaking past lasers)
- "grocery prices in 2026" + Pirates of the Caribbean (Jack Sparrow looking at an empty treasure chest)

## Output Format

Return a JSON object:
- "movie": string (full title)
- "year": number
- "character": string
- "scene_description": string (2–3 sentences — be SPECIFIC about what happens visually)
- "why_its_clever": string (explain the visual metaphor or ironic parallel in one sentence)
- "search_keywords": array of 4–6 strings (be VERY specific to find THIS scene, include dialogue quotes if applicable)
- "clip_start_hint": string (what to look for as the start frame)
- "clip_end_hint": string (what to look for as the end frame)
- "confidence": number (0.0–1.0)
- "alternatives": array of 2 objects with "movie", "character", "scene_description", "search_keywords", "why_its_clever"

Think like a meme lord with a film degree. The best pairing makes someone screenshot it and send it to their group chat.`;

const JOINT_SELECT_PROMPT = `You are picking the SINGLE BEST caption+scene pairing from a list of candidate captions for a YouTube Short.

You will receive a numbered list of captions. Your job:
1. Read ALL of them
2. For each one, think about what movie/TV scene would pair with it MOST CLEVERLY
3. Pick the ONE caption that has the most BRILLIANT, CLEVER scene pairing potential
4. Return that caption AND the perfect scene for it

The winning caption isn't necessarily the funniest caption in isolation — it's the one where you thought of a scene pairing so clever it made YOU laugh. The visual metaphor or ironic parallel should be undeniable.

Return a JSON object with:
- "selected_index": number (0-based index of the chosen caption)
- "selected_caption": string (the caption text)
- "why_this_one": string (why this caption+scene pairing is the cleverest)
- "movie": string (full title)
- "year": number
- "character": string
- "scene_description": string (2–3 sentences, SPECIFIC visual details)
- "why_its_clever": string (the visual metaphor or ironic parallel)
- "search_keywords": array of 4–6 strings (SPECIFIC to find THIS scene)
- "clip_start_hint": string
- "clip_end_hint": string
- "confidence": number (0.0–1.0)
- "alternatives": array of 2 objects with "movie", "character", "scene_description", "search_keywords", "why_its_clever"`;

export interface JointMatch {
  caption: Caption;
  scene: SceneMatch;
}

export async function selectBestPairing(captions: Caption[]): Promise<JointMatch> {
  console.log(`[SceneMatcher] Evaluating ${captions.length} captions for best caption+scene pairing...`);

  if (!CONFIG.xaiApiKey || captions.length === 0) {
    const caption = captions[0] || { text: 'existence is a group project nobody signed up for', mood: 'resigned', format: 'observation', confidence: 0.5, topic: '' };
    return { caption, scene: getFallbackScene(caption) };
  }

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });

  const captionList = captions.map((c, i) => `${i}. "${c.text}" [mood: ${c.mood}]`).join('\n');

  try {
    const response = await grok.chat.completions.create({
      model: CONFIG.llm.model,
      max_tokens: 2048,
      temperature: CONFIG.llm.sceneTemperature,
      messages: [
        { role: 'system', content: JOINT_SELECT_PROMPT },
        {
          role: 'user',
          content: `Here are ${captions.length} caption candidates. Pick the ONE with the most clever scene pairing:\n\n${captionList}`,
        },
      ],
      response_format: { type: 'json_object' },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) {
      const caption = captions[0];
      return { caption, scene: await matchScene(caption) };
    }

    const parsed = JSON.parse(content);
    const selectedIdx = parsed.selected_index ?? 0;
    const selectedCaption = captions[selectedIdx] || captions[0];

    console.log(`[SceneMatcher] Selected #${selectedIdx}: "${selectedCaption.text}"`);
    console.log(`[SceneMatcher] Why: ${(parsed.why_this_one || '').slice(0, 100)}`);

    const scene: SceneMatch = {
      movieTitle: parsed.movie || parsed.movieTitle || 'Unknown',
      year: parsed.year || 0,
      character: parsed.character || 'Unknown',
      momentDescription: parsed.scene_description || parsed.momentDescription || '',
      emotionalMatch: parsed.why_its_clever || '',
      searchKeywords: parsed.search_keywords || parsed.searchKeywords || [`${parsed.movie} scene`],
      clipStartHint: parsed.clip_start_hint || '',
      clipEndHint: parsed.clip_end_hint || '',
      emotion: selectedCaption.mood || 'neutral',
      confidence: parsed.confidence ?? 0.5,
      alternatives: (parsed.alternatives || []).slice(0, 2).map((alt: any) => ({
        movieTitle: alt.movie || alt.movieTitle || '',
        character: alt.character || '',
        momentDescription: alt.scene_description || alt.momentDescription || '',
        searchKeywords: alt.search_keywords || alt.searchKeywords || [],
      })),
    };

    return { caption: selectedCaption, scene };
  } catch (err) {
    console.warn('[SceneMatcher] Joint selection failed, falling back to single match');
    const caption = captions[0];
    return { caption, scene: await matchScene(caption) };
  }
}

const TOP_N_PROMPT = `You are picking the TOP 5 best caption+scene pairings from a list of candidate captions for YouTube Shorts.

You will receive a numbered list of captions. Your job:
1. Read ALL of them
2. For each one, think about what movie/TV scene would pair with it MOST CLEVERLY
3. Pick the TOP 5 captions that have the most BRILLIANT, CLEVER scene pairing potential
4. Return them ranked #1 (best) to #5

The winning captions aren't necessarily the funniest in isolation — they're the ones where the scene pairing creates a visual metaphor, ironic parallel, or recontextualization so clever it makes you laugh.

Return a JSON object with a "picks" array of exactly 5 objects, each containing:
- "rank": number (1-5)
- "caption_index": number (0-based index of the chosen caption)
- "caption_text": string (the caption text)
- "movie": string (full title)
- "year": number
- "character": string
- "scene_description": string (2-3 sentences, SPECIFIC visual details)
- "why_its_clever": string (the visual metaphor or ironic parallel — this is the punchline explanation)
- "search_keywords": array of 4-6 strings
- "clip_start_hint": string
- "clip_end_hint": string
- "confidence": number (0.0-1.0)
- "alternatives": array of 2 objects with "movie", "character", "scene_description", "search_keywords", "why_its_clever"`;

export interface RankedPairing {
  rank: number;
  caption: Caption;
  scene: SceneMatch;
}

export async function selectTopPairings(captions: Caption[], count: number = 5): Promise<RankedPairing[]> {
  console.log(`[SceneMatcher] Selecting top ${count} pairings from ${captions.length} captions...`);

  if (!CONFIG.xaiApiKey || captions.length === 0) {
    const caption = captions[0] || { text: 'existence is a group project nobody signed up for', mood: 'resigned', format: 'observation', confidence: 0.5, topic: '' };
    return [{ rank: 1, caption, scene: getFallbackScene(caption) }];
  }

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });
  const captionList = captions.map((c, i) => `${i}. "${c.text}" [mood: ${c.mood}]`).join('\n');

  try {
    const response = await grok.chat.completions.create({
      model: CONFIG.llm.model,
      max_tokens: 4096,
      temperature: CONFIG.llm.sceneTemperature,
      messages: [
        { role: 'system', content: TOP_N_PROMPT },
        {
          role: 'user',
          content: `Here are ${captions.length} caption candidates. Pick the TOP 5 with the cleverest scene pairings:\n\n${captionList}`,
        },
      ],
      response_format: { type: 'json_object' },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) return [];

    const parsed = JSON.parse(content);
    const picks = parsed.picks || [];

    return picks.slice(0, count).map((pick: any, i: number) => {
      const idx = pick.caption_index ?? 0;
      const caption = captions[idx] || captions[0];

      const scene: SceneMatch = {
        movieTitle: pick.movie || 'Unknown',
        year: pick.year || 0,
        character: pick.character || 'Unknown',
        momentDescription: pick.scene_description || '',
        emotionalMatch: pick.why_its_clever || '',
        searchKeywords: pick.search_keywords || [`${pick.movie} scene`],
        clipStartHint: pick.clip_start_hint || '',
        clipEndHint: pick.clip_end_hint || '',
        emotion: caption.mood || 'neutral',
        confidence: pick.confidence ?? 0.5,
        alternatives: (pick.alternatives || []).slice(0, 2).map((alt: any) => ({
          movieTitle: alt.movie || alt.movieTitle || '',
          character: alt.character || '',
          momentDescription: alt.scene_description || alt.momentDescription || '',
          searchKeywords: alt.search_keywords || alt.searchKeywords || [],
        })),
      };

      return { rank: pick.rank ?? (i + 1), caption, scene };
    });
  } catch (err) {
    console.warn('[SceneMatcher] Top-N selection failed');
    return [];
  }
}

const MULTI_SCENE_PROMPT = `You are finding MULTIPLE different movie/TV clip options for a SINGLE YouTube Shorts caption.

The format: black bar with caption text on top, movie/TV clip on bottom.

You will receive ONE caption. Your job:
1. Brainstorm many possible movie/TV scenes that would pair with this caption
2. Pick the MOST CLEVER, DIFFERENT options — each should be a distinct movie/show with a unique angle on the joke
3. Rank them by how clever the visual metaphor / ironic parallel is

Return a JSON object with a "scenes" array of objects, each containing:
- "rank": number (1 = best)
- "movie": string (full title)
- "year": number
- "character": string
- "scene_description": string (2-3 sentences, SPECIFIC visual details)
- "why_its_clever": string (the visual metaphor or ironic parallel)
- "search_keywords": array of 4-6 strings
- "clip_start_hint": string
- "clip_end_hint": string
- "confidence": number (0.0-1.0)

RULES:
- Every scene must be from a DIFFERENT movie/show
- Prioritize iconic, instantly recognizable moments
- The scene must work as a 3-8 second silent clip
- Think about the VISUAL irony, not just thematic connection`;

const TWITCH_SCENE_PROMPT = `You are finding the BEST Twitch streamer / LSF (LiveStreamFail) clip to pair with a YouTube Shorts caption.

The format: black bar with caption text on top, Twitch clip on bottom.

You will receive ONE caption. Your job:
1. Think about which popular Twitch streamer moments would PERFECTLY match this caption
2. Pick the MOST ICONIC, RECOGNIZABLE, and FUNNY options
3. Focus on moments that the Twitch/LSF community has already memed to death — that recognition is what makes it viral

## Streamer moments to consider (these are GOLDMINES on YouTube):
- xQc: raging at chat, desk slamming, confused face, juicer rants, rapid-fire takes
- Tyler1: screaming, head dent jokes, League rage, standing desk slam
- Forsen: blank stare at chat, god gamer moments, hobo arc, sitting in silence
- HasanAbi: leaning back in chair, "chat..." exasperation, political rants
- Kai Cenat: losing his mind laughing, over-the-top reactions, W streamer moments
- IShowSpeed: screaming, running around, unhinged energy
- Pokimane: facepalm, "are you serious" look, done-with-chat energy
- Asmongold: bald take delivery, MMO grinding face, "actually..." rants
- Mizkif: forced laugh, OTK chaos, "content" face
- Summit1g: 1G moment, calm before storm rage, bald stare
- Sodapoppin: disappointed dad energy, old school vibes, WoW malding
- Jerma985: psycho face, sus moments, unhinged smile
- Any LSF top clip — if it was on the front page of r/LivestreamFail, it's searchable

Return a JSON object with a "scenes" array of objects, each containing:
- "rank": number (1 = best)
- "movie": string (the streamer's name — treat them as the "movie title")
- "year": number (year of the clip/stream, approximate is fine)
- "character": string (streamer name again, or their known persona like "el goblino xQc")
- "scene_description": string (2-3 sentences — describe the EXACT moment: what they're doing, their facial expression, the energy)
- "why_its_clever": string (why this streamer moment + this caption = comedy gold)
- "search_keywords": array of 4-6 strings (YouTube search terms that will ACTUALLY find this clip — include "twitch", streamer name, and the moment description)
- "clip_start_hint": string
- "clip_end_hint": string
- "confidence": number (0.0-1.0)

RULES:
- Every clip must be from a DIFFERENT streamer
- Prioritize moments that have been clipped thousands of times (easy to find on YouTube)
- The moment should be visually funny even without audio
- Think about FACIAL EXPRESSIONS and BODY LANGUAGE — that's what carries the joke in a silent Short
- search_keywords MUST include the streamer's name and "twitch clip" or "lsf" for better YouTube results`;

export async function matchMultipleScenes(caption: Caption, count: number = 5): Promise<SceneMatch[]> {
  console.log(`[SceneMatcher] Finding ${count} clip options for: "${caption.text.slice(0, 50)}..."`);

  if (!CONFIG.xaiApiKey) {
    return [getFallbackScene(caption)];
  }

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });

  try {
    const response = await grok.chat.completions.create({
      model: CONFIG.llm.model,
      max_tokens: 4096,
      temperature: CONFIG.llm.sceneTemperature,
      messages: [
        { role: 'system', content: MULTI_SCENE_PROMPT },
        {
          role: 'user',
          content: `Caption: "${caption.text}"\nMood: ${caption.mood}\n\nFind ${count} different clip options ranked by cleverness.`,
        },
      ],
      response_format: { type: 'json_object' },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) return [getFallbackScene(caption)];

    const parsed = JSON.parse(content);
    const scenes = parsed.scenes || [];

    return scenes.slice(0, count).map((s: any) => ({
      movieTitle: s.movie || 'Unknown',
      year: s.year || 0,
      character: s.character || 'Unknown',
      momentDescription: s.scene_description || '',
      emotionalMatch: s.why_its_clever || '',
      searchKeywords: s.search_keywords || [`${s.movie} scene`],
      clipStartHint: s.clip_start_hint || '',
      clipEndHint: s.clip_end_hint || '',
      emotion: caption.mood || 'neutral',
      confidence: s.confidence ?? 0.5,
      alternatives: [],
    }));
  } catch (err) {
    console.warn('[SceneMatcher] Multi-scene match failed, using fallback');
    return [getFallbackScene(caption)];
  }
}

export async function matchTwitchClips(caption: Caption, count: number = 5): Promise<SceneMatch[]> {
  console.log(`[SceneMatcher] Finding ${count} Twitch/LSF clips for: "${caption.text.slice(0, 50)}..."`);

  if (!CONFIG.xaiApiKey) {
    return [getFallbackScene(caption)];
  }

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });

  try {
    const response = await grok.chat.completions.create({
      model: CONFIG.llm.model,
      max_tokens: 4096,
      temperature: CONFIG.llm.sceneTemperature,
      messages: [
        { role: 'system', content: TWITCH_SCENE_PROMPT },
        {
          role: 'user',
          content: `Caption: "${caption.text}"\nMood: ${caption.mood}\n\nFind ${count} different Twitch streamer clip options ranked by how perfectly they match.`,
        },
      ],
      response_format: { type: 'json_object' },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) return [getFallbackScene(caption)];

    const parsed = JSON.parse(content);
    const scenes = parsed.scenes || [];

    return scenes.slice(0, count).map((s: any) => ({
      movieTitle: s.movie || 'Unknown',
      year: s.year || 0,
      character: s.character || 'Unknown',
      momentDescription: s.scene_description || '',
      emotionalMatch: s.why_its_clever || '',
      searchKeywords: s.search_keywords || [`${s.movie} twitch clip`],
      clipStartHint: s.clip_start_hint || '',
      clipEndHint: s.clip_end_hint || '',
      emotion: caption.mood || 'neutral',
      confidence: s.confidence ?? 0.5,
      alternatives: [],
    }));
  } catch (err) {
    console.warn('[SceneMatcher] Twitch clip match failed, using fallback');
    return [getFallbackScene(caption)];
  }
}

export async function matchScene(caption: Caption): Promise<SceneMatch> {
  console.log(`[SceneMatcher] Matching scene for: "${caption.text.slice(0, 50)}..."`);

  if (!CONFIG.xaiApiKey) {
    return getFallbackScene(caption);
  }

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });

  try {
    const response = await grok.chat.completions.create({
      model: CONFIG.llm.model,
      max_tokens: CONFIG.llm.maxTokens,
      temperature: CONFIG.llm.sceneTemperature,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        {
          role: 'user',
          content: `Caption: "${caption.text}"\nMood: ${caption.mood}`,
        },
      ],
      response_format: { type: 'json_object' },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) return getFallbackScene(caption);

    const parsed = JSON.parse(content);
    return {
      movieTitle: parsed.movie || parsed.movieTitle || 'Unknown',
      year: parsed.year || 0,
      character: parsed.character || 'Unknown',
      momentDescription: parsed.scene_description || parsed.momentDescription || '',
      emotionalMatch: parsed.why_its_clever || parsed.emotional_match || '',
      searchKeywords: parsed.search_keywords || parsed.searchKeywords || [`${parsed.movie} scene`],
      clipStartHint: parsed.clip_start_hint || '',
      clipEndHint: parsed.clip_end_hint || '',
      emotion: caption.mood || 'neutral',
      confidence: parsed.confidence ?? 0.5,
      alternatives: (parsed.alternatives || []).slice(0, 2).map((alt: any) => ({
        movieTitle: alt.movie || alt.movieTitle || '',
        character: alt.character || '',
        momentDescription: alt.scene_description || alt.momentDescription || '',
        searchKeywords: alt.search_keywords || alt.searchKeywords || [],
      })),
    };
  } catch (err) {
    console.warn('[SceneMatcher] LLM call failed, using fallback');
    return getFallbackScene(caption);
  }
}

const FALLBACK_SCENES: SceneMatch[] = [
  {
    movieTitle: 'The Office',
    year: 2005,
    character: 'Michael Scott',
    momentDescription: 'Michael screaming "No! God! No!" in his office after receiving bad news.',
    emotionalMatch: 'Pure dramatic overreaction to a mundane situation — the contrast with a dry caption is instant comedy.',
    searchKeywords: ['the office michael scott no god no', 'michael scott screaming no', 'the office no scene'],
    clipStartHint: 'Michael stands up from desk',
    clipEndHint: 'Cut after the final "Nooooo"',
    emotion: 'defeated',
    confidence: 0.85,
    alternatives: [],
  },
  {
    movieTitle: 'Breaking Bad',
    year: 2008,
    character: 'Walter White',
    momentDescription: 'Walter staring blankly into space, the thousand-yard stare of a man who has run out of options.',
    emotionalMatch: 'The hollow emptiness matches resigned acceptance of a bad situation.',
    searchKeywords: ['breaking bad walter white stare', 'walter white blank stare scene', 'breaking bad defeated'],
    clipStartHint: 'Close-up on Walter\'s face',
    clipEndHint: 'Before any dialogue starts',
    emotion: 'defeated',
    confidence: 0.82,
    alternatives: [],
  },
  {
    movieTitle: 'The Office',
    year: 2005,
    character: 'Jim Halpert',
    momentDescription: 'Jim slowly turns to look directly at the camera with a completely flat expression. No words. Just the look.',
    emotionalMatch: 'Jim\'s silent fourth-wall break perfectly captures resigned awareness.',
    searchKeywords: ['jim halpert looks at camera the office', 'jim halpert reaction shot', 'the office jim to camera'],
    clipStartHint: 'Jim turns head toward camera',
    clipEndHint: 'Cut before he looks away or speaks',
    emotion: 'resigned',
    confidence: 0.92,
    alternatives: [],
  },
  {
    movieTitle: 'Pulp Fiction',
    year: 1994,
    character: 'Vincent Vega',
    momentDescription: 'John Travolta looking around confused in an empty apartment, the universal "where am I and what is happening" energy.',
    emotionalMatch: 'The disoriented confusion matches any caption about not understanding what\'s going on.',
    searchKeywords: ['john travolta confused pulp fiction meme', 'travolta looking around pulp fiction', 'confused travolta'],
    clipStartHint: 'Travolta enters and starts looking around',
    clipEndHint: 'After he gestures with his hands',
    emotion: 'dissociating',
    confidence: 0.88,
    alternatives: [],
  },
  {
    movieTitle: 'Blade Runner 2049',
    year: 2017,
    character: 'K',
    momentDescription: 'Ryan Gosling walking slowly through a desolate landscape with a hollow, thousand-yard stare.',
    emotionalMatch: 'The existential emptiness and visual beauty make any mundane caption feel epic and bleak.',
    searchKeywords: ['blade runner 2049 ryan gosling walk scene', 'ryan gosling blade runner stare', 'blade runner 2049 K walking'],
    clipStartHint: 'K walking in wide shot',
    clipEndHint: 'Before any dialogue',
    emotion: 'exhausted',
    confidence: 0.80,
    alternatives: [],
  },
];

function getFallbackScene(caption: Caption): SceneMatch {
  const idx = Math.floor(Math.random() * FALLBACK_SCENES.length);
  return FALLBACK_SCENES[idx];
}
