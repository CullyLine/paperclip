import { execFileSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import { CONFIG } from './config';
import type { Caption } from './types';

/**
 * Escapes text for use in FFmpeg drawtext filter.
 */
function escapeDrawtext(text: string): string {
  return text
    .replace(/\\/g, '\\\\')
    .replace(/'/g, '\u2019')
    .replace(/:/g, '\\:')
    .replace(/%/g, '%%')
    .replace(/\[/g, '\\[')
    .replace(/\]/g, '\\]')
    .replace(/;/g, '\\;');
}

/**
 * Calculates font size to fit text within available width.
 */
function calculateFontSize(text: string, maxWidth: number): number {
  const charWidth = 0.55;
  const maxFontSize = 72;
  const minFontSize = 48;
  const idealSize = Math.floor(maxWidth / (text.length * charWidth));
  return Math.max(minFontSize, Math.min(maxFontSize, idealSize));
}

/**
 * Wraps text into multiple lines if needed, returning an array of lines.
 */
function wrapText(text: string, maxCharsPerLine: number): string[] {
  if (text.length <= maxCharsPerLine) return [text];

  const words = text.split(' ');
  const lines: string[] = [];
  let currentLine = '';

  for (const word of words) {
    if ((currentLine + ' ' + word).trim().length > maxCharsPerLine) {
      if (currentLine) lines.push(currentLine.trim());
      currentLine = word;
    } else {
      currentLine = currentLine ? currentLine + ' ' + word : word;
    }
  }
  if (currentLine) lines.push(currentLine.trim());
  return lines;
}

/**
 * Composites a YouTube Short: black caption bar on top, movie clip on bottom.
 * Output: 1080x1920 9:16 MP4.
 */
export async function compositeVideo(
  clipPath: string,
  caption: Caption,
  outputName: string
): Promise<string> {
  console.log(`[Compositor] Compositing video for: "${caption.text.slice(0, 50)}..."`);

  fs.mkdirSync(CONFIG.outputDir, { recursive: true });
  const outputPath = path.join(CONFIG.outputDir, `${outputName}.mp4`);

  const { width, height, captionBarRatio } = CONFIG.video;
  const barHeight = Math.round(height * captionBarRatio);
  const clipHeight = height - barHeight;

  const fontSize = calculateFontSize(caption.text, width - 80);
  const lines = wrapText(caption.text, Math.floor((width - 80) / (fontSize * 0.55)));
  const escapedLines = lines.map(escapeDrawtext);

  // Build drawtext filters for each line of text, centered in the black bar
  const lineHeight = fontSize + 8;
  const totalTextHeight = lines.length * lineHeight;
  const startY = Math.round((barHeight - totalTextHeight) / 2);

  const drawtextFilters = escapedLines.map((line, i) => {
    const y = startY + i * lineHeight;
    return `drawtext=text='${line}':fontcolor=white:fontsize=${fontSize}:x=(w-text_w)/2:y=${y}:font=Arial Black`;
  });

  // FFmpeg filter: scale clip to fit inside bottom area (letterbox, no crop), black bar on top with text
  const filterComplex = [
    `[0:v]scale=${width}:${clipHeight}:force_original_aspect_ratio=decrease,pad=${width}:${clipHeight}:(ow-iw)/2:(oh-ih)/2:color=black[clip]`,
    `color=black:${width}x${barHeight}:d=60[bar]`,
    `[bar]${drawtextFilters.join(',')}[caption]`,
    `[caption][clip]vstack=inputs=2[out]`,
  ].join(';');

  try {
    execFileSync('ffmpeg', [
      '-y',
      '-i', clipPath,
      '-filter_complex', filterComplex,
      '-map', '[out]',
      '-map', '0:a?',
      '-map_metadata', '-1',
      '-fflags', '+bitexact',
      '-flags:v', '+bitexact',
      '-flags:a', '+bitexact',
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '23',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-shortest',
      '-movflags', '+faststart',
      '-t', CONFIG.video.maxDurationSec.toString(),
      outputPath,
    ], { encoding: 'utf-8', timeout: 120000 });
  } catch (err: any) {
    throw new Error(`[Compositor] FFmpeg failed: ${err.message || err}`);
  }

  if (!fs.existsSync(outputPath)) {
    throw new Error(`[Compositor] Output file not created: ${outputPath}`);
  }

  console.log(`[Compositor] Video saved: ${outputPath}`);
  return outputPath;
}
