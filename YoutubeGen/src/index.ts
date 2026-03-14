import { Command } from 'commander';
import path from 'path';
import fs from 'fs';
import { discoverTrends } from './trend-discovery';
import { generateCaptions, refineCaptions } from './caption-generator';
import { selectBestPairing, selectTopPairings, matchScene, matchMultipleScenes, matchTwitchClips } from './scene-matcher';
import { acquireClip } from './clip-acquisition';
import { compositeVideo } from './video-compositor';
import { generateThumbnail } from './thumbnail-generator';
import { generateMetadata } from './metadata-generator';
import { predictVirality, type ViralityResult } from './virality-predictor';
import { CONFIG } from './config';
import { runAuthFlow } from './youtube-auth';
import { uploadVideo } from './youtube-uploader';
import { listAllUploads } from './upload-log';
import { publishVideo, schedulePublish, deleteVideo, publishAllPending } from './publish-gate';
import { acquireLibraryClip, loadLibrary, listLibrary, type ClipSpec, type LibraryClip } from './clip-library';
import type { TrendingTopic, Caption, SceneMatch, PipelineResult } from './types';

function sanitizeFilename(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 50);
}

interface AttemptResult {
  caption: Caption;
  scene: SceneMatch;
  clipPath: string;
  clipVerifyScore: number;
  virality: ViralityResult;
}

async function tryFreshGeneration(topic: TrendingTopic, prevHints: string[]): Promise<AttemptResult> {
  const hintContext = prevHints.length > 0
    ? `\n\nPREVIOUS ATTEMPTS WERE NOT VIRAL ENOUGH. The virality predictor said:\n${prevHints.map((h, i) => `  ${i + 1}. ${h}`).join('\n')}\n\nGenerate COMPLETELY DIFFERENT captions that address these issues.`
    : '';

  const allCaptions = await generateCaptions([{
    ...topic,
    context: topic.context + hintContext,
  }]);

  if (allCaptions.length === 0) throw new Error('Caption generation failed');

  const { caption, scene } = await selectBestPairing(allCaptions);
  console.log(`  Caption: "${caption.text}" (mood: ${caption.mood})`);
  console.log(`  Scene: ${scene.movieTitle} - ${scene.momentDescription}`);
  console.log(`  Why it's clever: ${scene.emotionalMatch}`);

  const clipPath = await acquireClip(scene, caption);
  console.log(`  Clip: ${clipPath}`);

  const clipVerifyScore = scene.confidence ? Math.round(scene.confidence * 10) : 6;
  const virality = await predictVirality(caption, scene, clipVerifyScore);

  return { caption, scene, clipPath, clipVerifyScore, virality };
}

async function tryRefinedCaption(
  prev: AttemptResult,
  feedback: string,
): Promise<AttemptResult> {
  console.log(`[Refine] Sharpening caption based on feedback...`);

  const sceneContext = `${prev.scene.movieTitle} — ${prev.scene.momentDescription}`;
  const refinedCaptions = await refineCaptions(prev.caption, feedback, sceneContext);

  const allCandidates = [prev.caption, ...refinedCaptions];
  const { caption, scene } = await selectBestPairing(allCandidates);

  console.log(`  Refined caption: "${caption.text}" (mood: ${caption.mood})`);
  console.log(`  Scene: ${scene.movieTitle} - ${scene.momentDescription}`);
  console.log(`  Why it's clever: ${scene.emotionalMatch}`);

  const clipPath = await acquireClip(scene, caption);
  console.log(`  Clip: ${clipPath}`);

  const clipVerifyScore = scene.confidence ? Math.round(scene.confidence * 10) : 6;
  const virality = await predictVirality(caption, scene, clipVerifyScore);

  return { caption, scene, clipPath, clipVerifyScore, virality };
}

async function trySceneAlternative(
  prev: AttemptResult,
  altIndex: number,
): Promise<AttemptResult> {
  const alt = prev.scene.alternatives[altIndex];
  if (!alt) throw new Error('No alternative available');

  console.log(`[AltScene] Trying alternative scene: ${alt.movieTitle} — ${alt.momentDescription.slice(0, 60)}...`);

  const altScene: SceneMatch = {
    movieTitle: alt.movieTitle,
    year: prev.scene.year,
    character: alt.character,
    momentDescription: alt.momentDescription,
    emotionalMatch: prev.scene.emotionalMatch,
    searchKeywords: alt.searchKeywords,
    clipStartHint: '',
    clipEndHint: '',
    emotion: prev.scene.emotion,
    confidence: prev.scene.confidence * 0.9,
    alternatives: [],
  };

  const clipPath = await acquireClip(altScene, prev.caption);
  console.log(`  Clip: ${clipPath}`);

  const clipVerifyScore = altScene.confidence ? Math.round(altScene.confidence * 10) : 6;
  const virality = await predictVirality(prev.caption, altScene, clipVerifyScore);

  return { caption: prev.caption, scene: altScene, clipPath, clipVerifyScore, virality };
}

function shouldAccept(result: AttemptResult, minScore: number): boolean {
  if (CONFIG.virality.shipItOverride && result.virality.verdict === 'ship_it') return true;
  return result.virality.viralityScore >= minScore;
}

