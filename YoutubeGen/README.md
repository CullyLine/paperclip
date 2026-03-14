# YouTube Shorts Generator

Automated pipeline that generates YouTube Shorts in the viral "black bar caption + movie reaction clip" format.

## Format

- **Top ~25%**: Black bar with centered white text caption
- **Bottom ~75%**: Movie/TV clip matching the caption's vibe
- **Output**: 1080x1920 (9:16) MP4 + thumbnail PNG + metadata JSON

## Prerequisites

- **Node.js** 20+
- **FFmpeg** installed and on PATH
- **yt-dlp** installed and on PATH
- **xAI API key** (for Grok-powered captions and scene matching)

## Setup

```bash
# Install dependencies
npm install

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your API keys
```

## Usage

```bash
# Generate a short about a specific topic
npm start -- --topic "rent prices"

# Generate 5 shorts from auto-discovered trending topics
npm start -- --batch 5
```

## Output

Each generated short produces three files in the `output/` directory:

- `short_<topic>_<timestamp>.mp4` - The finished YouTube Short video
- `short_<topic>_<timestamp>_thumb.png` - YouTube-optimized thumbnail
- `short_<topic>_<timestamp>_metadata.json` - Upload-ready metadata (title, description, hashtags, tags)

## Architecture

```
CLI Orchestrator (index.ts)
  |
  +-> Trend Discovery (trend-discovery.ts)
  +-> Caption Generator (caption-generator.ts)
  +-> Scene Matcher (scene-matcher.ts)
  +-> Clip Acquisition (clip-acquisition.ts)
  +-> Video Compositor (video-compositor.ts)
  +-> Thumbnail Generator (thumbnail-generator.ts)
  +-> Metadata Generator (metadata-generator.ts)
```

## Clip Cache

Downloaded clips are cached in `cache/clips.db` (SQLite) and reused across runs. The cache grows over time, reducing redundant downloads.

## LLM Provider

This project uses **xAI Grok** (`grok-4.20-beta-latest-non-reasoning`) via the OpenAI-compatible API at `https://api.x.ai/v1`. Set `XAI_API_KEY` in your `.env` file. Graceful fallbacks are used when no API key is configured.
