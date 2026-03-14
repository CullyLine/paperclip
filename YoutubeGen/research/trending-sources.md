# Trending Topic Sources Research

Research for the YouTube Shorts Generator Pipeline — identifying the best APIs, scraping approaches, and data sources for real-time trending topics.

---

## 1. Google Trends

### Options

| Approach | Type | Cost | Reliability |
|----------|------|------|-------------|
| **SerpApi Google Trends API** | Official 3rd-party | 100 free searches/mo, then paid | High (99.9% uptime) |
| **pytrends** | Unofficial Python lib | Free | Medium — breaks when Google changes backend |
| **pytrends-async** | Async fork of pytrends | Free | Medium — same fragility, adds retry/proxy support |

### SerpApi (Recommended)

- Official Python library: `serpapi-python`
- Supports: interest over time, geographic breakdowns, related topics, related queries, **trending searches** (real-time + daily)
- Max 5 terms per search, 100 char limit per term
- Free tier: 100 searches/month
- Endpoint for trending now: `engine=google_trends_trending_now`

```typescript
// Node.js usage
import { getJson } from "serpapi";
const result = await getJson({
  engine: "google_trends_trending_now",
  frequency: "realtime",
  geo: "US",
  cat: "all",
  api_key: process.env.SERPAPI_KEY,
});
```

### pytrends (Fallback)

- `pip install pytrends`
- `trending_searches()` returns daily trending searches by country
- `realtime_trending_searches()` returns real-time trends
- **Problem**: Frequently breaks, needs proxy rotation to avoid rate limits
- Use only as fallback if SerpApi budget is exhausted

### Recommendation

**Use SerpApi as primary.** 100 free searches/month is enough for a daily pipeline (3-4 searches/day). Fall back to pytrends with proxy rotation if budget is a concern.

---

## 2. Reddit API

### Authentication

- OAuth 2.0 required for useful access
- Register app at `reddit.com/prefs/apps` (script type for server-side)
- Access tokens expire after 1 hour — implement refresh token logic
- User-Agent format: `<platform>:<app_id>:<version> (by /u/<username>)`

### Rate Limits

| Access Type | Limit |
|-------------|-------|
| Unauthenticated | 10 req/min |
| OAuth authenticated | 60 req/min |
| Free tier (OAuth) | 100 QPM per client ID |

- Rate limit headers: `X-Ratelimit-Reset`, `X-Ratelimit-Remaining`, `X-Ratelimit-Used`
- Pagination: max 100 items per request, max 1,000 total via pagination

### Pricing

- **$0.24 per 1,000 API calls**
- Free tier: 100 req/min, 10,000 monthly calls
- Pagination and auth overhead add ~2-5% to actual request counts

### Best Subreddits for Trending Zoomer Topics

| Subreddit | Members | Signal Type |
|-----------|---------|-------------|
| r/memes | 30M+ | Mainstream meme trends |
| r/meirl | 7M+ | Relatable/self-deprecating humor |
| r/2meirl4meirl | 2M+ | Nihilistic/dark relatable humor |
| r/GenZ | 1M+ | Gen Z culture, trends, discourse |
| r/me_irl | 7M+ | Absurdist relatable content |
| r/shitposting | 3M+ | Absurdist/ironic memes |
| r/whenthe | 500K+ | "When the..." meme format (directly relevant) |
| r/dankmemes | 7M+ | Edgier mainstream memes |
| r/MovieDetails | 3M+ | Movie scene discussions |
| r/reactiongifs | 2M+ | Reaction content trends |

### Useful Endpoints

```
GET /r/{subreddit}/hot    — currently popular posts
GET /r/{subreddit}/rising — early trending posts (best signal)
GET /r/popular             — cross-subreddit trending
GET /api/trending_searches — sitewide trending search terms
```

### Recommendation

**High-value, low-cost source.** Use `/rising` on target subreddits for early trend detection. Poll every 30-60 minutes. r/whenthe and r/meirl are the highest-signal subreddits for this specific content format.