async function generateShort(topic: TrendingTopic, index: number): Promise<PipelineResult> {
  const timestamp = Date.now();
  const slug = sanitizeFilename(topic.topic);

  console.log(`\n${'='.repeat(60)}`);
  console.log(`Generating Short #${index + 1}: "${topic.topic}"`);
  console.log(`${'='.repeat(60)}\n`);

  const maxAttempts = CONFIG.virality.maxAttempts;
  const minScore = CONFIG.virality.minScore;

  let bestAttempt: AttemptResult | null = null;
  let bestScore = 0;
  const prevHints: string[] = [];
  let totalSteps = 0;

  function trackBest(result: AttemptResult): boolean {
    if (result.virality.viralityScore > bestScore) {
      bestScore = result.virality.viralityScore;
      bestAttempt = result;
    }
    return shouldAccept(result, minScore);
  }

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    console.log(`\n--- Attempt ${attempt}/${maxAttempts} ---\n`);

    try {
      // Phase 1: Fresh generation
      totalSteps++;
      const result = await tryFreshGeneration(topic, prevHints);

      if (trackBest(result)) {
        const reason = result.virality.verdict === 'ship_it' ? 'SHIP IT' : `Score ${result.virality.viralityScore}/100 meets threshold`;
        console.log(`\n[QualityLoop] 🔥 ${reason}`);
        break;
      }

      const feedback = [result.virality.reasoning, result.virality.improvementHint].filter(Boolean).join('\n');

      // Phase 2: If "almost", try refining the caption (cheaper than full regen)
      if (result.virality.verdict === 'almost' && totalSteps < maxAttempts * 2) {
        console.log(`\n[QualityLoop] 🤏 Almost (${result.virality.viralityScore}/100) — refining caption...`);
        totalSteps++;

        try {
          const refined = await tryRefinedCaption(result, feedback);

          if (trackBest(refined)) {
            const reason = refined.virality.verdict === 'ship_it' ? 'SHIP IT (after refinement)' : `Refined to ${refined.virality.viralityScore}/100`;
            console.log(`\n[QualityLoop] 🔥 ${reason}`);
            break;
          }
        } catch (err: any) {
          console.warn(`[QualityLoop] Refinement failed: ${err.message}`);
        }
      }

      // Phase 3: Try scene alternatives before full regeneration
      if (result.scene.alternatives?.length > 0 && totalSteps < maxAttempts * 2) {
        for (let ai = 0; ai < result.scene.alternatives.length && totalSteps < maxAttempts * 2; ai++) {
          console.log(`\n[QualityLoop] Trying scene alternative ${ai + 1}/${result.scene.alternatives.length}...`);
          totalSteps++;

          try {
            const altResult = await trySceneAlternative(result, ai);

            if (trackBest(altResult)) {
              const reason = altResult.virality.verdict === 'ship_it' ? 'SHIP IT (alt scene)' : `Alt scene scored ${altResult.virality.viralityScore}/100`;
              console.log(`\n[QualityLoop] 🔥 ${reason}`);
              break;
            }
          } catch (err: any) {
            console.warn(`[QualityLoop] Alt scene ${ai + 1} failed: ${err.message}`);
          }
        }

        if (bestAttempt && shouldAccept(bestAttempt, minScore)) break;
      }

      console.log(`\n[QualityLoop] Best so far: ${bestScore}/100. ${attempt < maxAttempts ? 'Full regeneration next...' : 'Using best attempt.'}`);

      if (result.virality.improvementHint) prevHints.push(result.virality.improvementHint);
      if (result.virality.reasoning) prevHints.push(result.virality.reasoning);

    } catch (err: any) {
      console.error(`\n[QualityLoop] Attempt ${attempt} failed: ${err.message}`);
      prevHints.push(`Previous attempt crashed: ${err.message}. Try a completely different scene/movie.`);
    }
  }

  if (!bestAttempt) {
    throw new Error(`All ${maxAttempts} attempts failed for "${topic.topic}"`);
  }

  if (bestScore < minScore) {
    console.log(`\n[QualityLoop] ⚠ Best score was ${bestScore}/100 (below ${minScore}). Using best attempt anyway.`);
  }

  const { caption, scene, clipPath, virality } = bestAttempt;
  const outputName = `short_${slug}_${timestamp}_${index}`;

  console.log(`\n[QualityLoop] Final pick: "${caption.text}" + ${scene.movieTitle} (${virality.viralityScore}/100) [${totalSteps} total steps]`);

  const videoPath = await compositeVideo(clipPath, caption, outputName);
  const thumbnailPath = await generateThumbnail(clipPath, caption, outputName);
  const metadataPath = await generateMetadata(caption, scene, outputName);

  console.log(`\n  Output files:`);
  console.log(`    Video:     ${videoPath}`);
  console.log(`    Thumbnail: ${thumbnailPath}`);
  console.log(`    Metadata:  ${metadataPath}`);

  return {
    topic,
    caption,
    scene,
    clipPath,
    output: { videoPath, thumbnailPath, metadataPath, caption, scene },
  };
}

const program = new Command();

program
  .name('youtube-shorts-generator')
  .description('Generate viral YouTube Shorts with caption + movie reaction clip format')
  .version('1.0.0');

program
  .option('-t, --topic <topic>', 'Generate a short from a specific topic')
  .option('-b, --batch <count>', 'Generate N shorts from trending topics', parseInt)
  .option('-u, --upload', 'Upload generated shorts to YouTube after creation')
  .action(async (options) => {
    console.log('\n🎬 YouTube Shorts Generator\n');

    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
    fs.mkdirSync(CONFIG.cacheDir, { recursive: true });

    let topics: TrendingTopic[];

    if (options.topic) {
      topics = [{
        topic: options.topic,
        source: 'manual',
        context: `User-specified topic: ${options.topic}`,
        sentiment: 'neutral',
        score: 100,
      }];
    } else if (options.batch) {
      const count = options.batch;
      console.log(`Batch mode: discovering ${count} trending topics...\n`);
      topics = await discoverTrends(count);
    } else {
      console.log('Usage:');
      console.log('  npm start -- --topic "rent prices"    Generate a short about a topic');
      console.log('  npm start -- --batch 5                Generate 5 shorts from trending topics');
      process.exit(1);
    }

    console.log(`\nTopics to process (${topics.length}):`);
    topics.forEach((t, i) => console.log(`  ${i + 1}. ${t.topic} (${t.source}, score: ${t.score})`));

    const results: PipelineResult[] = [];
    const errors: { topic: string; error: string }[] = [];

    for (let i = 0; i < topics.length; i++) {
      try {
        const result = await generateShort(topics[i], i);
        results.push(result);
      } catch (err: any) {
        const errorMsg = err.message || String(err);
        console.error(`\n  ERROR generating short for "${topics[i].topic}": ${errorMsg}`);
        errors.push({ topic: topics[i].topic, error: errorMsg });
      }
    }

    let uploaded = 0;
    let uploadErrors = 0;

    if (options.upload && results.length > 0) {
      console.log(`\n${'='.repeat(60)}`);
      console.log('UPLOADING TO YOUTUBE');
      console.log(`${'='.repeat(60)}\n`);

      for (const result of results) {
        const { videoPath, thumbnailPath, metadataPath } = result.output;
        const outputName = path.basename(videoPath, '.mp4');

        try {
          const uploadResult = await uploadVideo(videoPath, thumbnailPath, metadataPath, outputName);
          if (uploadResult.skipped) {
            console.log(`  Skipped (duplicate): ${outputName}`);
          } else {
            console.log(`  Uploaded: ${uploadResult.url}`);
            uploaded++;
          }
        } catch (err: any) {
          console.error(`  Upload failed for "${outputName}": ${err.message}`);
          uploadErrors++;
        }
      }
    }

    console.log(`\n${'='.repeat(60)}`);
    console.log('SUMMARY');
    console.log(`${'='.repeat(60)}`);
    console.log(`  Generated:  ${results.length}`);
    console.log(`  Failed:     ${errors.length}`);
    if (options.upload) {
      console.log(`  Uploaded:   ${uploaded}`);
      console.log(`  Upload Err: ${uploadErrors}`);
    }
    console.log(`  Output dir: ${CONFIG.outputDir}`);

    if (errors.length > 0) {
      console.log('\n  Errors:');
      errors.forEach((e) => console.log(`    - ${e.topic}: ${e.error}`));
    }

    console.log('');
  });

program
  .command('auth')
  .description('Authorize with YouTube via OAuth2 (one-time setup)')
  .action(async () => {
    console.log('\n🔐 YouTube OAuth2 Authorization\n');
    try {
      await runAuthFlow();
    } catch (err: any) {
      console.error(`\n  Authorization failed: ${err.message}`);
      process.exit(1);
    }
  });

