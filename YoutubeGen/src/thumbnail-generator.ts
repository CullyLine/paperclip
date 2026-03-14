import { execFileSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import sharp from 'sharp';
import { CONFIG } from './config';
import type { Caption } from './types';

/**
 * Extracts a frame from the video at a visually interesting point
 * (1/3 through the clip tends to have good expressions).
 */
function extractFrame(videoPath: string, outputPath: string): void {
  let duration = 10;
  try {
    const probe = execFileSync('ffprobe', [
      '-v', 'quiet',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      videoPath,
    ], { encoding: 'utf-8', timeout: 10000 });
    duration = parseFloat(probe.trim()) || 10;
  } catch {}

  const seekTime = Math.max(0.5, duration / 3);

  execFileSync('ffmpeg', [
    '-y',
    '-ss', seekTime.toString(),
    '-i', videoPath,
    '-vframes', '1',
    '-q:v', '2',
    outputPath,
  ], { encoding: 'utf-8', timeout: 15000 });
}

/**
 * Generates a YouTube-optimized thumbnail.
 * Extracts a frame from the clip, adds caption text overlay.
 */
export async function generateThumbnail(
  clipPath: string,
  caption: Caption,
  outputName: string
): Promise<string> {
  console.log(`[Thumbnail] Generating thumbnail for: "${caption.text.slice(0, 50)}..."`);

  fs.mkdirSync(CONFIG.outputDir, { recursive: true });

  const framePath = path.join(CONFIG.cacheDir, `frame_${outputName}.jpg`);
  const outputPath = path.join(CONFIG.outputDir, `${outputName}_thumb.png`);

  extractFrame(clipPath, framePath);

  if (!fs.existsSync(framePath)) {
    throw new Error(`[Thumbnail] Frame extraction failed for: ${clipPath}`);
  }

  const thumbWidth = 1080;
  const thumbHeight = 1920;
  const barHeight = Math.round(thumbHeight * 0.25);
  const clipAreaHeight = thumbHeight - barHeight;

  const clipFrame = await sharp(framePath)
    .resize(thumbWidth, clipAreaHeight, { fit: 'cover', position: 'centre' })
    .toBuffer();

  const fontSize = Math.min(64, Math.max(48, Math.floor(thumbWidth / (caption.text.length * 0.55))));
  const lines = wrapTextForSvg(caption.text, Math.floor(thumbWidth / (fontSize * 0.6)));

  const lineHeight = fontSize + 10;
  const totalTextHeight = lines.length * lineHeight;
  const textStartY = Math.round((barHeight - totalTextHeight) / 2) + fontSize;

  const textElements = lines
    .map((line, i) => {
      const y = textStartY + i * lineHeight;
      const escaped = line.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
      return `<text x="50%" y="${y}" text-anchor="middle" font-family="Arial, sans-serif" font-size="${fontSize}" font-weight="bold" fill="white">${escaped}</text>`;
    })
    .join('');

  const svgOverlay = Buffer.from(
    `<svg width="${thumbWidth}" height="${barHeight}">${textElements}</svg>`
  );

  const blackBar = await sharp({
    create: { width: thumbWidth, height: barHeight, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 255 } },
  })
    .composite([{ input: svgOverlay, top: 0, left: 0 }])
    .png()
    .toBuffer();

  await sharp({
    create: { width: thumbWidth, height: thumbHeight, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 255 } },
  })
    .composite([
      { input: blackBar, top: 0, left: 0 },
      { input: clipFrame, top: barHeight, left: 0 },
    ])
    .png({ effort: 6 })
    .withMetadata({})
    .toFile(outputPath);

  try {
    if (fs.existsSync(framePath)) fs.unlinkSync(framePath);
  } catch {
    // Windows may hold a lock on the file briefly; ignore cleanup failure
  }

  console.log(`[Thumbnail] Saved: ${outputPath}`);
  return outputPath;
}

function wrapTextForSvg(text: string, maxCharsPerLine: number): string[] {
  if (text.length <= maxCharsPerLine) return [text];
  const words = text.split(' ');
  const lines: string[] = [];
  let current = '';
  for (const word of words) {
    if ((current + ' ' + word).trim().length > maxCharsPerLine) {
      if (current) lines.push(current.trim());
      current = word;
    } else {
      current = current ? current + ' ' + word : word;
    }
  }
  if (current) lines.push(current.trim());
  return lines;
}
