/**
 * Daily AI news digest: aggregate stories, rank for "at-home programmer" usefulness,
 * post to Discord. Uses xAI Grok when XAI_API_KEY is set; otherwise heuristic ranking.
 */

import cron from "node-cron";
import { EmbedBuilder } from "discord.js";

const UA = "PaperclipDiscordBot/1.0 (AI news digest; +https://github.com/paperclipai/paperclip)";

/** Discord embed descriptions are plain text — HTML tags show literally; strip them. */
function stripHtmlPlainText(s) {
  if (s == null || s === "") return "";
  let t = String(s);
  t = t.replace(/<br\s*\/?>/gi, " ");
  t = t.replace(/<\/(p|div|h[1-6]|li|tr)>/gi, " ");
  t = t.replace(/<[^>]+>/g, "");
  t = t
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)));
  return t.replace(/\s+/g, " ").trim();
}

/** @param {string} url */
async function fetchJson(url, timeoutMs = 15000) {
  const ac = new AbortController();
  const tid = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(url, { headers: { "User-Agent": UA }, signal: ac.signal });
    if (!res.ok) throw new Error(`${url} → ${res.status}`);
    return res.json();
  } finally {
    clearTimeout(tid);
  }
}

function since24h() {
  return Math.floor(Date.now() / 1000) - 86400;
}

/**
 * @returns {Promise<Array<{ title: string, url: string, source: string, snippet: string }>>}
 */
async function fetchHackerNewsCandidates() {
  const ts = since24h();
  const queries = [
    "AI OR LLM OR Claude OR OpenAI",
    "Cursor OR VS Code OR GitHub Copilot",
    "Ollama OR local model OR open weights",
    "API SDK developer",
  ];
  const out = [];
  const seen = new Set();
  const batches = await Promise.all(
    queries.map(async (q) => {
      const enc = encodeURIComponent(q);
      const url = `https://hn.algolia.com/api/v1/search?tags=story&numericFilters=created_at_i>${ts}&query=${enc}&hitsPerPage=12`;
      try {
        return await fetchJson(url);
      } catch (e) {
        console.warn(`[ai-news] HN query failed (${q}):`, e.message);
        return { hits: [] };
      }
    }),
  );
  for (const data of batches) {
    for (const hit of data.hits || []) {
      const u = hit.url || `https://news.ycombinator.com/item?id=${hit.objectID}`;
      if (seen.has(u)) continue;
      seen.add(u);
      out.push({
        title: hit.title || "Untitled",
        url: u,
        source: "Hacker News",
        snippet: (hit.story_text || "").slice(0, 400),
      });
    }
  }
  return out;
}

/**
 * @returns {Promise<Array<{ title: string, url: string, source: string, snippet: string }>>}
 */
async function fetchRedditCandidates() {
  const subs = ["LocalLLaMA", "MachineLearning", "technology", "programming"];
  const seen = new Set();
  const batches = await Promise.all(
    subs.map(async (sub) => {
      const url = `https://www.reddit.com/r/${sub}/top.json?t=day&limit=12`;
      try {
        return { sub, data: await fetchJson(url) };
      } catch (e) {
        console.warn(`[ai-news] Reddit r/${sub} failed:`, e.message);
        return { sub, data: null };
      }
    }),
  );
  const out = [];
  for (const { sub, data } of batches) {
    if (!data) continue;
    const children = data?.data?.children || [];
    for (const c of children) {
      const p = c.data;
      if (!p?.title || p.stickied) continue;
      const u = `https://reddit.com${p.permalink}`;
      if (seen.has(u)) continue;
      seen.add(u);
      out.push({
        title: p.title,
        url: u,
        source: `r/${sub}`,
        snippet: (p.selftext || "").slice(0, 400),
      });
    }
  }
  return out;
}

function normalizeUrl(u) {
  try {
    const x = new URL(u);
    x.hash = "";
    return x.toString();
  } catch {
    return u;
  }
}

function dedupe(items) {
  const seen = new Set();
  const out = [];
  for (const it of items) {
    const k = normalizeUrl(it.url);
    if (seen.has(k)) continue;
    seen.add(k);
    out.push(it);
  }
  return out;
}

const HOME_DEV_BOOST = [
  /\b(cursor|vscode|vs code|github copilot|copilot|jetbrains|zed editor|neovim)\b/i,
  /\b(api|sdk|cli|npm|pypi|library|open.source|open-source|github)\b/i,
  /\b(ollama|llama\.cpp|mlx|gguf|quantized|local llm|on.device|on-device)\b/i,
  /\b(fine-?tun|lora|adapter|hugging\s*face|transformers)\b/i,
  /\b(agent|automation|workflow|mcp|plugin|extension)\b/i,
  /\b(anthropic|openai|google ai|gemini|mistral|deepseek)\b.*\b(api|release|model)\b/i,
];