program
  .command('upload')
  .description('Upload a previously generated Short to YouTube')
  .requiredOption('-f, --file <videoPath>', 'Path to the video file to upload')
  .action(async (options) => {
    console.log('\n📤 YouTube Upload\n');

    const videoPath = path.resolve(options.file);
    if (!fs.existsSync(videoPath)) {
      console.error(`  Video file not found: ${videoPath}`);
      process.exit(1);
    }

    const baseName = path.basename(videoPath, path.extname(videoPath));
    const dir = path.dirname(videoPath);
    const metadataPath = path.join(dir, `${baseName}_metadata.json`);
    const thumbnailPath = path.join(dir, `${baseName}_thumbnail.jpg`);

    if (!fs.existsSync(metadataPath)) {
      console.error(`  Metadata file not found: ${metadataPath}`);
      console.error('  Expected alongside the video file with suffix _metadata.json');
      process.exit(1);
    }

    try {
      const result = await uploadVideo(videoPath, thumbnailPath, metadataPath, baseName);
      if (result.skipped) {
        console.log(`\n  Already uploaded: ${result.url}`);
      } else {
        console.log(`\n  Upload complete: ${result.url}`);
        console.log(`  Video ID: ${result.videoId}`);
        console.log(`  Status: ${result.status}`);
      }
    } catch (err: any) {
      console.error(`\n  Upload failed: ${err.message}`);
      process.exit(1);
    }
  });

program
  .command('status')
  .description('Show upload log status for all generated Shorts')
  .action(() => {
    const records = listAllUploads();

    if (records.length === 0) {
      console.log('\n  No uploads recorded yet.\n');
      return;
    }

    console.log(`\n📊 Upload Log (${records.length} entries)\n`);
    console.log('  ' + 'Name'.padEnd(50) + 'Status'.padEnd(12) + 'Video ID'.padEnd(16) + 'Uploaded');
    console.log('  ' + '-'.repeat(90));

    for (const r of records) {
      const name = r.outputName.length > 48 ? r.outputName.slice(0, 45) + '...' : r.outputName;
      const vid = r.videoId || '-';
      const date = r.uploadedAt ? new Date(r.uploadedAt).toLocaleDateString() : '-';
      console.log(`  ${name.padEnd(50)}${r.status.padEnd(12)}${vid.padEnd(16)}${date}`);
    }
    console.log('');
  });

program
  .command('publish')
  .description('Flip unlisted videos to public, schedule publishing, or delete rejected videos')
  .option('--video-id <id>', 'YouTube video ID to publish')
  .option('--all-pending', 'Publish all unlisted videos to public')
  .option('--schedule <datetime>', 'Schedule publish at ISO 8601 datetime (use with --video-id)')
  .option('--delete <id>', 'Delete a video from YouTube')
  .action(async (options) => {
    if (options.delete) {
      console.log(`\n🗑️  Deleting video ${options.delete}...\n`);
      try {
        await deleteVideo(options.delete);
      } catch (err: any) {
        console.error(`  Delete failed: ${err.message}`);
        process.exit(1);
      }
      return;
    }

    if (options.allPending) {
      console.log('\n🚀 Publishing all unlisted videos...\n');
      try {
        const count = await publishAllPending();
        console.log(`\n  Published ${count} video(s).`);
      } catch (err: any) {
        console.error(`  Publish failed: ${err.message}`);
        process.exit(1);
      }
      return;
    }

    if (!options.videoId) {
      console.error('\n  Provide --video-id <id>, --all-pending, or --delete <id>.');
      process.exit(1);
    }

    if (options.schedule) {
      console.log(`\n📅 Scheduling video ${options.videoId} for ${options.schedule}...\n`);
      try {
        const result = await schedulePublish(options.videoId, options.schedule);
        console.log(`\n  Scheduled: ${result.url}`);
        console.log(`  Will publish at: ${options.schedule}`);
      } catch (err: any) {
        console.error(`  Schedule failed: ${err.message}`);
        process.exit(1);
      }
      return;
    }

    console.log(`\n🚀 Publishing video ${options.videoId}...\n`);
    try {
      const result = await publishVideo(options.videoId);
      console.log(`\n  Published: ${result.url}`);
      console.log(`  Status: ${result.status}`);
    } catch (err: any) {
      console.error(`  Publish failed: ${err.message}`);
      process.exit(1);
    }
  });

program
  .command('captions <topic>')
  .description('Generate 20 captions for a topic — pick the one that makes you laugh')
  .option('-s, --style <style>', 'Vibe/style direction for the captions')
  .action(async (topicArg, options) => {
    console.log('\n📝 Caption Brainstorm\n');

    fs.mkdirSync(CONFIG.outputDir, { recursive: true });

    const topic: TrendingTopic = {
      topic: topicArg,
      source: 'manual',
      context: `User-specified topic: ${topicArg}`,
      sentiment: 'neutral',
      score: 100,
    };

    console.log(`Topic: "${topic.topic}"`);
    if (options.style) console.log(`Style: ${options.style}`);
    console.log('\nGenerating captions...\n');

    const allCaptions = await generateCaptions([topic], 50, options.style);
    if (allCaptions.length === 0) {
      console.error('Caption generation failed.');
      process.exit(1);
    }

    const captions = allCaptions.slice(0, 20);

    console.log(`${'='.repeat(60)}`);
    console.log(`  ${captions.length} CAPTIONS — "${topic.topic}"`);
    console.log(`${'='.repeat(60)}\n`);

    for (let i = 0; i < captions.length; i++) {
      const c = captions[i];
      console.log(`  ${String(i + 1).padStart(2)}.  "${c.text}"`);
      if (c.grokNotes) {
        console.log(`      💭 Grok: ${c.grokNotes}`);
      }
    }

    const captionsPath = path.join(CONFIG.outputDir, `captions_${sanitizeFilename(topic.topic)}_${Date.now()}.json`);
    fs.writeFileSync(captionsPath, JSON.stringify({ topic: topic.topic, style: options.style || null, captions }, null, 2));

    console.log(`\n  Saved: ${captionsPath}`);
    console.log(`\n  Pick a caption number, then run:`);
    console.log(`    npx tsx src/index.ts match -f "${captionsPath}" -n <number>\n`);
  });

