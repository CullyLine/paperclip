import type { TrendingTopic } from './types';

const googleTrends = require('google-trends-api');

async function fetchGoogleTrends(): Promise<TrendingTopic[]> {
  try {
    const results = await googleTrends.dailyTrends({ geo: 'US' });
    const parsed = JSON.parse(results);
    const searches = parsed.default?.trendingSearchesDays?.[0]?.trendingSearches || [];

    return searches.slice(0, 10).map((s: any, i: number) => ({
      topic: s.title?.query || s.query || 'unknown',
      source: 'google' as const,
      context: s.articles?.[0]?.title || s.title?.query || '',
      sentiment: 'neutral' as const,
      score: 100 - i * 10,
    }));
  } catch (err) {
    console.warn('[TrendDiscovery] Google Trends fetch failed, using fallback topics');
    return [];
  }
}

async function fetchRedditTrends(): Promise<TrendingTopic[]> {
  const subreddits = ['memes', 'meirl', 'GenZ', '2meirl4meirl'];
  const topics: TrendingTopic[] = [];

  for (const sub of subreddits) {
    try {
      const res = await fetch(`https://www.reddit.com/r/${sub}/hot.json?limit=5`, {
        headers: { 'User-Agent': 'YoutubeShortGen/1.0' },
      });
      if (!res.ok) continue;
      const data: any = await res.json();
      const posts = data?.data?.children || [];

      for (const post of posts) {
        const d = post.data;
        if (d.stickied) continue;
        topics.push({
          topic: d.title,
          source: 'reddit',
          context: `r/${sub} - ${d.score} upvotes`,
          sentiment: 'mixed',
          score: Math.min(100, Math.round(d.score / 100)),
        });
      }
    } catch {
      continue;
    }
  }

  return topics.slice(0, 10);
}

/**
 * Discovers trending topics from multiple sources, returning a ranked list.
 * Falls back to curated topics if all API calls fail.
 */
export async function discoverTrends(count: number = 5): Promise<TrendingTopic[]> {
  console.log('[TrendDiscovery] Fetching trending topics...');

  const [googleTopics, redditTopics] = await Promise.allSettled([
    fetchGoogleTrends(),
    fetchRedditTrends(),
  ]);

  const allTopics: TrendingTopic[] = [
    ...(googleTopics.status === 'fulfilled' ? googleTopics.value : []),
    ...(redditTopics.status === 'fulfilled' ? redditTopics.value : []),
  ];

  if (allTopics.length === 0) {
    console.log('[TrendDiscovery] No live trends found, using fallback topics');
    return getFallbackTopics().slice(0, count);
  }

  allTopics.sort((a, b) => b.score - a.score);

  const seen = new Set<string>();
  const unique = allTopics.filter((t) => {
    const key = t.topic.toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  console.log(`[TrendDiscovery] Found ${unique.length} unique topics`);
  return unique.slice(0, count);
}

function getFallbackTopics(): TrendingTopic[] {
  return [
    { topic: 'rent prices', source: 'manual', context: 'Rising cost of living', sentiment: 'negative', score: 95 },
    { topic: 'dating apps', source: 'manual', context: 'Modern dating struggles', sentiment: 'mixed', score: 90 },
    { topic: 'remote work ending', source: 'manual', context: 'Return to office mandates', sentiment: 'negative', score: 88 },
    { topic: 'student loans', source: 'manual', context: 'Student debt crisis', sentiment: 'negative', score: 85 },
    { topic: 'AI replacing jobs', source: 'manual', context: 'AI automation anxiety', sentiment: 'mixed', score: 82 },
    { topic: 'grocery prices', source: 'manual', context: 'Inflation hitting groceries', sentiment: 'negative', score: 80 },
    { topic: 'adulting', source: 'manual', context: 'Struggle of being an adult', sentiment: 'mixed', score: 78 },
    { topic: 'side hustles', source: 'manual', context: 'Everyone needs a side hustle now', sentiment: 'mixed', score: 75 },
  ];
}
