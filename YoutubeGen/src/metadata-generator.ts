import fs from 'fs';
import path from 'path';
import { CONFIG } from './config';
import type { Caption, SceneMatch, VideoMetadata, AnimalClipContext } from './types';

/**
 * Generates YouTube-optimized metadata for a Short.
 * Produces a JSON file with title, description, hashtags, tags, category,
 * and a pinned comment draft in Cully Mode voice.
 *
 * Two modes:
 *   - generateAnimalMetadata: for the animal channel (Cully Mode voice)
 *   - generateMetadata: legacy mode for movie-scene captions
 */

// ---------------------------------------------------------------------------
// Animal channel: Cully Mode metadata
// ---------------------------------------------------------------------------

const ANIMAL_BEHAVIOR_HASHTAGS: Record<string, string[]> = {
  scream: ['#funnyanimal', '#animalreaction', '#screaming'],
  sing: ['#singinganimal', '#funnyanimal', '#animalvideo'],
  dance: ['#dancinganimal', '#funnyanimal', '#animals'],
  eat: ['#funnyanimal', '#asmr', '#animals'],
  fight: ['#animalfight', '#funnyanimal', '#wildanimals'],
  climb: ['#animals', '#funnyanimal', '#wildlife'],
  stare: ['#animalreaction', '#funnyanimal', '#animals'],
  jump: ['#funnyanimal', '#animals', '#wildlife'],
  run: ['#funnyanimal', '#animals', '#wildanimals'],
  default: ['#funnyanimal', '#animals', '#shorts'],
};

const SPECIES_SEO_VARIANTS: Record<string, string[]> = {
  hyrax: ['hyrax', 'rock hyrax', 'hyrax screaming', 'hyrax funny', 'hyrax reaction'],
  monkey: ['monkey', 'funny monkey', 'capuchin monkey', 'monkey behavior', 'primate'],
  capuchin: ['capuchin', 'capuchin monkey', 'funny monkey', 'capuchin reaction'],
  cockatoo: ['cockatoo', 'funny cockatoo', 'cockatoo dance', 'parrot'],
  parrot: ['parrot', 'funny parrot', 'parrot talking', 'cockatoo'],
  cat: ['cat', 'funny cat', 'cat behavior', 'kitten', 'cats'],
  kitten: ['kitten', 'funny kitten', 'baby cat', 'kittens', 'cat'],
  bird: ['bird', 'funny bird', 'bird behavior', 'bird video'],
  dog: ['dog', 'funny dog', 'dog behavior', 'puppy', 'doggo'],
  bear: ['bear', 'funny bear', 'bear video', 'wildlife'],
  otter: ['otter', 'funny otter', 'otter video', 'sea otter'],
  raccoon: ['raccoon', 'funny raccoon', 'raccoon video', 'trash panda'],
  capybara: ['capybara', 'funny capybara', 'capybara video', 'capybara reaction'],
  goat: ['goat', 'funny goat', 'screaming goat', 'goat video'],
};

function getAnimalBehaviorHashtags(behavior: string): string[] {
  const lower = behavior.toLowerCase();
  for (const [key, tags] of Object.entries(ANIMAL_BEHAVIOR_HASHTAGS)) {
    if (lower.includes(key)) return tags;
  }
  return ANIMAL_BEHAVIOR_HASHTAGS.default;
}

function getSpeciesSeoVariants(species: string): string[] {
  const lower = species.toLowerCase();
  for (const [key, variants] of Object.entries(SPECIES_SEO_VARIANTS)) {
    if (lower.includes(key)) return variants;
  }
  // Unknown species: use as-is plus generic fallbacks
  const slug = lower.replace(/[^a-z0-9 ]/g, '').trim();
  return [slug, `funny ${slug}`, `${slug} video`, 'funny animal', 'animal behavior'];
}

/**
 * Builds the title with species parenthetical.
 * Input: "he checks in with the hole", species: "man"
 * Output: "he checks in with the hole (man)"
 * If the caption already has a parenthetical, it is preserved.
 */