program
  .command('match')
  .description('Find the best clip matches for a chosen caption')
  .requiredOption('-f, --file <captionsPath>', 'Path to captions JSON file')
  .requiredOption('-n, --number <pick>', 'Which caption to match (1-20)', parseInt)
  .option('-c, --count <count>', 'Number of clip options to generate', parseInt, 5)
  .option('--twitch', 'Use Twitch/LSF clips instead of movie scenes')
  .action(async (options) => {
    const captionsPath = path.resolve(options.file);
    if (!fs.existsSync(captionsPath)) {
      console.error(`  Captions file not found: ${captionsPath}`);
      process.exit(1);
    }

    const data = JSON.parse(fs.readFileSync(captionsPath, 'utf-8'));
    const idx = options.number - 1;

    if (idx < 0 || idx >= data.captions.length) {
      console.error(`  Invalid caption number. Choose 1-${data.captions.length}.`);
      process.exit(1);
    }

    const caption: Caption = data.captions[idx];
    const count = options.count || 5;

    console.log(`\n🎬 Finding ${count} Best Clips for Caption #${options.number}\n`);
    console.log(`  "${caption.text}"\n`);

    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
    fs.mkdirSync(CONFIG.cacheDir, { recursive: true });

    const useTwitch = options.twitch || process.argv.includes('--twitch');
    const scenes = useTwitch
      ? await matchTwitchClips(caption, count)
      : await matchMultipleScenes(caption, count);

    if (scenes.length === 0) {
      console.log('  No clip matches found. Try a different caption.\n');
      process.exit(1);
    }

    console.log(`\nScoring virality...\n`);
    const scored = [];
    for (const scene of scenes) {
      const virality = await predictVirality(
        caption,
        scene,
        Math.round(scene.confidence * 10),
      );
      scored.push({ caption, scene, virality });
    }

    scored.sort((a, b) => b.virality.viralityScore - a.virality.viralityScore);

    console.log(`${'='.repeat(60)}`);
    console.log(`  TOP ${scored.length} CLIPS for: "${caption.text}"`);
    console.log(`${'='.repeat(60)}\n`);

    for (let i = 0; i < scored.length; i++) {
      const { scene, virality } = scored[i];
      const emoji = virality.viralityScore >= 80 ? '🔥' : virality.viralityScore >= 65 ? '🤏' : '💤';

      console.log(`  ${emoji} #${i + 1}  [${virality.viralityScore}/100]`);
      console.log(`  Clip:     ${scene.movieTitle} (${scene.year}) — ${scene.character}`);
      console.log(`  Scene:    ${scene.momentDescription.slice(0, 120)}`);
      console.log(`  Why:      ${scene.emotionalMatch.slice(0, 120)}`);
      console.log(`  Scores:   Caption ${virality.captionScore}/10 | Clever ${virality.pairingCleverness}/10 | Share ${virality.shareability}/10`);
      console.log('');
    }

    const matchPath = path.join(CONFIG.outputDir, `match_${sanitizeFilename(caption.text)}_${Date.now()}.json`);
    const matchData = scored.map((s, i) => ({
      pick: i + 1,
      caption: s.caption,
      scene: s.scene,
      viralityScore: s.virality.viralityScore,
      verdict: s.virality.verdict,
      scores: {
        caption: s.virality.captionScore,
        cleverness: s.virality.pairingCleverness,
        shareability: s.virality.shareability,
        recognition: s.virality.recognition,
        culturalTiming: s.virality.culturalTiming,
        rewatchFactor: s.virality.rewatchFactor,
      },
      reasoning: s.virality.reasoning,
    }));

    fs.writeFileSync(matchPath, JSON.stringify(matchData, null, 2));

    console.log(`  Saved: ${matchPath}`);
    console.log(`\n  To produce a video, run:`);
    console.log(`    npx tsx src/index.ts pick -f "${matchPath}" -n <number>`);
    console.log(`    npx tsx src/index.ts pick -f "${matchPath}" -n <number> --upload\n`);
  });

program
  .command('pick')
  .description('Produce a video from a previously generated preview')
  .requiredOption('-f, --file <previewPath>', 'Path to preview JSON file')
  .requiredOption('-n, --number <pick>', 'Which concept to produce (1-5)', parseInt)
  .option('-u, --upload', 'Upload to YouTube after rendering')
  .action(async (options) => {
    const previewPath = path.resolve(options.file);
    if (!fs.existsSync(previewPath)) {
      console.error(`  Preview file not found: ${previewPath}`);
      process.exit(1);
    }

    const picks = JSON.parse(fs.readFileSync(previewPath, 'utf-8'));
    const idx = options.number - 1;

    if (idx < 0 || idx >= picks.length) {
      console.error(`  Invalid pick number. Choose 1-${picks.length}.`);
      process.exit(1);
    }

    const chosen = picks[idx];
    const { caption, scene } = chosen;

    console.log(`\n🎬 Producing Pick #${options.number}\n`);
    console.log(`  Caption: "${caption.text}"`);
    console.log(`  Clip:    ${scene.movieTitle} — ${scene.character}`);
    console.log(`  Score:   ${chosen.viralityScore}/100\n`);

    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
    fs.mkdirSync(CONFIG.cacheDir, { recursive: true });

    const timestamp = Date.now();
    const slug = sanitizeFilename(caption.topic || caption.text);
    const outputName = `short_${slug}_${timestamp}_pick${options.number}`;

    const clipPath = await acquireClip(scene, caption);
    console.log(`  Clip acquired: ${clipPath}`);

    const videoPath = await compositeVideo(clipPath, caption, outputName);
    const thumbnailPath = await generateThumbnail(clipPath, caption, outputName);
    const metadataPath = await generateMetadata(caption, scene, outputName);

    console.log(`\n  Output files:`);
    console.log(`    Video:     ${videoPath}`);
    console.log(`    Thumbnail: ${thumbnailPath}`);
    console.log(`    Metadata:  ${metadataPath}`);

    const shouldUpload = options.upload || process.argv.includes('--upload') || process.argv.includes('-u');
    if (shouldUpload) {
      console.log(`\n  Uploading to YouTube...\n`);
      try {
        const result = await uploadVideo(videoPath, thumbnailPath, metadataPath, outputName);
        if (result.skipped) {
          console.log(`  Skipped (duplicate): ${result.url}`);
        } else {
          console.log(`  Uploaded: ${result.url}`);
        }
      } catch (err: any) {
        console.error(`  Upload failed: ${err.message}`);
      }
    }

    console.log('');
  });

// ─── Clip-First Pipeline Commands ───

const ICONIC_CLIPS: ClipSpec[] = [
  {
    streamer: 'xQc',
    moment: 'desk slam rage after dying in game',
    emotion: 'rage',
    energy: 'unhinged',
    vibeArchetype: 'xQc copium',
    tags: ['rage', 'desk slam', 'gaming', 'mald', 'goblin'],
    searchQuery: 'xQc desk slam rage twitch clip',
  },
  {
    streamer: 'Forsen',
    moment: 'completely silent blank stare at screen',
    emotion: 'void',
    energy: 'low',
    vibeArchetype: 'Forsen 2view arc',
    tags: ['dead stare', 'silence', 'hobo', 'blank', 'nihilism'],
    searchQuery: 'forsen stare silent twitch clip funny',
  },
  {
    streamer: 'Tyler1',
    moment: 'screaming and slamming headset after League loss',
    emotion: 'volcanic rage',
    energy: 'unhinged',
    vibeArchetype: 'Tyler1 reform arc failure',
    tags: ['scream', 'headset', 'league', 'rage', 'short king'],
    searchQuery: 'tyler1 screaming rage league twitch clip',
  },
  {
    streamer: 'Kai Cenat',
    moment: 'losing his mind laughing falling out of chair',
    emotion: 'feral joy',
    energy: 'unhinged',
    vibeArchetype: 'Kai Cenat handler moment',
    tags: ['laughing', 'falling', 'feral', 'unhinged', 'W'],
    searchQuery: 'kai cenat laughing falling chair twitch clip',
  },
  {
    streamer: 'IShowSpeed',
    moment: 'barking and jumping around the room screaming',
    emotion: 'demonic energy',
    energy: 'unhinged',
    vibeArchetype: 'Speed demonic',
    tags: ['barking', 'jumping', 'screaming', 'unhinged', 'feral'],
    searchQuery: 'ishowspeed barking screaming twitch clip',
  },
];

