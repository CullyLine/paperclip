import { google } from 'googleapis';
import { getAuthenticatedClient } from './youtube-auth';
import { updateUploadStatus, listAllUploads } from './upload-log';

interface PublishResult {
  videoId: string;
  status: string;
  url: string;
}

/**
 * Flip an unlisted video to public.
 * Requires `part=status` and re-supplies snippet fields that YouTube mandates.
 */
export async function publishVideo(videoId: string): Promise<PublishResult> {
  const auth = await getAuthenticatedClient();
  const youtube = google.youtube({ version: 'v3', auth });

  const current = await youtube.videos.list({
    part: ['snippet', 'status'],
    id: [videoId],
  });

  const video = current.data.items?.[0];
  if (!video) {
    throw new Error(`Video not found on YouTube: ${videoId}`);
  }

  await youtube.videos.update({
    part: ['status'],
    requestBody: {
      id: videoId,
      status: {
        privacyStatus: 'public',
        selfDeclaredMadeForKids: video.status?.selfDeclaredMadeForKids ?? false,
      },
    },
  });

  const now = new Date().toISOString();
  const url = `https://youtube.com/shorts/${videoId}`;

  const record = findRecordByVideoId(videoId);
  if (record) {
    updateUploadStatus(record.outputName, 'public', { publishedAt: now });
  }

  console.log(`[Publish] Video ${videoId} is now public: ${url}`);
  return { videoId, status: 'public', url };
}

/**
 * Schedule a video for future publishing.
 * YouTube requires privacyStatus=private + publishAt for scheduled releases.
 */
export async function schedulePublish(
  videoId: string,
  publishAt: string,
): Promise<PublishResult> {
  const publishDate = new Date(publishAt);
  if (isNaN(publishDate.getTime())) {
    throw new Error(`Invalid date: ${publishAt}. Use ISO 8601 format.`);
  }

  if (publishDate.getTime() <= Date.now()) {
    throw new Error('Scheduled publish time must be in the future.');
  }

  const auth = await getAuthenticatedClient();
  const youtube = google.youtube({ version: 'v3', auth });

  const current = await youtube.videos.list({
    part: ['snippet', 'status'],
    id: [videoId],
  });

  const video = current.data.items?.[0];
  if (!video) {
    throw new Error(`Video not found on YouTube: ${videoId}`);
  }

  await youtube.videos.update({
    part: ['status'],
    requestBody: {
      id: videoId,
      status: {
        privacyStatus: 'private',
        publishAt: publishDate.toISOString(),
        selfDeclaredMadeForKids: video.status?.selfDeclaredMadeForKids ?? false,
      },
    },
  });

  const url = `https://youtube.com/shorts/${videoId}`;

  const record = findRecordByVideoId(videoId);
  if (record) {
    updateUploadStatus(record.outputName, 'scheduled', {
      publishedAt: publishDate.toISOString(),
    });
  }

  console.log(`[Publish] Video ${videoId} scheduled for ${publishDate.toISOString()}: ${url}`);
  return { videoId, status: 'scheduled', url };
}

/**
 * Delete a rejected video from YouTube.
 */
export async function deleteVideo(videoId: string): Promise<void> {
  const auth = await getAuthenticatedClient();
  const youtube = google.youtube({ version: 'v3', auth });

  await youtube.videos.delete({ id: videoId });

  const record = findRecordByVideoId(videoId);
  if (record) {
    updateUploadStatus(record.outputName, 'deleted');
  }

  console.log(`[Publish] Video ${videoId} deleted from YouTube.`);
}

/**
 * Publish all unlisted videos to public.
 * Returns the count of videos published.
 */
export async function publishAllPending(): Promise<number> {
  const records = listAllUploads().filter(
    (r) => r.status === 'unlisted' && r.videoId,
  );

  if (records.length === 0) {
    console.log('[Publish] No unlisted videos to publish.');
    return 0;
  }

  let published = 0;
  for (const record of records) {
    try {
      await publishVideo(record.videoId!);
      published++;
    } catch (err: any) {
      console.error(`[Publish] Failed to publish ${record.videoId}: ${err.message}`);
    }
  }

  return published;
}

function findRecordByVideoId(videoId: string) {
  return listAllUploads().find((r) => r.videoId === videoId);
}