---

## 3. X (Twitter) API

### Access Tiers

| Tier | Cost | Read Quota | Notes |
|------|------|------------|-------|
| Free | $0 | 100 reads/mo | Extremely limited |
| Basic | $200/mo | 10K reads/mo | Minimum viable tier |
| Pro | $5K/mo | 1M reads/mo | Full trending access |
| Enterprise | $42K+/mo | Negotiated | Overkill for this use case |

### Trending Endpoint

```
GET /2/trends/by/woeid/{woeid}
```

- WOEID `1` = worldwide, `23424977` = United States
- Returns top 50 trending topics with tweet volume
- Free tier: likely insufficient (100 reads/month total)

### Reality Check

The X API is **prohibitively expensive** for a content generation pipeline. At $200/month for Basic, you get trending data but limited read capacity. The free tier (100 reads/month) is essentially useless for automated pipelines.

### Alternative: Scraping

- Nitter instances (unofficial Twitter frontend) — increasingly unreliable
- Third-party scrapers exist but violate X ToS
- Not recommended for production pipelines

### Recommendation

**Deprioritize.** X trending data is valuable but the API pricing makes it impractical. Use it only if already paying for X API for other reasons. Google Trends and Reddit provide comparable trend signal at far lower cost.

---

## 4. TikTok

### Official Research API

- Apply via [TikTok Developer Portal](https://developers.tiktok.com/research/)
- Requires project registration and approval
- Auth: Client Key + Client Secret → access token
- Supports querying by: keywords, hashtags, music IDs, regions, date ranges
- **Caveat**: Research API approval can take weeks and has usage restrictions

### Third-Party APIs

| Service | What It Offers | Cost |
|---------|---------------|------|
| **SociaVault** | Trending videos, trending music, music details | Paid tiers |
| **Soundcharts** | TikTok music/sound trend data | Paid tiers |
| **Apify TikTok Trending Songs** | Top 100 trending songs by country | $20/mo + usage |
| **Unofficial TikTok scrapers** | Various data points | Free but fragile |

### Useful Data Points

- Trending sounds/music → indicates cultural moment topics
- Trending hashtags → surface emerging trends
- Viral video formats → detect format trends (relevant for our caption format)

### Recommendation

**Use as supplementary signal only.** TikTok trends often lead YouTube Shorts trends by 1-3 days, making it valuable for early detection. But API access is harder to get than Reddit/Google. Use Apify or SociaVault if budget allows; otherwise treat as nice-to-have.

---

## 5. Recommended Priority Order for Pipeline

| Priority | Source | Why | Setup Effort | Cost |
|----------|--------|-----|-------------|------|
| **1** | Google Trends (SerpApi) | Most reliable trending signal, covers all topics | Low | Free tier sufficient |
| **2** | Reddit API | Best for zoomer/meme-specific trends, cheap | Low | ~$0.24/1K calls |
| **3** | TikTok (Apify/SociaVault) | Early trend detection, format trends | Medium | $20+/mo |
| **4** | X/Twitter API | Good signal but overpriced | Low | $200+/mo |

### Suggested Pipeline Flow

```
1. Google Trends → get broad trending topics (daily)
2. Reddit /rising → filter for zoomer-relevant trends (every 30-60 min)
3. Cross-reference: topics trending on BOTH sources = high confidence
4. Optional: TikTok trending sounds → supplementary cultural signal
5. Output: ranked list of topics with source, confidence score, and context
```

### Data Schema for Pipeline Output

```typescript
interface TrendingTopic {
  topic: string;
  sources: ("google_trends" | "reddit" | "tiktok" | "twitter")[];
  confidence: number; // 0-1, higher = more sources agree
  sentiment: "positive" | "negative" | "neutral" | "mixed";
  context: string; // brief description of why it's trending
  relatedSubreddits: string[];
  trendVelocity: "rising" | "peak" | "declining";
  discoveredAt: string; // ISO timestamp
}
```