function buildAnimalTitle(captionText: string, animalSpecies: string): string {
  const text = captionText.toLowerCase().trim();
  const hasParenthetical = /\([^)]+\)$/.test(text);
  if (hasParenthetical) return text;
  // Only append parenthetical if species is specific (not empty)
  if (!animalSpecies || animalSpecies.trim() === '') return text;
  return `${text} (${animalSpecies.toLowerCase().trim()})`;
}

/**
 * Builds the description with keyword layer.
 * Formula: deadpan one-liner | species keywords | behavior keywords | hashtags
 */
function buildAnimalDescription(
  captionText: string,
  species: string,
  behavior: string,
  hashtags: string[],
): string {
  const speciesVariants = getSpeciesSeoVariants(species);
  const keywordLine = speciesVariants.slice(0, 3).join(', ');
  const behaviorSlug = behavior.toLowerCase().trim();

  return [
    captionText.toLowerCase().trim(),
    '',
    `${keywordLine}, ${behaviorSlug}`,
    '',
    hashtags.join(' '),
  ].join('\n');
}

/**
 * Builds a pinned comment in Cully Mode voice.
 * The pinned comment acts as a voice extension — it should feel like a follow-up
 * observation from the same bureaucratic, fond observer. Keep it under 15 words.
 * No exclamation points. Deadpan delivery. Treat the animal's behavior as legitimate.
 */
function buildPinnedComment(captionText: string, behavior: string): string {
  const text = captionText.toLowerCase().trim();

  // Extract the verb phrase if possible (e.g. "checks in with", "has been at it", "forgot he had")
  const verbPhraseMatch = text.match(/^he ([a-z].*?)(?:\s*\([^)]+\))?$/);
  const verbPhrase = verbPhraseMatch ? verbPhraseMatch[1] : behavior;

  // Cully Mode pinned comment templates
  const templates = [
    `this is not the first time. we have documented the pattern.`,
    `the commitment is noted. the consistency is noted. all of it is noted.`,
    `he has been ${verbPhrase} for some time now. management is aware.`,
    `we are not alarmed. this is within his normal range of behavior.`,
    `the behavior has been logged. no action required at this time.`,
    `he does this every time. we have adjusted our expectations accordingly.`,
    `updates will be provided as the situation develops.`,
    `he is doing well. this is what doing well looks like for him.`,
  ];

  // Pick based on a hash of the caption text for determinism
  const idx = text.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0) % templates.length;
  return templates[idx];
}

/**
 * Generates metadata for the animal channel (Cully Mode voice).
 * This is the primary metadata generator for all current and future animal Shorts.
 */
export async function generateAnimalMetadata(
  context: AnimalClipContext,
  outputName: string,
): Promise<string> {
  console.log(`[Metadata] Generating animal metadata for: "${context.captionText.slice(0, 50)}"`);

  const speciesHashtag = context.animalSpecies.toLowerCase().replace(/[^a-z0-9]+/g, '');
  const behaviorHashtags = getAnimalBehaviorHashtags(context.behavior);

  const hashtags = [
    '#Shorts',
    `#${speciesHashtag}`,
    ...behaviorHashtags,
    '#wildlifecomedy',
  ].filter((h, i, arr) => arr.indexOf(h) === i).slice(0, 8);

  const title = buildAnimalTitle(context.captionText, context.animalSpecies);
  const description = buildAnimalDescription(
    context.captionText,
    context.animalSpecies,
    context.behavior,
    hashtags,
  );
  const pinnedComment = buildPinnedComment(context.captionText, context.behavior);

  const speciesVariants = getSpeciesSeoVariants(context.animalSpecies);
  const tags = [
    ...speciesVariants,
    context.behavior,
    'funny animal',
    'animal behavior',
    'wildlife',
    'animal comedy',
    'deadpan commentary',
    'wholesome',
  ].filter((t, i, arr) => arr.indexOf(t) === i).slice(0, 15);

  const metadata: VideoMetadata = {
    title,
    description,
    hashtags,
    tags,
    category: 'Pets & Animals',
    pinnedComment,
    animalSpecies: context.animalSpecies,
  };

  fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  const metadataPath = path.join(CONFIG.outputDir, `${outputName}_metadata.json`);
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));

  console.log(`[Metadata] Saved: ${metadataPath}`);
  return metadataPath;
}

