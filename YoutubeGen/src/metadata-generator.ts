import fs from 'fs';
import path from 'path';
import { CONFIG } from './config';
import type { Caption, SceneMatch, VideoMetadata } from './types';

/**
 * Generates YouTube-optimized metadata for a Short.
 * Produces a JSON file with title, description, hashtags, tags, and category.
 */
const TITLE_EMOJIS: Record<string, string> = {
  defeated: '😭',
  smug: '💀',
  shocked: '💀',
  resigned: '😅',
  dissociating: '💀',
  spiraling: '😭',
  unbothered: '😅',
  vindicated: '😭',
  exhausted: '😭',
  'darkly-amused': '💀',
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
  const emoji = TITLE_EMOJIS[caption.mood] || '💀';
  const text = caption.text.toLowerCase();
  const maxLen = 65;
  const truncated = text.length <= maxLen ? text : text.slice(0, maxLen - 3) + '...';
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
