import { google } from 'googleapis';
import fs from 'fs';
import path from 'path';
import { getAuthenticatedClient } from './src/youtube-auth';

const MEMORIES_DIR = path.resolve(__dirname, '..', 'memories');

interface ScheduledVideo {
  file: string;
  thumb?: string;
  title: string;
  description: string;
  tags: string[];
  scheduledDate: string;
  comment: string;
}

const VIDEOS: ScheduledVideo[] = [
  {
    file: 'goat-checkout-final.mp4',
    thumb: 'goat-checkout-frame.png',
    title: 'unexpected item in bagging area',
    description: [
      'unexpected item in bagging area (goat)',
      '',
      'goat, funny goat, goat shopping, self checkout, grocery store, animals in stores',
      '',
      '#Shorts #goat #funnyanimal #animals #animalreaction #grocery',
    ].join('\n'),
    tags: [
      'goat', 'funny goat', 'self checkout', 'unexpected item',
      'grocery store', 'animals in stores', 'funny animals',
      'animal reaction', 'shorts', 'goat shopping',
    ],
    scheduledDate: '2026-03-19T19:00:00Z',
    comment: 'the machine has been saying this for twenty minutes. he does not care.',
  },
  {
    file: 'moose-laundromat-final.mp4',
    thumb: 'moose-laundromat-frame.png',
    title: "he won't leave until the spin cycle's done",
    description: [
      "he won't leave until the spin cycle's done (moose)",
      '',
      'moose, funny moose, moose laundry, laundromat, animals doing laundry, big animal small room',
      '',
      '#Shorts #moose #funnyanimal #animals #laundry #animalreaction',
    ].join('\n'),
    tags: [
      'moose', 'funny moose', 'laundromat', 'spin cycle',
      'laundry', 'big animal', 'funny animals',
      'animal reaction', 'shorts', 'moose indoors',
    ],
    scheduledDate: '2026-03-20T19:00:00Z',
    comment: 'he has been here since 9. management has been informed.',
  },
  {
    file: 'behind-on-emails-final.mp4',
    title: 'behind on emails',
    description: [
      'behind on emails (cat)',
      '',
      'cat, funny cat, cat at desk, cat working, work from home, cat on computer, office cat',
      '',
      '#Shorts #cat #funnyanimal #animals #workmeme #animalreaction',
    ].join('\n'),
    tags: [
      'cat', 'funny cat', 'cat at desk', 'behind on emails',
      'work from home', 'cat on computer', 'office cat',
      'funny animals', 'shorts', 'cat working',
    ],
    scheduledDate: '2026-03-21T19:00:00Z',
    comment: "he's been staring at the screen for forty-five minutes. no progress has been made.",
  },
  {
    file: 'raccoon-faucet-final.mp4',
    thumb: 'raccoon-faucet-frame.png',
    title: 'he figured out the faucet',
    description: [
      'he figured out the faucet (raccoon)',
      '',
      'raccoon, funny raccoon, raccoon kitchen, raccoon faucet, raccoon water, smart raccoon',
      '',
      '#Shorts #raccoon #funnyanimal #animals #animalreaction #smartanimal',
    ].join('\n'),
    tags: [
      'raccoon', 'funny raccoon', 'raccoon faucet', 'raccoon kitchen',
      'smart raccoon', 'raccoon water', 'funny animals',
      'animal reaction', 'shorts', 'raccoon hands',
    ],
    scheduledDate: '2026-03-22T19:00:00Z',
    comment: 'this has been a long time coming. he has been practicing.',
  },
  {
    file: 'bear-porch-final.mp4',
    thumb: 'bear-porch-frame.png',
    title: 'he checks in every morning',
    description: [
      'he checks in every morning (bear)',
      '',
      'bear, funny bear, bear on porch, bear neighbor, suburban bear, bear at door, bear visit',
      '',
      '#Shorts #bear #funnyanimal #animals #animalreaction #wildlife',
    ].join('\n'),
    tags: [
      'bear', 'funny bear', 'bear on porch', 'bear neighbor',
      'suburban bear', 'bear at door', 'funny animals',
      'animal reaction', 'shorts', 'bear visit',
    ],
    scheduledDate: '2026-03-23T16:00:00Z',
    comment: 'he has not missed a day. the commitment is documented.',
  },
];

function truncate(str: string, max: number): string {
  return str.length <= max ? str : str.slice(0, max);
}

function truncateTags(tags: string[], maxTotal: number): string[] {
  const result: string[] = [];
  let total = 0;
  for (const tag of tags) {
    if (total + tag.length > maxTotal) break;
    result.push(tag);
    total += tag.length;
  }
  return result;
}

async function main() {
  const auth = await getAuthenticatedClient();
  const youtube = google.youtube({ version: 'v3', auth });

  const results: { title: string; videoId: string; url: string; scheduled: string }[] = [];

  for (const video of VIDEOS) {
    const videoPath = path.join(MEMORIES_DIR, video.file);
    const thumbPath = video.thumb ? path.join(MEMORIES_DIR, video.thumb) : null;

    if (!fs.existsSync(videoPath)) {
      console.error(`MISSING: ${video.file}`);
      continue;
    }

    console.log(`\nUploading: ${video.title}`);
    console.log(`  Scheduled: ${video.scheduledDate}`);

    try {
      const response = await youtube.videos.insert({
        part: ['snippet', 'status'],
        requestBody: {
          snippet: {
            title: truncate(video.title, 100),
            description: truncate(video.description, 5000),
            tags: truncateTags(video.tags, 500),
            categoryId: '15', // Pets & Animals
          },
          status: {
            privacyStatus: 'private',
            publishAt: video.scheduledDate,
            selfDeclaredMadeForKids: false,
          },
        },
        media: {
          body: fs.createReadStream(videoPath),
        },
      });

      const videoId = response.data.id!;
      const url = `https://youtube.com/shorts/${videoId}`;
      console.log(`  Uploaded: ${url}`);

      results.push({ title: video.title, videoId, url, scheduled: video.scheduledDate });

      if (thumbPath && fs.existsSync(thumbPath)) {
        try {
          await youtube.thumbnails.set({
            videoId,
            media: { body: fs.createReadStream(thumbPath) },
          });
          console.log(`  Thumbnail set`);
        } catch (e: any) {
          console.warn(`  Thumbnail failed: ${e.message}`);
        }
      }

      try {
        await youtube.commentThreads.insert({
          part: ['snippet'],
          requestBody: {
            snippet: {
              videoId,
              topLevelComment: {
                snippet: { textOriginal: video.comment },
              },
            },
          },
        });
        console.log(`  Comment posted: "${video.comment}"`);
      } catch (e: any) {
        console.warn(`  Comment failed (can pin manually): ${e.message}`);
      }

      console.log(`  DONE`);
    } catch (err: any) {
      if (err.message?.includes('quotaExceeded')) {
        console.error(`\nQUOTA EXCEEDED. Remaining videos not uploaded.`);
        console.error(`Try again tomorrow or upload manually.`);
        break;
      }
      console.error(`  Upload failed: ${err.message}`);
    }
  }

  console.log('\n=== UPLOAD SUMMARY ===');
  for (const r of results) {
    console.log(`  ${r.title}`);
    console.log(`    URL: ${r.url}`);
    console.log(`    Scheduled: ${r.scheduled}`);
  }
  console.log(`\n${results.length}/${VIDEOS.length} videos uploaded successfully.`);
}

main().catch(console.error);