// ---------------------------------------------------------------------------
// Legacy: movie-scene caption metadata (kept for backward compatibility)
// ---------------------------------------------------------------------------

const CULLY_MOODS = new Set(['tired', 'fond', 'accepting', 'concerned', 'matter-of-fact', 'deadpan']);

const TITLE_EMOJIS: Record<string, string> = {
  defeated: '\u{1F62D}',
  smug: '\u{1F480}',
  shocked: '\u{1F480}',
  resigned: '\u{1F605}',
  dissociating: '\u{1F480}',
  spiraling: '\u{1F62D}',
  unbothered: '\u{1F605}',
  vindicated: '\u{1F62D}',
  exhausted: '\u{1F62D}',
  'darkly-amused': '\u{1F480}',
};

const TOPIC_HASHTAGS: Record<string, string[]> = {
  money: ['#adulting', '#personalfinance', '#financialstress', '#broke'],
  finance: ['#adulting', '#personalfinance', '#financialstress'],
  work: ['#workmemes', '#officememes', '#9to5', '#careertok'],
  career: ['#workmemes', '#officememes', '#careertok'],
  dating: ['#dating', '#relationships', '#situationship'],
  relationship: ['#dating', '#relationships'],
  existential: ['#mentalhealth', '#zoomers', '#genz', '#quarterlifecrisis'],
  general: ['#mentalhealth', '#zoomers', '#genz'],
};

function getTopicHashtags(topic: string): string[] {
  const lower = topic.toLowerCase();
  for (const [key, tags] of Object.entries(TOPIC_HASHTAGS)) {
    if (lower.includes(key)) return tags.slice(0, 3);
  }
  const slug = lower.replace(/[^a-z0-9]+/g, '');
  return [`#${slug}`, '#adulting'];
}

function buildTitle(caption: Caption): string {
  const text = caption.text.toLowerCase();
  const maxLen = 70;
  const truncated = text.length <= maxLen ? text : text.slice(0, maxLen - 3) + '...';
  if (CULLY_MOODS.has(caption.mood)) {
    return truncated;
  }
  const emoji = TITLE_EMOJIS[caption.mood] || '\u{1F480}';
  return `${truncated} ${emoji}`;
}

export async function generateMetadata(
  caption: Caption,
  scene: SceneMatch,
  outputName: string
): Promise<string> {
  console.log(`[Metadata] Generating metadata for: "${caption.text.slice(0, 50)}..."`);

  const topicTags = getTopicHashtags(caption.topic);
  const movieTag = scene.movieTitle.toLowerCase().replace(/[^a-z0-9]+/g, '');

  const hashtags = [
    topicTags[0],
    '#relatable',
    '#Shorts',
    ...topicTags.slice(1),
    movieTag ? `#${movieTag}` : null,
  ].filter(Boolean) as string[];

  if (hashtags.length > 8) hashtags.length = 8;

  const tags = [
    caption.topic,
    'relatable',
    'funny',
    'zoomer humor',
    'adulting',
    'gen z',
    scene.movieTitle,
    scene.character,
    caption.mood,
    'short video',
    'viral',
    'comedy',
  ];

  const sceneCredit = scene.year
    ? `scene: ${scene.movieTitle} (${scene.year})`
    : `scene: ${scene.movieTitle}`;

  const metadata: VideoMetadata = {
    title: buildTitle(caption),
    description: [
      caption.text,
      '',
      sceneCredit,
      '',
      hashtags.join(' '),
    ].join('\n'),
    hashtags,
    tags,
    category: 'Comedy',
  };

  fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  const metadataPath = path.join(CONFIG.outputDir, `${outputName}_metadata.json`);
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));

  console.log(`[Metadata] Saved: ${metadataPath}`);
  return metadataPath;
}
