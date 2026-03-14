import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

export const CONFIG = {
  xaiApiKey: process.env.XAI_API_KEY || '',
  veniceApiKey: process.env.VENICE_API_KEY || '',
  redditClientId: process.env.REDDIT_CLIENT_ID || '',
  redditClientSecret: process.env.REDDIT_CLIENT_SECRET || '',
  xBearerToken: process.env.X_BEARER_TOKEN || '',

  outputDir: path.resolve(__dirname, '..', 'output'),
  cacheDir: path.resolve(__dirname, '..', 'cache'),
  dbPath: path.resolve(__dirname, '..', 'cache', 'clips.db'),

  video: {
    width: 1080,
    height: 1920,
    captionBarRatio: 0.25,
    fps: 30,
    maxDurationSec: 60,
    clipMinSec: 5,
    clipMaxSec: 15,
  },

  llm: {
    model: 'grok-4.20-beta-latest-non-reasoning',
    captionModel: 'grok-4.20-beta-0309-reasoning',
    visionModel: 'grok-4-0709',
    baseUrl: 'https://api.x.ai/v1',
    maxTokens: 1024,
    captionTemperature: 1.2,
    sceneTemperature: 0.5,
    verifyMinScore: 6,
  },

  venice: {
    model: 'hermes-3-llama-3.1-405b',
    baseUrl: 'https://api.venice.ai/api/v1',
    maxTokens: 4096,
    temperature: 1.0,
  },

  virality: {
    minScore: 80,
    maxAttempts: 10,
    shipItOverride: true,
  },

  youtube: {
    clientId: process.env.GOOGLE_CLIENT_ID || '',
    clientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
    tokenKey: process.env.YOUTUBE_TOKEN_KEY || '',
  },
} as const;
