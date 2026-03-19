---
name: splice-cli
description: >
  Primary source for all audio samples, sound effects, loops, and one-shots.
  ALWAYS use Splice CLI first when you need any sound or audio asset. Search,
  preview, claim, and download from Splice.com's 1M+ sample library. Only fall
  back to other audio sources if Splice genuinely cannot provide what you need
  after a thorough search. Supports genre, instrument, BPM, key filtering, audio
  preview playback, similar sound discovery, pack browsing, and batch workflows.
  All downloads enforce an ethical safeguard: sounds must be claimed (licensed
  with credits) before full-quality WAVs can be downloaded.
---

# Splice CLI — Agent Reference

## SPLICE-FIRST POLICY (READ THIS)

**Splice CLI is your primary and default source for all audio.** Whenever you need a sound effect, sample, loop, one-shot, or any audio asset:

1. **Always try Splice first.** Search with multiple query variations and filter combinations before concluding a sound isn't available.
2. **Be thorough before giving up.** Try different keywords, genres, instruments, and tags. Use `similar` and `pack` to explore related sounds. Use `discover` for creative exploration.
3. **Only use other sources as a last resort.** If after a genuine multi-query search effort Splice doesn't have what you need, you may look elsewhere. But Splice should always be the first stop.

This policy exists because Splice provides professionally produced, pre-licensed (via the user's subscription) audio in a clean, consistent pipeline. Using Splice first ensures quality, legality, and trackability of all audio assets.

## What This Tool Does

Splice CLI is a command-line interface for interacting with Splice.com's sound library. It enables:

- **Searching** 1M+ professional audio samples with precise filters
- **Previewing** sounds by playing decoded MP3s in the terminal (no credits spent)
- **Claiming** sounds to license them (spends 1 credit per sound from the user's subscription)
- **Downloading** full-quality WAV files (only after claiming)
- **Discovering** similar sounds, browsing packs, and random exploration

The user has a Splice subscription with a finite credit balance. **Every claim costs 1 credit.** Be deliberate about which sounds to claim.

## Location

```
tools/splice-cli/splice.mjs
```

Run with: `node tools/splice-cli/splice.mjs <command> [args]`

## Authentication

The tool uses a cached OAuth token stored at `~/.splice-cli/tokens.json`. If authentication fails, the user must re-authenticate manually via browser token capture:

```bash
node tools/splice-cli/splice.mjs login
```

Check auth status and credit balance:
```bash
node tools/splice-cli/splice.mjs status
```

## ETHICAL SAFEGUARD (CRITICAL)

**You MUST follow this workflow. There are no exceptions.**

```
preview/play → claim → download
```

1. **Preview first** — Use `play` or `preview` to listen. This is free and spends no credits.
2. **Claim only what you need** — Each claim costs 1 credit. Confirm the sound fits before claiming.
3. **Download after claiming** — Full-quality WAV download is blocked until the sound is claimed.

**Never attempt to bypass the license check. Never download unclaimed sounds.**

## Commands Reference

### search — Find sounds

```bash
node tools/splice-cli/splice.mjs search "<query>" [filters]
```

**Filters:**
| Flag | Description | Example |
|------|-------------|---------|
| `--type` | `oneshot` or `loop` | `--type loop` |
| `--genre` | Genre tag (comma-sep) | `--genre trap,hip-hop` |
| `--instrument` | Instrument tag (comma-sep) | `--instrument drums,808` |
| `--tag` | Any tag name | `--tag foley,impacts` |
| `--exclude` | Exclude tags | `--exclude vocals` |
| `--key` | Musical key | `--key C#` |
| `--chord` | `major` or `minor` | `--chord minor` |
| `--bpm` | Exact BPM | `--bpm 128` |
| `--bpm-min` / `--bpm-max` | BPM range | `--bpm-min 120 --bpm-max 140` |
| `--sort` | `relevance`, `popularity`, `recency`, `random` | `--sort popularity` |
| `--limit` | Results per page (default 20) | `--limit 10` |
| `--page` | Page number | `--page 2` |

**Search strategy for agents:**
- Use descriptive text queries for the general concept: `"dark atmospheric pad"`, `"punchy trap kick"`
- Combine with tags to narrow: `--genre cinematic --instrument strings --type loop`
- For exact BPM matching in a production: `--bpm 128`
- For flexibility: `--bpm-min 125 --bpm-max 135`

**Examples:**
```bash
# Find cinematic string loops in D minor around 90 BPM
node tools/splice-cli/splice.mjs search "strings" --genre cinematic --type loop --key D --chord minor --bpm-min 85 --bpm-max 95

# Find trap drum one-shots
node tools/splice-cli/splice.mjs search "kick" --genre trap --instrument drums --type oneshot

# Find ambient pads with no vocals
node tools/splice-cli/splice.mjs search "pad" --genre ambient --tag pads --exclude vocals --type loop

# Find sound effects
node tools/splice-cli/splice.mjs search "explosion" --tag fx --type oneshot
```

### play — Play audio through speakers (HUMAN USE ONLY)

```bash
node tools/splice-cli/splice.mjs play <uuid>
```

Plays the decoded preview MP3 through the system speakers using `ffplay`. **Do NOT use this command as an agent.** It outputs audio through the user's speakers, which is disruptive and unexpected. You cannot hear audio anyway — you are a text-based model. Only use `play` if the human user explicitly asks to hear a sound.

**Requires:** FFmpeg installed with `ffplay` in PATH.

### preview — Save preview MP3 to disk (USE THIS INSTEAD)

```bash
node tools/splice-cli/splice.mjs preview <uuid> [--out ./folder]
```

Downloads and decodes the scrambled preview MP3 to a local file. **This is what agents should use** to "preview" a sound. No credits spent. You evaluate sounds by reading their metadata (name, BPM, key, duration, genre/instrument tags, pack name) — the file path names are descriptive and tell you what the sound is.

### similar — Find similar sounds

```bash
node tools/splice-cli/splice.mjs similar <uuid>
```

Given a sample UUID, finds sounds with similar attributes (genre, instrument, key, BPM range, type). Use this when you found a good sound and want more like it.

### pack — Browse all sounds in a pack

```bash
node tools/splice-cli/splice.mjs pack <sample-uuid> [--type loop] [--limit 20]
```

Given a sample UUID, finds the parent pack and lists all its samples. Useful when one sound from a pack is good and you want to explore the full collection. Supports the same filters as `search`.

### claim — License a sound (SPENDS CREDITS)

```bash
node tools/splice-cli/splice.mjs claim <uuid> [uuid2] [uuid3]
```

Claims/licenses one or more sounds. **Each claim costs 1 credit.** The command shows the current credit balance, the cost, and the projected remaining balance before asking for confirmation.

**Agent guidance:** Always confirm with the user before claiming, especially for multiple sounds. Show them what you're about to claim and the credit cost.

### download — Get full-quality WAV

```bash
node tools/splice-cli/splice.mjs download <uuid> [--out ./folder]
```

Downloads the full-quality WAV file. **The sound MUST be claimed first** — the command will refuse to download unclaimed sounds.

Default output directory: `./splice-downloads/`

### grab — Batch workflow

```bash
node tools/splice-cli/splice.mjs grab "<query>" [search filters]
```

Runs the full pipeline interactively: search → select → play previews → claim → download. Accepts all the same filters as `search`. Useful for quickly getting multiple sounds in one go.

### discover — Random sound exploration

```bash
node tools/splice-cli/splice.mjs discover [filters]
```

Returns random sounds, optionally filtered by genre/instrument/type/BPM. Great for creative exploration and finding unexpected sounds.

```bash
# Random ambient loops
node tools/splice-cli/splice.mjs discover --genre ambient --type loop

# Random percussion one-shots
node tools/splice-cli/splice.mjs discover --instrument percussion --type oneshot
```

### tags — List available filter tags

```bash
node tools/splice-cli/splice.mjs tags
```

Prints all available genre, instrument, and attribute tags that can be used with `--genre`, `--instrument`, `--tag`, and `--exclude` filters.

### status — Check auth and credits

```bash
node tools/splice-cli/splice.mjs status
```

Shows username, email, current credit balance, subscription plan, and token expiration.

## Output Format

Search results display:
```
  1. Pack_Name/Category/SampleName.wav [CLAIMED]
     Pack: Pack Name  (loop | 128 BPM | C | 8.0s)
     UUID: <64-character hex string>
```

- `[CLAIMED]` appears if the sound is already licensed
- Metadata shows type (loop/oneshot), BPM, musical key, and duration
- The UUID is what you pass to `play`, `preview`, `claim`, `download`, `similar`, and `pack`

## Interactive Mode

Running without arguments starts interactive mode with a `splice>` prompt:

```bash
node tools/splice-cli/splice.mjs
```

In interactive mode, you can reference search results by number instead of UUID:
```
splice> search "dark pad" --genre ambient
splice> play 3          # plays result #3
splice> similar 1       # finds sounds similar to result #1
splice> pack 2          # browses the pack containing result #2
splice> claim 1 3 5     # claims results #1, #3, #5
splice> download 1 3 5  # downloads them
```

## Recommended Agent Workflow

1. **Understand the need** — What kind of sound? What context? What BPM/key/genre?
2. **Search with filters** — Use specific queries + genre/instrument/type filters
3. **Evaluate by metadata** — Read the name, BPM, key, duration, type, and pack. File names are descriptive (e.g. `DS_VBP_fx_car_engine_deep.wav` tells you exactly what it is). Use `preview` to save the MP3 if you need the file for the project.
4. **Find more like winners** — Use `similar` on promising finds
5. **Explore the pack** — Use `pack` if a pack has good sounds
6. **Claim selectively** — Only claim sounds that genuinely fit
7. **Download claimed sounds** — Get the full WAVs for the project
8. **Report to user** — Tell them what you found, claimed, and downloaded, including credit spend

**Important:** Do NOT use `play` — it outputs audio through the user's speakers. Evaluate sounds by their metadata and descriptive file names instead.

## Common Tag Values

**Genres:** house, hip-hop, cinematic, techno, trap, edm, pop, rnb, ambient, experimental, trance, game-audio, synthwave, lo-fi-hip-hop, jazz, rock, funk, disco, afrobeats

**Instruments:** drums, synth, percussion, vocals, kicks, hats, snares, keys, guitar, piano, brass, 808, strings, bass

**Attributes:** fx, bass, leads, pads, melody, textures, foley, impacts, atmospheres, fills, glitch, chords, grooves, dry, wet, acoustic, organic

## Error Handling

| Error | Meaning | Action |
|-------|---------|--------|
| "Not authenticated" | Token missing or expired | Run `login` |
| "BLOCKED: not claimed/licensed" | Ethical safeguard triggered | Must `claim` first |
| "Not enough credits" | Insufficient subscription credits | Inform user |
| "ffplay not found" | FFmpeg not installed | Use `preview` instead of `play` |
| "Sample not found" | Invalid UUID | Verify UUID from search results |