const HOME_DEV_PENALTY = [
  /\b(dna|genome|protein|clinical|patient|drug discovery|crispr)\b/i,
  /\b(quantum computing|fusion reactor|particle)\b/i,
  /\b(defense contract|pentagon|classified)\b/i,
  /\b(paper:|arxiv:|survey:|state of the art)\b.*\b(theoretic)\b/i,
];

function heuristicScore(item) {
  const text = `${item.title} ${item.snippet}`;
  let s = 5;
  for (const re of HOME_DEV_BOOST) {
    if (re.test(text)) s += 1.2;
  }
  for (const re of HOME_DEV_PENALTY) {
    if (re.test(text)) s -= 2;
  }
  if (item.source.startsWith("r/LocalLLaMA")) s += 1.5;
  return s;
}

/**
 * @param {Array<{ title: string, url: string, source: string, snippet: string }>} candidates
 * @param {string} apiKey
 */
async function rankWithGrok(candidates, apiKey) {
  const trimmed = candidates.slice(0, 45).map((c, i) => ({
    i,
    title: c.title,
    url: c.url,
    source: c.source,
    snippet: c.snippet?.slice(0, 200) || "",
  }));

  const system = `You pick the 10 best AI-related news items for an independent developer working from home with a normal PC and internet.
Prioritize (higher): practical tools, APIs/SDKs, IDE & coding assistants, open-weight or local models, something they can try today, shipping/product news relevant to builders.
Deprioritize (lower): pure lab research they cannot reproduce, biotech/genetics, enterprise-only deals, vague hype without actionable detail.
Return ONLY valid JSON: {"items":[{"title":"short headline","summary":"1-2 sentences","url":"...","accessibilityRank":1}]}
accessibilityRank 1 = most useful from home today, 10 = still worth knowing but less actionable.
Include exactly 10 items if possible; if fewer strong matches, include fewer (minimum 5 if candidates exist). Order items by accessibilityRank ascending (best first). Use the provided URLs exactly.
IMPORTANT: In "title" and "summary" use plain text only. Do not use HTML tags (<p>, <br>, etc.) or markdown — the output goes to Discord plain text.`;

  const user = `Candidates (JSON):\n${JSON.stringify(trimmed)}`;

  // Default: fast non-reasoning (see https://docs.x.ai/docs/models); override with XAI_MODEL if needed.
  const model = process.env.XAI_MODEL || "grok-4-1-fast-non-reasoning";

  const res = await fetch("https://api.x.ai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.3,
      max_tokens: 4096,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`xAI ${res.status}: ${err.slice(0, 300)}`);
  }

  const data = await res.json();
  const raw = data.choices?.[0]?.message?.content?.trim() || "";
  const jsonMatch = raw.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error("No JSON in Grok response");
  const parsed = JSON.parse(jsonMatch[0]);
  const items = parsed.items || [];
  return items.map((x) => ({
    title: stripHtmlPlainText(String(x.title || "")).slice(0, 200),
    summary: stripHtmlPlainText(String(x.summary || "")).slice(0, 400),
    url: String(x.url || ""),
    accessibilityRank: Number(x.accessibilityRank) || 5,
  }));
}

function rankHeuristic(candidates) {
  const scored = candidates
    .map((c) => ({ ...c, _score: heuristicScore(c) }))
    .sort((a, b) => b._score - a._score)
    .slice(0, 10);

  return scored.map((c, idx) => ({
    title: stripHtmlPlainText(c.title).slice(0, 200),
    summary: c.snippet
      ? stripHtmlPlainText(c.snippet).slice(0, 280) || "See link for details."
      : "See link for details.",
    url: c.url,
    accessibilityRank: idx + 1,
  }));
}

/** Discord markdown: **bold** titles; body is plain (no HTML — it is not rendered). */
function formatStoryLine(it, index0) {
  const title = stripHtmlPlainText(it.title).replace(/\*\*/g, "");
  const sum = stripHtmlPlainText(it.summary).replace(/\n/g, " ");
  return `**${index0 + 1}.** **${title}**\n${sum}\n${it.url}\n`;
}

function buildDiscordContent(items) {
  const lines = items.map((it, i) => formatStoryLine(it, i));
  return `**Daily AI news** — ordered for **at-home builders** (most actionable first).\n\n${lines.join("\n")}`;
}

/**
 * @param {import('discord.js').TextChannel} channel
 */
export async function postAiNewsDigest(channel) {
  try {
    await postAiNewsDigestInner(channel);
  } catch (e) {
    console.error("[ai-news] Digest failed:", e);
    try {
      await channel.send(`**AI news digest** failed: ${e.message || String(e)}`);
    } catch { /* ignore */ }
    throw e;
  }
}