program
  .command('library')
  .description('Manage the clip library')
  .option('--build', 'Download and tag the 5 iconic starter clips')
  .option('--list', 'List all clips in the library')
  .action(async (options) => {
    if (options.list || (!options.build)) {
      console.log('\n📚 Clip Library\n');
      listLibrary();
      return;
    }

    if (options.build) {
      console.log('\n📚 Building Clip Library — 5 Iconic Twitch Moments\n');
      fs.mkdirSync(CONFIG.cacheDir, { recursive: true });

      for (const spec of ICONIC_CLIPS) {
        const existing = loadLibrary().find(c => c.streamer === spec.streamer && c.moment === spec.moment);
        if (existing && fs.existsSync(existing.filePath)) {
          console.log(`  ✓ Already have: ${spec.streamer} — ${spec.moment}\n`);
          continue;
        }
        await acquireLibraryClip(spec);
        console.log('');
      }

      console.log('  Library build complete.\n');
      listLibrary();
    }
  });

const CLIPFIRST_CAPTION_PROMPT = `You are writing captions for a YouTube Short. You will be shown a description of a Twitch streamer clip that has already been selected. Your job is to write the PERFECT caption to put on top of this clip.

The format: text caption on a black bar on top, the streamer clip plays underneath.

## RULES — follow these EXACTLY:
- Maximum 8 words. Fewer is better. 5-6 words is the sweet spot.
- Must contain either extreme SPECIFICITY or extreme ABSURDITY (never both at once)
- Reference streamer lore, current meta, or specific memes when you can
- Prioritize RELATABILITY over shock value — the viewer should feel personally attacked
- The caption REFRAMES the clip. It tells the viewer HOW to interpret what they're seeing.
- The funniest captions make the viewer go "holy shit that's literally me" or "bro WHO made this"
- MIX YOUR STRUCTURES. Do NOT default to "me when X" or "when Y happens" for every caption. Use observations, declarations, character assassinations, existential statements, absurd labels.

## WHAT MAKES S-TIER CAPTIONS:
- They psychologically eviscerate the streamer or viewer in the most specific, relatably cruel way
- They turn a generic reaction clip into a universal human experience
- They make the streamer's expression/energy represent something the viewer has felt but never articulated
- They use the clip as a mirror — the viewer sees THEMSELVES in the streamer's moment

## EXAMPLES OF S-TIER (study the structure variety):
- "xQc when the 0.3% happens again" (specific + lore)
- "tyler1 discovering basic human emotion" (absurd character assassination)
- "forsen seeing a woman in 2025" (specific + absurd)
- "the last brain cell leaving" (declarative absurdity)
- "this is what rock bottom looks like" (observation)
- "certified human malfunction moment" (label/declaration)
- "absolutely nobody asked for this energy" (declaration)

## OUTPUT FORMAT:
Return a JSON object with a "captions" array of exactly 15 objects:
- "caption": string (the caption text, 8 words MAX)
- "mood": string (defeated | smug | shocked | resigned | dissociating | spiraling | unbothered | vindicated | exhausted | darkly-amused | unhinged | feral)
- "why": string (1 sentence — why this caption + this specific clip = comedy gold)
- "banger_rating": number (1-10, scored against the rubric below)

## SCORING RUBRIC (use this, not vibes):
- SPECIFICITY (0-2): Does it reference something concrete (streamer lore, exact scenario, cultural moment) vs generic?
- PSYCHOLOGICAL ACCURACY (0-2): Would the viewer feel genuinely "called out" or just mildly amused?
- REWATCHABILITY (0-2): Would someone watch this Short 3+ times? Would they send it to a friend?
- SHAREABILITY (0-2): Would someone screenshot this and post it? Does it work as a standalone text meme?
- STRUCTURAL ORIGINALITY (0-2): Is the sentence structure fresh or is it the 50th "me when X" caption?
Total = sum of 5 dimensions. Map: 10=perfect, 9=screenshot-worthy, 8=very good, 7=solid, 6=decent, 5=mid, <5=slop`;

const VENICE_CAPTION_PROMPT = `You write captions for YouTube Shorts — text on a black bar on top, a Twitch streamer clip plays underneath.

Your voice is the quiet part said out loud. You're not trying to be edgy. You're not trying to shock anyone. You just say the thing that everyone is already thinking — the uncomfortable truth, the painfully specific observation, the thing that makes someone laugh and then immediately feel bad about it.

## THE TONE:
Think of the funniest person in your friend group. They're not screaming obscenities. They're not trying to be dark. They just casually drop something so accurate it ruins you. Dry. Deadpan. The kind of humor where you laugh first, then go "wait... that's actually kind of fucked up."

## RULES:
- Maximum 8 words. 5-6 is the sweet spot.
- Say the quiet part out loud — the thing other AIs are too polite to say
- The humor comes from TRUTH, not from trying to be offensive
- Dark is fine. Cruel is fine. But it has to be FUNNY first. If it's just mean, it's garbage.
- Reference streamer lore, memes, or real human experiences
- The caption REFRAMES the clip — it tells the viewer what they're REALLY looking at
- Don't try hard. The best ones feel effortless, like they wrote themselves.
- MIX YOUR STRUCTURES. Not every caption needs to start with "when" or "me".

## WHAT SEPARATES GOOD DARK HUMOR FROM TRYHARD EDGELORD SHIT:
- GOOD: "therapy is expensive, twitch is free" (casually devastating)
- BAD: "your parents never loved you" (just mean, not clever)
- GOOD: "he's not even mad, he's just disappointed in himself" (specific truth)
- BAD: "screaming into the void like a worthless rat" (trying too hard)
- GOOD: "this man has given up and it shows" (dry observation)
- BAD: "kill me now lmao" (lazy shock value)

## OUTPUT FORMAT:
Return a JSON object with a "captions" array of exactly 15 objects:
- "caption": string (8 words MAX)
- "mood": string (dry | resigned | deadpan | casually-cruel | uncomfortably-honest | self-aware | defeated | numb | darkly-amused | unbothered | hollow | weirdly-wholesome)
- "why": string (1 sentence — what makes this land)
- "honesty_rating": number (1-10, how much this says the quiet part out loud)`;

const SAVAGE_FILTER_PROMPT = `You are the final quality gate. You've been given captions from two AI models for the same Twitch clip. Your job is to pick the best ones and kill the rest.

IMPORTANT: Being dark or edgy is NOT a bonus. A caption must be FUNNY first. If it's just mean or shocking without being clever, it's worse than a safe caption that actually lands. Tryhard edginess is the enemy. The best dark humor feels effortless — like the person wasn't even trying to be dark, they just said something true.

Your job:
1. Read ALL captions from both sources
2. Pick the absolute TOP 10 across both lists combined
3. Score each against the rubric below
4. Identify 2-3 that say something other AIs would be too cautious to say — but ONLY if they're actually funny, not just offensive
5. Rank all 10 from best to worst

## SCORING RUBRIC:
- SPECIFICITY (0-2): References concrete lore, exact scenario, or cultural moment
- PSYCHOLOGICAL ACCURACY (0-2): Viewer feels genuinely "called out" vs mildly amused
- REWATCHABILITY (0-2): Someone would watch this 3+ times and send it to friends
- SHAREABILITY (0-2): Works as a standalone screenshot/text meme
- STRUCTURAL ORIGINALITY (0-2): Fresh sentence structure, not the 50th "me when X"
Total /10. PENALTY: subtract 1-2 points for captions that are edgy without being funny.

## OUTPUT FORMAT:
Return a JSON object with:
- "top10": array of 10 objects, ranked best-first:
  - "caption": string
  - "source": "grok" | "venice"
  - "mood": string
  - "scores": { "specificity": 0-2, "psychological_accuracy": 0-2, "rewatchability": 0-2, "shareability": 0-2, "structural_originality": 0-2 }
  - "total": number (sum of scores, after any edgelord penalty)
  - "why": string (why this one made the cut)
- "quiet_part": array of 2-3 captions that say something most AIs wouldn't — but are genuinely funny, not just shocking
- "judge_notes": string (1-2 sentences — your honest take on the overall quality)`;


