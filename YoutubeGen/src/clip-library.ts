import { execFileSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';
import { CONFIG } from './config';

export interface LibraryClip {
  id: string;
  filePath: string;
  streamer: string;
  moment: string;
  emotion: string;
  energy: 'low' | 'medium' | 'high' | 'unhinged';
  vibeArchetype: string;
  tags: string[];
  durationSec: number;
  searchQuery: string;
  sourceUrl?: string;
}

const LIBRARY_DIR = path.resolve(CONFIG.cacheDir, 'library');
const LIBRARY_INDEX = path.resolve(LIBRARY_DIR, 'index.json');

function ensureLibraryDir(): void {
  fs.mkdirSync(LIBRARY_DIR, { recursive: true });
}

export function loadLibrary(): LibraryClip[] {
  ensureLibraryDir();
  if (!fs.existsSync(LIBRARY_INDEX)) return [];
  try {
    return JSON.parse(fs.readFileSync(LIBRARY_INDEX, 'utf-8'));
  } catch {
    return [];
  }
}

function saveLibrary(clips: LibraryClip[]): void {
  ensureLibraryDir();
  fs.writeFileSync(LIBRARY_INDEX, JSON.stringify(clips, null, 2));
}

function searchYouTube(query: string, maxResults: number = 5): string[] {
  try {
    const result = execFileSync('yt-dlp', [
      '--default-search', `ytsearch${maxResults}`,
      '--get-id',
      '--no-playlist',
      '--match-filter', 'duration < 120',
      query,
    ], { encoding: 'utf-8', timeout: 30000 });

    return result.trim().split('\n')
      .filter(id => id.trim().length === 11)
      .slice(0, maxResults)
      .map(id => `https://www.youtube.com/watch?v=${id.trim()}`);
  } catch {
    return [];
  }
}

function downloadClip(url: string, outputPath: string): boolean {
  try {
    execFileSync('yt-dlp', [
      '-f', 'bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720]/best',
      '--merge-output-format', 'mp4',
      '--no-playlist',
      '-o', outputPath,
      url,
    ], { encoding: 'utf-8', timeout: 120000 });
    return fs.existsSync(outputPath);
  } catch {
    return false;
  }
}

function getVideoDuration(filePath: string): number {
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

function trimToMax(inputPath: string, outputPath: string, maxSec: number): boolean {
  const duration = getVideoDuration(inputPath);
  if (duration <= maxSec) {
    fs.copyFileSync(inputPath, outputPath);
    return true;
  }
  const start = Math.floor(Math.random() * Math.max(0, duration - maxSec));
  try {
    execFileSync('ffmpeg', [
      '-y', '-ss', start.toString(), '-i', inputPath,
      '-t', maxSec.toString(),
      '-c:v', 'libx264', '-c:a', 'aac', '-movflags', '+faststart',
      outputPath,
    ], { encoding: 'utf-8', timeout: 60000 });
    return fs.existsSync(outputPath);
  } catch {
    return false;
  }
}

export interface ClipSpec {
  streamer: string;
  moment: string;
  emotion: string;
  energy: 'low' | 'medium' | 'high' | 'unhinged';
  vibeArchetype: string;
  tags: string[];
  searchQuery: string;
}

export async function acquireLibraryClip(spec: ClipSpec): Promise<LibraryClip | null> {
  ensureLibraryDir();
  console.log(`[Library] Searching for: ${spec.streamer} — ${spec.moment}`);

  const urls = searchYouTube(spec.searchQuery, 5);
  if (urls.length === 0) {
    console.log(`[Library] No results for: ${spec.searchQuery}`);
    return null;
  }

  for (const url of urls) {
    const clipId = uuidv4();
    const rawPath = path.join(LIBRARY_DIR, `raw_${clipId}.mp4`);
    const finalPath = path.join(LIBRARY_DIR, `${clipId}.mp4`);

    console.log(`[Library] Downloading: ${url}`);
    if (!downloadClip(url, rawPath)) continue;

    const trimmed = trimToMax(rawPath, finalPath, CONFIG.video.clipMaxSec);
    if (trimmed && rawPath !== finalPath && fs.existsSync(rawPath)) {
      try { fs.unlinkSync(rawPath); } catch {}
    }
    const usePath = trimmed ? finalPath : rawPath;

    const duration = getVideoDuration(usePath);
    const clip: LibraryClip = {
      id: clipId,
      filePath: usePath,
      streamer: spec.streamer,
      moment: spec.moment,
      emotion: spec.emotion,
      energy: spec.energy,
      vibeArchetype: spec.vibeArchetype,
      tags: spec.tags,
      durationSec: duration,
      searchQuery: spec.searchQuery,
      sourceUrl: url,
    };

    const library = loadLibrary();
    library.push(clip);
    saveLibrary(library);

    console.log(`[Library] Added: ${spec.streamer} — ${spec.moment} (${duration.toFixed(1)}s)`);
    return clip;
  }

  console.log(`[Library] Failed to acquire clip for: ${spec.streamer}`);
  return null;
}

export function listLibrary(): void {
  const clips = loadLibrary();
  if (clips.length === 0) {
    console.log('  Library is empty.\n');
    return;
  }
  for (const c of clips) {
    const exists = fs.existsSync(c.filePath) ? '✓' : '✗';
    console.log(`  ${exists} [${c.id.slice(0, 8)}] ${c.streamer} — ${c.moment}`);
    console.log(`    ${c.vibeArchetype} | ${c.emotion} | ${c.energy} | ${c.durationSec.toFixed(1)}s`);
    console.log(`    Tags: ${c.tags.join(', ')}`);
    console.log('');
  }
}
