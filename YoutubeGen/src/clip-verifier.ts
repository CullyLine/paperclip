import OpenAI from 'openai';
import { execFileSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { CONFIG } from './config';
import type { Caption, SceneMatch } from './types';

const VERIFY_PROMPT = `You are judging whether a video clip works as a match for a YouTube Shorts caption.

The format: black bar on top with white text caption, video clip playing underneath. The humor comes from the connection between the caption and what's happening in the clip.

You are looking at frames extracted from a candidate clip. You need to:

1. Describe what is happening in the clip (people, actions, expressions, setting, any visible text/overlays)
2. Judge how well it pairs with the caption
3. Score it 1-10

## IMPORTANT: Two Modes of Matching

### Movie/TV clips:
Judge by how CLEVERLY the scene creates a visual metaphor or ironic parallel with the caption.

### Twitch/Streamer clips (if the intended source mentions a streamer name like xQc, Forsen, Tyler1, Kai Cenat, etc.):
Be MORE LENIENT. For streamer clips, what matters is:
- Does the clip show a person (ideally a streamer) in a setting that VIBES with the caption?
- Does their expression, body language, or energy match the caption's mood?
- Would this clip be funny underneath the caption even if it's not the EXACT moment described?
- A streamer sitting at their desk, reacting, raging, staring blankly, laughing — any of these can work if the ENERGY matches.
- You do NOT need to identify the specific streamer. If you see someone at a gaming setup reacting in a way that fits the caption, that's a match.

## Scoring Guide:
- 1-3: Completely wrong content (e.g. a nature documentary when you need a person reacting)
- 4-5: Shows a person but the energy/mood is totally wrong for the caption
- 6-7: Right vibe — a person reacting/expressing something that works with the caption
- 8-9: Excellent match — the reaction, setting, and energy amplify the caption perfectly
- 10: God-tier — the clip makes the caption 10x funnier

## Output Format

Return a JSON object:
- "clip_description": string (what you see happening in these frames)
- "connection_analysis": string (how/if the clip connects to the caption)
- "score": number (1-10)
- "verdict": "accept" | "reject" (accept if score >= 6)
- "suggestion": string (if rejecting, what kind of scene would work better)`;

interface VerifyResult {
  clipDescription: string;
  connectionAnalysis: string;
  score: number;
  verdict: 'accept' | 'reject';
  suggestion: string;
}

function extractFrames(videoPath: string, count: number = 4): string[] {
  const duration = getClipDuration(videoPath);
  const framePaths: string[] = [];
  const dir = path.dirname(videoPath);
  const base = path.basename(videoPath, path.extname(videoPath));

  for (let i = 0; i < count; i++) {
    const time = (duration / (count + 1)) * (i + 1);
    const framePath = path.join(dir, `${base}_verify_${i}.jpg`);

    try {
      execFileSync('ffmpeg', [
        '-y',
        '-ss', time.toFixed(2),
        '-i', videoPath,
        '-frames:v', '1',
        '-q:v', '3',
        '-update', '1',
        framePath,
      ], { encoding: 'utf-8', timeout: 10000 });

      if (fs.existsSync(framePath)) {
        framePaths.push(framePath);
      }
    } catch {
      // skip this frame
    }
  }

  return framePaths;
}

function getClipDuration(filePath: string): number {
  try {
    const result = execFileSync('ffprobe', [
      '-v', 'quiet',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      filePath,
    ], { encoding: 'utf-8', timeout: 10000 });
    return parseFloat(result.trim()) || 10;
  } catch {
    return 10;
  }
}

function frameToBase64(framePath: string): string {
  const buffer = fs.readFileSync(framePath);
  return buffer.toString('base64');
}

function cleanupFrames(framePaths: string[]): void {
  for (const p of framePaths) {
    try { fs.unlinkSync(p); } catch {}
  }
}

export async function verifyClip(
  clipPath: string,
  caption: Caption,
  scene: SceneMatch,
): Promise<VerifyResult> {
  console.log(`[Verifier] Analyzing clip for: "${caption.text.slice(0, 50)}..."`);

  if (!CONFIG.xaiApiKey) {
    console.warn('[Verifier] No API key, auto-accepting');
    return { clipDescription: '', connectionAnalysis: '', score: 7, verdict: 'accept', suggestion: '' };
  }

  const framePaths = extractFrames(clipPath, 4);
  if (framePaths.length === 0) {
    console.warn('[Verifier] Could not extract frames, auto-accepting');
    return { clipDescription: '', connectionAnalysis: '', score: 5, verdict: 'reject', suggestion: 'Could not analyze clip' };
  }

  const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });

  const imageContent = framePaths.map((fp) => ({
    type: 'image_url' as const,
    image_url: { url: `data:image/jpeg;base64,${frameToBase64(fp)}` },
  }));

  try {
    const response = await grok.chat.completions.create({
      model: CONFIG.llm.visionModel,
      max_tokens: CONFIG.llm.maxTokens,
      temperature: 0.3,
      messages: [
        { role: 'system', content: VERIFY_PROMPT },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: `Caption: "${caption.text}"\nMood: ${caption.mood}\nIntended scene: ${scene.movieTitle} — ${scene.momentDescription}\nWhy it should be clever: ${scene.emotionalMatch}\n\nHere are ${framePaths.length} frames from the candidate clip. Judge how well this clip works:`,
            },
            ...imageContent,
          ],
        },
      ],
      response_format: { type: 'json_object' },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) {
      cleanupFrames(framePaths);
      return { clipDescription: '', connectionAnalysis: '', score: 5, verdict: 'reject', suggestion: 'No response from vision model' };
    }

    const parsed = JSON.parse(content);
    const result: VerifyResult = {
      clipDescription: parsed.clip_description || '',
      connectionAnalysis: parsed.connection_analysis || '',
      score: parsed.score ?? 5,
      verdict: (parsed.score ?? 5) >= CONFIG.llm.verifyMinScore ? 'accept' : 'reject',
      suggestion: parsed.suggestion || '',
    };

    const emoji = result.verdict === 'accept' ? '✓' : '✗';
    console.log(`[Verifier] ${emoji} Score: ${result.score}/10 — ${result.connectionAnalysis.slice(0, 80)}`);
    if (result.verdict === 'reject' && result.suggestion) {
      console.log(`[Verifier] Suggestion: ${result.suggestion.slice(0, 100)}`);
    }

    cleanupFrames(framePaths);
    return result;
  } catch (err: any) {
    console.warn(`[Verifier] Vision analysis failed: ${err.message}`);
    cleanupFrames(framePaths);
    return { clipDescription: '', connectionAnalysis: '', score: 5, verdict: 'reject', suggestion: `Vision error: ${err.message}` };
  }
}
