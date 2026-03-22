/**
 * Model pricing table for server-side cost estimation.
 * Used as fallback when adapters don't report cost (e.g., Cursor CLI).
 * Prices are per 1M tokens in USD.
 */

export interface ModelPricing {
  inputPerMillion: number;
  cachedInputPerMillion: number;
  outputPerMillion: number;
}

const PRICING_TABLE: Record<string, ModelPricing> = {
  // Claude models
  "claude-sonnet-4-20250514": { inputPerMillion: 3, cachedInputPerMillion: 0.3, outputPerMillion: 15 },
  "claude-4-sonnet": { inputPerMillion: 3, cachedInputPerMillion: 0.3, outputPerMillion: 15 },
  "claude-3-5-sonnet-20241022": { inputPerMillion: 3, cachedInputPerMillion: 0.3, outputPerMillion: 15 },
  "claude-3-5-sonnet": { inputPerMillion: 3, cachedInputPerMillion: 0.3, outputPerMillion: 15 },
  "claude-3-7-sonnet-20250219": { inputPerMillion: 3, cachedInputPerMillion: 0.3, outputPerMillion: 15 },
  "claude-3.7-sonnet": { inputPerMillion: 3, cachedInputPerMillion: 0.3, outputPerMillion: 15 },
  "claude-3-opus-20240229": { inputPerMillion: 15, cachedInputPerMillion: 1.5, outputPerMillion: 75 },
  "claude-3-opus": { inputPerMillion: 15, cachedInputPerMillion: 1.5, outputPerMillion: 75 },
  "claude-3-haiku-20240307": { inputPerMillion: 0.25, cachedInputPerMillion: 0.025, outputPerMillion: 1.25 },
  "claude-3-haiku": { inputPerMillion: 0.25, cachedInputPerMillion: 0.025, outputPerMillion: 1.25 },
  "claude-3-5-haiku-20241022": { inputPerMillion: 1, cachedInputPerMillion: 0.1, outputPerMillion: 5 },
  "claude-3-5-haiku": { inputPerMillion: 1, cachedInputPerMillion: 0.1, outputPerMillion: 5 },

  // GPT models
  "gpt-4o": { inputPerMillion: 2.5, cachedInputPerMillion: 1.25, outputPerMillion: 10 },
  "gpt-4o-2024-11-20": { inputPerMillion: 2.5, cachedInputPerMillion: 1.25, outputPerMillion: 10 },
  "gpt-4o-mini": { inputPerMillion: 0.15, cachedInputPerMillion: 0.075, outputPerMillion: 0.6 },
  "gpt-4-turbo": { inputPerMillion: 10, cachedInputPerMillion: 5, outputPerMillion: 30 },
  "o1": { inputPerMillion: 15, cachedInputPerMillion: 7.5, outputPerMillion: 60 },
  "o1-mini": { inputPerMillion: 3, cachedInputPerMillion: 1.5, outputPerMillion: 12 },
  "o3-mini": { inputPerMillion: 1.1, cachedInputPerMillion: 0.55, outputPerMillion: 4.4 },

  // Gemini models
  "gemini-2.5-pro": { inputPerMillion: 1.25, cachedInputPerMillion: 0.31, outputPerMillion: 10 },
  "gemini-2.5-flash": { inputPerMillion: 0.15, cachedInputPerMillion: 0.037, outputPerMillion: 0.6 },
  "gemini-2.0-flash": { inputPerMillion: 0.1, cachedInputPerMillion: 0.025, outputPerMillion: 0.4 },
  "gemini-1.5-pro": { inputPerMillion: 1.25, cachedInputPerMillion: 0.31, outputPerMillion: 5 },
  "gemini-1.5-flash": { inputPerMillion: 0.075, cachedInputPerMillion: 0.02, outputPerMillion: 0.3 },

  // Cursor special model names
  "composer-2": { inputPerMillion: 3, cachedInputPerMillion: 0.3, outputPerMillion: 15 },
  "cursor:claude-3-5-sonnet": { inputPerMillion: 3, cachedInputPerMillion: 0.3, outputPerMillion: 15 },
  "cursor:gpt-4o": { inputPerMillion: 2.5, cachedInputPerMillion: 1.25, outputPerMillion: 10 },
};

const DEFAULT_PRICING: ModelPricing = {
  inputPerMillion: 3,
  cachedInputPerMillion: 0.3,
  outputPerMillion: 15,
};

function normalizeModelKey(model: string): string {
  return model.toLowerCase().trim();
}

export function getModelPricing(model: string): ModelPricing {
  const normalized = normalizeModelKey(model);

  if (PRICING_TABLE[normalized]) return PRICING_TABLE[normalized];

  for (const [key, pricing] of Object.entries(PRICING_TABLE)) {
    if (normalized.includes(key) || key.includes(normalized)) {
      return pricing;
    }
  }

  return DEFAULT_PRICING;
}

/**
 * Estimate cost in USD from token counts and model name.
 * Returns null if no tokens are provided.
 */
export function estimateCostUsd(
  model: string,
  inputTokens: number,
  cachedInputTokens: number,
  outputTokens: number,
): number | null {
  if (inputTokens === 0 && outputTokens === 0 && cachedInputTokens === 0) {
    return null;
  }

  const pricing = getModelPricing(model);
  const nonCachedInput = Math.max(0, inputTokens - cachedInputTokens);
  const cost =
    (nonCachedInput / 1_000_000) * pricing.inputPerMillion +
    (cachedInputTokens / 1_000_000) * pricing.cachedInputPerMillion +
    (outputTokens / 1_000_000) * pricing.outputPerMillion;

  return cost;
}