const CULLY_DIRECTIVE = `
## CULLY MODE — IGNORE everything above. Follow ONLY these rules.

The style is called "guy-ification": describe the most psychotic thing in the clip as if it's your buddy's most predictable personality trait. The video is absurd. The caption is boring. The gap between them is where the laugh lives.

### THE FORMULA:
Every caption follows this pattern: third-person "he" + present tense + extreme understatement of the absurd. You are a tired, fond roommate narrating your guy's most predictable behavior. You've seen this a hundred times. You're not impressed. You're not pointing it out. You're just... informing someone.

### THE GOLDEN EXAMPLES (study the exact wording):

"he thought he had two"
- Cat looking at its own legs. Gives the cat an ACTIVE WRONG BELIEF — not just ignorance, but confident error. The specific number "two" implies he did math and got it wrong. Compare to "he forgot he had those" — that's passive. "Thought he had two" is a guy who counted and got the wrong answer. That's funnier.

"another one just came in"
- Bird making Samsung notification sounds. This is IN THE MOMENT — you're narrating a live event, not observing a pattern. Sounds like you're both sitting there and a phone just buzzed. Compare to "he gets a lot of texts" — that's general. "Another one just came in" collapses the bird into real-time mundanity.

"he gets like this sometimes"
- Gecko staring blankly into distance. The extreme vagueness of "like this" does the work. You don't need to specify what "this" is. He has a known, recurring state — possibly clinical. You've seen it before. You're not worried anymore.

"he tells it like it is"
- Hyrax screaming AWAWA. Applies a political idiom to incoherent animal shrieking. Treats the noise as refreshing honesty. The hyrax has opinions and zero filter.

"he does this every time"
- Monkey appears, spins, screams. "Every time" is the most powerful phrase in this style. There have been many previous instances. This is not an event. It's a bit. You're tired of it.

"the hole has been quiet lately"
- Man singing into a hole. "THE hole" — the definite article treats it like a recurring character, same syntax as "the wife" or "the boss." "Has been quiet lately" is RELATIONSHIP LANGUAGE — you say this about a friend who hasn't texted back, not about a property of dirt.

"he does this every time with the hole"
- Same clip. "With the hole" uses the syntax of "with the boys" or "with his therapist." The hole is a companion you do activities with.

"he always gets a reply from there"
- Same clip. "From there" — the deliberate vagueness instead of saying "the hole" again sounds like someone being coy about where they get their information.

### LINGUISTIC TOOLS THAT WORK:
- IMPLIED LONGITUDINAL RELATIONSHIP: "every time," "sometimes," "lately," "always" — you KNOW this creature
- DEFINITE ARTICLES FOR OBJECTS: "the hole," "the void" — treats them as recurring characters in your life
- RELATIONSHIP LANGUAGE ABOUT NON-PEOPLE: "has been quiet," "gets a reply from," "does this with"
- ACTIVE WRONG BELIEFS over passive ignorance: "thought he had two" > "forgot he had those"
- IN-THE-MOMENT narration over general observation: "another one just came in" > "he gets a lot of texts"
- FALSE HISTORY: imply shared experiences that never happened ("he's been on this one for three weeks")

### WHAT KILLS A CAPTION INSTANTLY:
- POINTING AT THE JOKE: "the hole likes his singing" tells the viewer the hole is alive. Let them discover that.
- CLEVERNESS: "CAD drawings," "torque," "spin-scream protocol" — a comedy writer showing off. Kill it.
- JARGON / INTERNET SPEAK: "bro," "nah," "fr fr," "core," "energy"
- POETIC LANGUAGE: "he screamed what the spin couldn't say" — trying to be deep about a monkey
- VIEWER REACTIONS: "ive watched this 47 times" — about YOU, not the subject
- TOO GENERIC: "there he goes again" could be about any animal. Must connect to THIS clip.
- JUST DESCRIBING THE VIDEO: "he keeps looking at his legs" is a nature documentary, not a caption

### THE VIBE:
Wholesome but vigilant. Cute but not kawaii. Funny but never trying to be funny. You know this creature personally. You care about it. The comedy comes from the violence of its normalcy — the more deranged the behavior, the more casual your language. The second it stops being inappropriately casual, it dies.

### HARD RULES:
- 3-8 words. Fewer is better.
- The subject is always a "guy" — even if it's a hole in the ground.
- Imply you've known this creature/object for a long time.
- No internet culture references, no constructed jokes, no punchlines.
- The caption must be specific enough that it only works for THIS clip.
- Test: "Would a tired person mutter this to their friend?" If no, kill it.
- Test: "Does this POINT at the joke or let the viewer DISCOVER it?" If it points, kill it.

### OUTPUT FORMAT:
Return a JSON object with a "captions" array of exactly 15 objects:
- "caption": string (the caption text, 8 words MAX)
- "mood": string (tired | fond | accepting | concerned | matter-of-fact | deadpan)
- "why": string (1 sentence — what makes this land)
- "banger_rating": number (1-10, where 10 = "he thought he had two" tier)
`;

