import { google, type youtube_v3 } from 'googleapis';
import fs from 'fs';
import path from 'path';
import { getAuthenticatedClient } from './youtube-auth';
import { getUploadByName, logUpload } from './upload-log';
import type { VideoMetadata, UploadRecord } from './types';

const CATEGORY_MAP: Record<string, string> = {
  comedy: '23',
  entertainment: '24',
  gaming: '20',
  education: '27',
  music: '10',
  news: '25',
  science: '28',
  sports: '17',
};

interface UploadResult {
  videoId: string;
  status: string;
  url: string;
  skipped: boolean;
}

function resolveCategoryId(category: string): string {
  return CATEGORY_MAP[category.toLowerCase()] || '24';
}

function truncate(str: string, max: number): string {
  return str.length <= max ? str : str.slice(0, max);
}

function truncateTags(tags: string[], maxTotalChars: number): string[] {
  const result: string[] = [];
  let total = 0;
  for (const tag of tags) {
    if (total + tag.length > maxTotalChars) break;
    result.push(tag);
    total += tag.length;
  }
  return result;
}

function loadMetadata(metadataPath: string): VideoMetadata {
  const raw = fs.readFileSync(metadataPath, 'utf8');
  return JSON.parse(raw) as VideoMetadata;
}

export async function uploadVideo(
  videoPath: string,
  thumbnailPath: string,
  metadataPath: string,
  outputName: string,
): Promise<UploadResult> {
  const existing = getUploadByName(outputName);
  if (existing && (existing.status === 'uploaded' || existing.status === 'unlisted' || existing.status === 'public')) {
    console.log(`[Upload] Skipping "${outputName}" — already uploaded (${existing.status})`);
    return {
      videoId: existing.videoId!,
      status: existing.status,
      url: existing.youtubeUrl!,
      skipped: true,
    };
  }

  if (!fs.existsSync(videoPath)) {
    throw new Error(`Video file not found: ${videoPath}`);
  }
  if (!fs.existsSync(metadataPath)) {
    throw new Error(`Metadata file not found: ${metadataPath}`);
  }

  const metadata = loadMetadata(metadataPath);
  const auth = await getAuthenticatedClient();
  const youtube = google.youtube({ version: 'v3', auth });

  const pendingRecord: UploadRecord = {
    outputName,
    videoId: null,
    youtubeUrl: null,
    status: 'pending',
    uploadedAt: null,
    publishedAt: null,
    metadataPath,
    videoPath,
    thumbnailPath,
  };
  logUpload(pendingRecord);

  console.log(`[Upload] Uploading "${outputName}"...`);

  let response: { data: youtube_v3.Schema$Video };
  try {
    response = await youtube.videos.insert({
      part: ['snippet', 'status'],
      requestBody: {
        snippet: {
          title: truncate(metadata.title, 100),
          description: truncate(metadata.description, 5000),
          tags: truncateTags(metadata.tags, 500),
          categoryId: resolveCategoryId(metadata.category),
        },
        status: {
          privacyStatus: 'unlisted',
          selfDeclaredMadeForKids: false,
        },
      },
      media: {
        body: fs.createReadStream(videoPath),
      },
    });
  } catch (err: any) {
    const errMsg = err.message || String(err);
    logUpload({ ...pendingRecord, status: 'failed', error: errMsg });

    if (err.code === 403 || errMsg.includes('quotaExceeded')) {
      throw new Error(
        `YouTube API quota exceeded. Daily limit reached. Try again tomorrow or request a quota increase at https://console.cloud.google.com/apis/api/youtube.googleapis.com/quotas\n  Original error: ${errMsg}`,
      );
    }

    if (errMsg.includes('invalid_grant') || errMsg.includes('Token has been expired')) {
      throw new Error(
        `YouTube auth token expired. Re-run: npx tsx src/index.ts auth\n  Original error: ${errMsg}`,
      );
    }

    throw new Error(`Upload failed: ${errMsg}`);
  }

  const videoId = response.data.id!;
  const youtubeUrl = `https://youtube.com/shorts/${videoId}`;
  const now = new Date().toISOString();

  console.log(`[Upload] Video uploaded: ${youtubeUrl}`);

  if (fs.existsSync(thumbnailPath)) {
    try {
      console.log(`[Upload] Setting custom thumbnail...`);
      await youtube.thumbnails.set({
        videoId,
        media: {
          body: fs.createReadStream(thumbnailPath),
        },
      });
      console.log(`[Upload] Thumbnail set.`);
    } catch (err: any) {
      console.warn(`[Upload] Thumbnail upload failed (video still uploaded): ${err.message}`);
    }
  }

  const successRecord: UploadRecord = {
    outputName,
    videoId,
    youtubeUrl,
    status: 'unlisted',
    uploadedAt: now,
    publishedAt: null,
    metadataPath,
    videoPath,
    thumbnailPath,
  };
  logUpload(successRecord);

  return {
    videoId,
    status: 'unlisted',
    url: youtubeUrl,
    skipped: false,
  };
}
