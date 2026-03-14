import { execSync, execFileSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import Database from 'better-sqlite3';
import { v4 as uuidv4 } from 'uuid';
import { CONFIG } from './config';
import { verifyClip } from './clip-verifier';
import type { SceneMatch, CachedClip, Caption } from './types';

let db: Database.Database | null = null;

function getDb(): Database.Database {
  if (db) return db;
  fs.mkdirSync(CONFIG.cacheDir, { recursive: true });
  db = new Database(CONFIG.dbPath);
  db.exec(`
    CREATE TABLE IF NOT EXISTS clips (
      id TEXT PRIMARY KEY,
      filePath TEXT NOT NULL,
      sourceUrl TEXT NOT NULL,
      videoId TEXT NOT NULL,
      movieTitle TEXT NOT NULL,
      character TEXT NOT NULL,
      emotion TEXT NOT NULL,
      mood TEXT NOT NULL,
      durationSec REAL NOT NULL,
      createdAt TEXT NOT NULL,
      verifiedDescription TEXT DEFAULT '',
      verifyScore INTEGER DEFAULT 0
    )
  `);
  try {
    db.exec(`ALTER TABLE clips ADD COLUMN verifiedDescription TEXT DEFAULT ''`);
  } catch {}
  try {
    db.exec(`ALTER TABLE clips ADD COLUMN verifyScore INTEGER DEFAULT 0`);
  } catch {}
  return db;
}

function findCachedClip(scene: SceneMatch): (CachedClip & { verifyScore: number }) | null {
  const db = getDb();
  const row = db
    .prepare('SELECT * FROM clips WHERE movieTitle = ? AND character = ? ORDER BY verifyScore DESC LIMIT 1')
    .get(scene.movieTitle, scene.character) as (CachedClip & { verifyScore: number }) | undefined;

  if (row && fs.existsSync(row.filePath)) {
    console.log(`[ClipAcquisition] Cache hit: ${row.movieTitle} - ${row.character} (score: ${row.verifyScore}/10)`);
    return row;
  }
  return null;
}

export function findHighScoreClips(minScore: number = 8): Array<CachedClip & { verifyScore: number }> {
  const db = getDb();
  const rows = db
    .prepare('SELECT * FROM clips WHERE verifyScore >= ? ORDER BY verifyScore DESC LIMIT 20')
    .all(minScore) as Array<CachedClip & { verifyScore: number }>;

  return rows.filter(r => fs.existsSync(r.filePath));
}

function searchYouTubeMultiple(keywords: string[], maxResults: number = 3): string[] {
  const query = keywords.join(' ');
  try {
    const result = execFileSync('yt-dlp', [
      '--default-search', `ytsearch${maxResults + 2}`,
      '--get-id',
      '--no-playlist',
      '--match-filter', 'duration < 300',
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
  } catch (err) {
    console.warn(`[ClipAcquisition] Download failed: ${err}`);
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

function trimClip(inputPath: string, outputPath: string, maxDuration: number): boolean {
  const duration = getVideoDuration(inputPath);
  const clipDuration = Math.min(duration, maxDuration);
  const startTime = duration > maxDuration
    ? Math.floor(Math.random() * (duration - maxDuration))
    : 0;

  try {
    execFileSync('ffmpeg', [
      '-y',
      '-ss', startTime.toString(),
      '-i', inputPath,
      '-t', clipDuration.toString(),
      '-map_metadata', '-1',
      '-fflags', '+bitexact',
      '-flags:v', '+bitexact',
      '-flags:a', '+bitexact',
      '-c:v', 'libx264',
      '-c:a', 'aac',
      '-movflags', '+faststart',
      outputPath,
    ], { encoding: 'utf-8', timeout: 60000 });
    return fs.existsSync(outputPath);
  } catch {
    return false;
  }
}

/**
 * Acquires a video clip matching the scene description.
 * Downloads candidates, verifies with vision model, rejects bad matches.
 */
export async function acquireClip(scene: SceneMatch, caption?: Caption): Promise<string> {
  console.log(`[ClipAcquisition] Acquiring clip for: ${scene.movieTitle} - ${scene.momentDescription}`);

  const cached = findCachedClip(scene);
  if (cached && cached.verifyScore >= CONFIG.llm.verifyMinScore) {
    return cached.filePath;
  }

  const searchSets = [
    scene.searchKeywords,
    [`${scene.movieTitle} ${scene.character} scene clip`],
    [`${scene.movieTitle} ${scene.momentDescription.split(' ').slice(0, 5).join(' ')} scene`],
    [`${scene.movieTitle} best scene clip`],
  ];

  if (scene.alternatives?.length) {
    for (const alt of scene.alternatives) {
      searchSets.push(alt.searchKeywords);
      searchSets.push([`${alt.movieTitle} ${alt.character} scene clip`]);
    }
  }

  const triedUrls = new Set<string>();
  const MAX_ATTEMPTS = 3;
  let attempts = 0;

  for (const keywords of searchSets) {
    if (attempts >= MAX_ATTEMPTS) break;
    if (!keywords?.length) continue;

    const urls = searchYouTubeMultiple(keywords, 3);
    for (const downloadUrl of urls) {
      if (attempts >= MAX_ATTEMPTS) break;
      if (triedUrls.has(downloadUrl)) continue;
      triedUrls.add(downloadUrl);
      attempts++;

      const clipId = uuidv4();
      const rawPath = path.join(CONFIG.cacheDir, `raw_${clipId}.mp4`);
      const trimmedPath = path.join(CONFIG.cacheDir, `${clipId}.mp4`);

      const downloaded = downloadClip(downloadUrl, rawPath);
      if (!downloaded) continue;

      const trimmed = trimClip(rawPath, trimmedPath, CONFIG.video.clipMaxSec);
      const finalPath = trimmed ? trimmedPath : rawPath;

      if (trimmed && rawPath !== trimmedPath && fs.existsSync(rawPath)) {
        fs.unlinkSync(rawPath);
      }

      if (caption) {
        const result = await verifyClip(finalPath, caption, scene);

        if (result.verdict === 'reject') {
          console.log(`[ClipAcquisition] Clip rejected (${result.score}/10), trying next...`);
          try { fs.unlinkSync(finalPath); } catch {}
          continue;
        }

        const duration = getVideoDuration(finalPath);
        const db = getDb();
        db.prepare(`
          INSERT INTO clips (id, filePath, sourceUrl, videoId, movieTitle, character, emotion, mood, durationSec, createdAt, verifiedDescription, verifyScore)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(clipId, finalPath, downloadUrl, clipId, scene.movieTitle, scene.character, scene.emotion, scene.emotion, duration, new Date().toISOString(), result.clipDescription, result.score);

        console.log(`[ClipAcquisition] Verified clip: ${scene.movieTitle} (${result.score}/10, ${duration}s)`);
        return finalPath;
      }

      const duration = getVideoDuration(finalPath);
      const db = getDb();
      db.prepare(`
        INSERT INTO clips (id, filePath, sourceUrl, videoId, movieTitle, character, emotion, mood, durationSec, createdAt, verifiedDescription, verifyScore)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(clipId, finalPath, downloadUrl, clipId, scene.movieTitle, scene.character, scene.emotion, scene.emotion, duration, new Date().toISOString(), '', 0);

      console.log(`[ClipAcquisition] Cached clip (unverified): ${scene.movieTitle} (${duration}s)`);
      return finalPath;
    }
  }

  throw new Error(`[ClipAcquisition] Could not find a suitable clip for: ${scene.movieTitle} after ${attempts} attempts`);
}