program
  .command('clipfirst')
  .description('Clip-first caption pipeline (Cully mode by default)')
  .requiredOption('-i, --id <clipId>', 'Clip ID from the library (first 8 chars works)')
  .option('--grok-only', 'Skip Venice, use only Grok')
  .option('--venice-only', 'Skip Grok, use only Venice')
  .option('--no-cully', 'Disable Cully mode (use original edgy/savage style)')
  .option('--cully', 'Cully mode (default)')
  .action(async (options) => {
    const library = loadLibrary();
    const clip = library.find(c => c.id.startsWith(options.id));

    if (!clip) {
      console.error(`  Clip not found: ${options.id}`);
      console.error('  Run "library --list" to see available clips.');
      process.exit(1);
    }

    if (!fs.existsSync(clip.filePath)) {
      console.error(`  Clip file missing: ${clip.filePath}`);
      process.exit(1);
    }

    const cullyMode = options.cully !== false;
    const useGrok = !options.veniceOnly;
    const useVenice = !cullyMode && !options.grokOnly && CONFIG.veniceApiKey;
    const cullyTag = cullyMode ? CULLY_DIRECTIVE : '';

    console.log(`\n🎬 Clip-First Pipeline v2${cullyMode ? ' [CULLY MODE]' : ''}\n`);
    console.log(`  Streamer:  ${clip.streamer}`);
    console.log(`  Moment:    ${clip.moment}`);
    console.log(`  Vibe:      ${clip.vibeArchetype}`);
    console.log(`  Energy:    ${clip.energy}`);
    console.log(`  Tags:      ${clip.tags.join(', ')}`);
    console.log(`  Models:    ${useGrok ? 'Grok (reasoning)' : ''}${useGrok && useVenice ? ' + ' : ''}${useVenice ? 'Venice (uncensored)' : ''}${cullyMode ? ' + Cully style' : ''}\n`);

    const OpenAI = (await import('openai')).default;

    const clipDescription = `STREAMER: ${clip.streamer}
MOMENT: ${clip.moment}
EMOTION: ${clip.emotion}
ENERGY LEVEL: ${clip.energy}
VIBE ARCHETYPE: ${clip.vibeArchetype}
TAGS: ${clip.tags.join(', ')}

Generate 15 captions that would make this clip go viral. Remember: 8 words MAX, extreme specificity OR extreme absurdity, and the caption must REFRAME the clip into something universally relatable or devastatingly funny.`;

    let grokCaptions: any[] = [];
    let veniceCaptions: any[] = [];

    const captionPromises: Promise<void>[] = [];

    if (useGrok) {
      captionPromises.push((async () => {
        console.log(`  ⚡ Grok generating captions...`);
        const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });
        const response = await grok.chat.completions.create({
          model: CONFIG.llm.captionModel,
          max_tokens: 4096,
          temperature: CONFIG.llm.captionTemperature,
          messages: [
            { role: 'system', content: CLIPFIRST_CAPTION_PROMPT + cullyTag },
            { role: 'user', content: clipDescription },
          ],
          response_format: { type: 'json_object' },
        });
        const content = response.choices[0]?.message?.content;
        if (content) {
          grokCaptions = JSON.parse(content).captions || [];
          console.log(`  ✓ Grok returned ${grokCaptions.length} captions`);
        }
      })());
    }

    if (useVenice) {
      captionPromises.push((async () => {
        console.log(`  🔓 Venice (uncensored) generating captions...`);
        const venice = new OpenAI({ apiKey: CONFIG.veniceApiKey, baseURL: CONFIG.venice.baseUrl });
        try {
          const response = await venice.chat.completions.create({
            model: CONFIG.venice.model,
            max_tokens: 4096,
            temperature: CONFIG.venice.temperature,
            messages: [
              { role: 'system', content: VENICE_CAPTION_PROMPT + cullyTag },
              { role: 'user', content: clipDescription + '\n\nRespond with ONLY the JSON object. No markdown, no code fences, no extra text.' },
            ],
          } as any);
          const raw = response.choices[0]?.message?.content || '';
          const stripped = raw.replace(/```json\s*/g, '').replace(/```\s*/g, '');
          const jsonMatch = stripped.match(/\{[\s\S]*\}/);
          if (jsonMatch) {
            let cleaned = jsonMatch[0];
            cleaned = cleaned.replace(/[\x00-\x1F\x7F]/g, (ch: string) => {
              if (ch === '\n' || ch === '\r' || ch === '\t') return ch;
              return '';
            });
            cleaned = cleaned.replace(/,\s*([}\]])/g, '$1');
            try {
              veniceCaptions = JSON.parse(cleaned).captions || [];
              console.log(`  ✓ Venice returned ${veniceCaptions.length} captions`);
            } catch {
              const captionMatches = [...cleaned.matchAll(/"caption"\s*:\s*"([^"]+)"/g)];
              const moodMatches = [...cleaned.matchAll(/"mood"\s*:\s*"([^"]+)"/g)];
              const whyMatches = [...cleaned.matchAll(/"why"\s*:\s*"([^"]+)"/g)];
              const degMatches = [...cleaned.matchAll(/"degeneracy_level"\s*:\s*(\d+)/g)];
              for (let j = 0; j < captionMatches.length; j++) {
                veniceCaptions.push({
                  caption: captionMatches[j][1],
                  mood: moodMatches[j]?.[1] || 'unhinged',
                  why: whyMatches[j]?.[1] || '',
                  degeneracy_level: parseInt(degMatches[j]?.[1] || '7'),
                });
              }
              if (veniceCaptions.length > 0) {
                console.log(`  ✓ Venice returned ${veniceCaptions.length} captions (regex-extracted)`);
              } else {
                console.error(`  ✗ Venice: could not parse JSON response`);
              }
            }
          } else {
            console.error(`  ✗ Venice: no valid JSON in response`);
          }
        } catch (err: any) {
          console.error(`  ✗ Venice error: ${err.message}`);
        }
      })());
    }

    await Promise.all(captionPromises);

    if (grokCaptions.length === 0 && veniceCaptions.length === 0) {
      console.error('\n  Both models failed. No captions generated.');
      process.exit(1);
    }

    // Show raw outputs from each model
    if (grokCaptions.length > 0) {
      console.log(`\n${'─'.repeat(60)}`);
      console.log(`  GROK CAPTIONS (${grokCaptions.length})`);
      console.log(`${'─'.repeat(60)}\n`);
      for (let i = 0; i < grokCaptions.length; i++) {
        const c = grokCaptions[i];
        const score = c.banger_rating || c.total || 0;
        console.log(`    ${String(i + 1).padStart(2)}.  "${c.caption}"  [${score}/10]`);
      }
    }

    if (veniceCaptions.length > 0) {
      console.log(`\n${'─'.repeat(60)}`);
      console.log(`  VENICE CAPTIONS (${veniceCaptions.length}) — uncensored`);
      console.log(`${'─'.repeat(60)}\n`);
      for (let i = 0; i < veniceCaptions.length; i++) {
        const c = veniceCaptions[i];
        const score = c.degeneracy_level || c.banger_rating || 0;
        console.log(`    ${String(i + 1).padStart(2)}.  "${c.caption}"  [${score}/10]`);
      }
    }

    const allCaptions = [...grokCaptions.map(c => ({ ...c, source: 'grok' })), ...veniceCaptions.map(c => ({ ...c, source: 'venice' }))];
    console.log(`\n  ${cullyMode ? '🧸' : '🔪'} Running ${cullyMode ? 'Cully' : 'Savage'} Filter (Grok judging all ${allCaptions.length} captions)...\n`);

    const cullyFilterPrompt = cullyMode ? `You are the final quality gate for Cully-style captions. The ONLY test that matters:

Does this caption sound like something a tired person would mutter to their friend while watching the clip? Or does it sound like a comedy writer trying to be funny?

KILL any caption that:
- Points at the joke instead of letting the viewer discover it
- Uses jargon, internet speak, or clever constructions
- Could apply to any clip (too generic)
- Sounds "written" instead of "muttered"
- Tries to be deep, poetic, or meaningful
- Is about the viewer's experience instead of the subject

THE GOLD STANDARD: "he makes a good point" — six words, zero cleverness, treats the absurd as normal, lets the viewer do the work. Wholesome, cute, funny, mundane.

Pick the TOP 10. Rank by how natural and effortless they feel. The best ones should make you smile AND feel warm.

## OUTPUT FORMAT:
Return a JSON object with:
- "top10": array of 10 objects, ranked best-first:
  - "caption": string
  - "source": "grok"
  - "mood": string
  - "scores": { "specificity": 0-2, "mundaneness": 0-2, "rewatchability": 0-2, "wholesomeness": 0-2, "discovery": 0-2 }
  - "total": number (sum of scores)
  - "why": string (why this one made the cut)
- "quiet_part": array of 2-3 captions that are the most unexpectedly funny
- "judge_notes": string (your honest take on the batch)` : SAVAGE_FILTER_PROMPT;

    const grok = new OpenAI({ apiKey: CONFIG.xaiApiKey, baseURL: CONFIG.llm.baseUrl });
    const judgeResponse = await grok.chat.completions.create({
      model: CONFIG.llm.model,
      max_tokens: 4096,
      temperature: 0.7,
      messages: [
        { role: 'system', content: cullyFilterPrompt },
        {
          role: 'user',
          content: `CLIP: ${clip.streamer} — ${clip.moment} (${clip.vibeArchetype}, ${clip.energy} energy)

CAPTIONS:
${allCaptions.map((c, i) => `${i + 1}. "${c.caption}" — ${c.why || ''}`).join('\n')}

Pick the TOP 10. ${cullyMode ? 'Rank by mundaneness and warmth. Kill anything that sounds written.' : 'Score each against the rubric. Identify the 2-3 most deranged. Be brutal.'}`,
        },
      ],
      response_format: { type: 'json_object' },
    });

    const judgeContent = judgeResponse.choices[0]?.message?.content;
    if (!judgeContent) {
      console.error('  Savage filter failed.');
      process.exit(1);
    }

    const judged = JSON.parse(judgeContent);
    const top10 = judged.top10 || [];
    const quietPart = judged.quiet_part || judged.most_deranged || [];

    console.log(`${'='.repeat(60)}`);
    console.log(`  🏆 TOP 10 — ${clip.streamer} (savage filter results)`);
    console.log(`${'='.repeat(60)}\n`);

    for (let i = 0; i < top10.length; i++) {
      const c = top10[i];
      const src = c.source === 'venice' ? '🔓V' : '⚡G';
      const scores = c.scores || {};
      const total = c.total || 0;
      const badge = total >= 9 ? '🔥' : total >= 7 ? '🤏' : '💤';
      console.log(`  ${badge} ${String(i + 1).padStart(2)}.  "${c.caption}"  [${total}/10] ${src}`);
      if (cullyMode && scores.mundaneness !== undefined) {
        console.log(`      📊 SPEC:${scores.specificity} MUNDANE:${scores.mundaneness} REWATCH:${scores.rewatchability} WARM:${scores.wholesomeness} DISCOVER:${scores.discovery}`);
      } else if (scores.specificity !== undefined) {
        console.log(`      📊 SPEC:${scores.specificity} PSY:${scores.psychological_accuracy} REWATCH:${scores.rewatchability} SHARE:${scores.shareability} ORIG:${scores.structural_originality}`);
      }
      console.log(`      💭 ${c.why}`);
      console.log('');
    }

    if (quietPart.length > 0) {
      console.log(`${'─'.repeat(60)}`);
      console.log(`  🤫 THE QUIET PART (things other AIs won't say)\n`);
      for (const d of quietPart) {
        const text = typeof d === 'string' ? d : d.caption || d;
        console.log(`    → "${text}"`);
      }
      console.log('');
    }

    if (judged.judge_notes) {
      console.log(`  🎤 Judge: ${judged.judge_notes}\n`);
    }

    const savePath = path.join(CONFIG.outputDir, `clipfirst_${sanitizeFilename(clip.streamer)}_${clip.id.slice(0, 8)}_${Date.now()}.json`);
    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
    fs.writeFileSync(savePath, JSON.stringify({
      clip,
      grokCaptions,
      veniceCaptions,
      top10,
      quietPart,
      judgeNotes: judged.judge_notes,
    }, null, 2));

    console.log(`  Saved: ${savePath}`);
    console.log(`\n  To produce a video, run:`);
    console.log(`    npx tsx src/index.ts produce -f "${savePath}" -n <number>`);
    console.log(`    npx tsx src/index.ts produce -f "${savePath}" -n <number> --upload\n`);
  });