async function postAiNewsDigestInner(channel) {
  const apiKey = process.env.XAI_API_KEY || process.env.GROK_API_KEY;

  console.log("[ai-news] Fetching Hacker News + Reddit…");
  const [hn, reddit] = await Promise.all([fetchHackerNewsCandidates(), fetchRedditCandidates()]);
  console.log(`[ai-news] Raw: ${hn.length} HN, ${reddit.length} Reddit`);
  let candidates = dedupe([...hn, ...reddit]);

  if (candidates.length < 5) {
    console.warn("[ai-news] Few candidates; broadening HN search without strict time filter");
    try {
      const url =
        "https://hn.algolia.com/api/v1/search?tags=story&query=" +
        encodeURIComponent("AI OR LLM OR OpenAI OR Anthropic") +
        "&hitsPerPage=20";
      const data = await fetchJson(url);
      for (const hit of data.hits || []) {
        const u = hit.url || `https://news.ycombinator.com/item?id=${hit.objectID}`;
        candidates.push({
          title: hit.title || "Untitled",
          url: u,
          source: "Hacker News",
          snippet: (hit.story_text || "").slice(0, 400),
        });
      }
      candidates = dedupe(candidates);
    } catch (e) {
      console.warn("[ai-news] Fallback HN failed:", e.message);
    }
  }

  let items;
  if (apiKey) {
    try {
      items = await rankWithGrok(candidates, apiKey);
    } catch (e) {
      console.error("[ai-news] Grok failed, using heuristic:", e.message);
      items = rankHeuristic(candidates);
    }
  } else {
    console.warn("[ai-news] XAI_API_KEY not set — using heuristic ranking (set XAI_API_KEY for Grok).");
    items = rankHeuristic(candidates);
  }

  if (!items.length) {
    await channel.send("**AI news digest** — Could not gather stories today. Try again tomorrow.");
    console.log("[ai-news] No items to post.");
    return;
  }

  console.log(`[ai-news] Posting ${items.length} stories to Discord…`);
  const full = buildDiscordContent(items);
  const embed = new EmbedBuilder()
    .setColor(0x5865f2)
    .setTitle("📰 Top AI stories for home developers")
    .setDescription(full.length > 4096 ? full.slice(0, 4080) + "…" : full)
    .setFooter({
      text: apiKey
        ? "Ranked with Grok (xAI) · Sources: HN, Reddit"
        : "Heuristic ranking · Sources: HN, Reddit · set XAI_API_KEY for Grok",
    })
    .setTimestamp();

  if (full.length <= 4096) {
    await channel.send({ embeds: [embed] });
    console.log("[ai-news] Digest posted (single embed).");
    return;
  }

  // Split long content into chunks (Discord embed description max 4096)
  const chunks = [];
  let buf = `**Daily AI news** — ordered for **at-home builders**.\n\n`;
  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    const block = `${formatStoryLine(it, i)}\n`;
    if (buf.length + block.length > 3800) {
      chunks.push(buf);
      buf = block;
    } else {
      buf += block;
    }
  }
  if (buf) chunks.push(buf);
  for (let i = 0; i < chunks.length; i++) {
    const e = new EmbedBuilder()
      .setColor(0x5865f2)
      .setTitle(i === 0 ? "📰 Top AI stories for home developers" : "(continued)")
      .setDescription(chunks[i])
      .setTimestamp();
    await channel.send({ embeds: [e] });
  }
  console.log("[ai-news] Digest posted (split embeds).");
}

/**
 * @param {import('discord.js').Client} client
 * @param {string} channelId
 */
export function scheduleAiNewsDigest(client, channelId) {
  const tz = process.env.DISCORD_AI_NEWS_TIMEZONE || "America/New_York";
  const cronExpr = process.env.DISCORD_AI_NEWS_CRON || "0 18 * * *";
  const runAtStart = process.env.DISCORD_AI_NEWS_RUN_AT_START === "true";

  const job = cron.schedule(
    cronExpr,
    async () => {
      try {
        const ch = await client.channels.fetch(channelId);
        if (!ch || !ch.isTextBased()) {
          console.error("[ai-news] Invalid channel:", channelId);
          return;
        }
        console.log("[ai-news] Running scheduled digest...");
        await postAiNewsDigest(ch);
        console.log("[ai-news] Digest posted.");
      } catch (e) {
        console.error("[ai-news] Scheduled run failed:", e);
      }
    },
    { timezone: tz },
  );

  console.log(`[ai-news] Scheduled digest: ${cronExpr} (${tz}) → channel ${channelId}`);

  if (runAtStart) {
    setTimeout(async () => {
      try {
        const ch = await client.channels.fetch(channelId);
        if (ch?.isTextBased()) {
          console.log("[ai-news] Running digest (DISCORD_AI_NEWS_RUN_AT_START)...");
          await postAiNewsDigest(ch);
        }
      } catch (e) {
        console.error("[ai-news] Run-at-start failed:", e);
      }
    }, 8000);
  }

  return job;
}