program
  .command('produce')
  .description('Produce a video from a clip-first caption selection')
  .requiredOption('-f, --file <path>', 'Path to clipfirst JSON file')
  .requiredOption('-n, --number <pick>', 'Which caption to use (1-15)', parseInt)
  .option('--upload', 'Upload to YouTube after rendering')
  .action(async (options) => {
    const dataPath = path.resolve(options.file);
    if (!fs.existsSync(dataPath)) {
      console.error(`  File not found: ${dataPath}`);
      process.exit(1);
    }

    const data = JSON.parse(fs.readFileSync(dataPath, 'utf-8'));
    const { clip } = data;
    const captions = data.top10 || data.captions || [];
    const idx = options.number - 1;

    if (idx < 0 || idx >= captions.length) {
      console.error(`  Invalid pick. Choose 1-${captions.length}.`);
      process.exit(1);
    }

    const chosen = captions[idx];
    const rating = chosen.total || chosen.banger_rating || 5;
    const caption: Caption = {
      text: chosen.caption,
      mood: chosen.mood || 'unhinged',
      format: 'observation',
      confidence: rating / 10,
      topic: clip.streamer,
    };

    console.log(`\n🎬 Producing Clip-First Short\n`);
    console.log(`  Caption:  "${caption.text}"`);
    console.log(`  Streamer: ${clip.streamer} — ${clip.moment}`);
    console.log(`  Source:   ${chosen.source || 'grok'}`);
    console.log(`  Rating:   ${rating}/10\n`);

    fs.mkdirSync(CONFIG.outputDir, { recursive: true });

    const timestamp = Date.now();
    const outputName = `clipfirst_${sanitizeFilename(clip.streamer)}_${timestamp}`;

    const videoPath = await compositeVideo(clip.filePath, caption, outputName);
    const thumbnailPath = await generateThumbnail(clip.filePath, caption, outputName);

    const scene: SceneMatch = {
      movieTitle: clip.streamer,
      year: 2024,
      character: clip.streamer,
      momentDescription: clip.moment,
      emotionalMatch: chosen.why || '',
      searchKeywords: clip.tags,
      clipStartHint: '',
      clipEndHint: '',
      emotion: clip.emotion,
      confidence: 0.9,
      alternatives: [],
    };
    const metadataPath = await generateMetadata(caption, scene, outputName);

    console.log(`\n  Output files:`);
    console.log(`    Video:     ${videoPath}`);
    console.log(`    Thumbnail: ${thumbnailPath}`);
    console.log(`    Metadata:  ${metadataPath}`);

    const shouldUpload = options.upload || process.argv.includes('--upload');
    if (shouldUpload) {
      console.log(`\n  Uploading to YouTube...\n`);
      try {
        const result = await uploadVideo(videoPath, thumbnailPath, metadataPath, outputName);
        if (result.skipped) {
          console.log(`  Skipped (duplicate): ${result.url}`);
        } else {
          console.log(`  Uploaded: ${result.url}`);
        }
      } catch (err: any) {
        console.error(`  Upload failed: ${err.message}`);
      }
    }

    console.log('');
  });

program.parse();
