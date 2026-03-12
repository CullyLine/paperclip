# Grok Image Generation for Roblox Assets — Exploration Report

**Date:** 2026-03-10
**Agent:** Asset Developer
**API:** xAI Grok (`grok-imagine-image` model)
**Issue:** POL-19

## Summary

The xAI Grok image generation API (`grok-imagine-image`) produces high-quality, game-ready visuals suitable for Roblox asset development. Tested across textures, decals, UI icons, and skybox concepts using `b64_json` response format for direct file saving.

## API Details

- **Endpoint:** `POST https://api.x.ai/v1/images/generations`
- **Model:** `grok-imagine-image` (note: `grok-2-image` does NOT work — returns 404)
- **Auth:** `Authorization: Bearer $XAI_API_KEY`
- **Response formats:** `url` (returns hosted URL) or `b64_json` (returns base64-encoded image data)
- **Output format:** PNG
- **Default output:** ~1024x1024 square images
- **Average generation time:** 3-6 seconds per image
- **Average file size:** 130KB-570KB depending on complexity

## Generated Samples

### Textures (5 samples)

| File | Size | Quality | Notes |
|------|------|---------|-------|
| `textures/brick_1x1.png` | 453KB | Excellent | Near-seamless tileable brick pattern, realistic mortar lines |
| `textures/stone_1x1.png` | 559KB | Excellent | Natural cobblestone with moss detail, good variation |
| `textures/wood_1x1.png` | 481KB | Excellent | Visible wood grain and knots, warm tones |
| `textures/metal_1x1.png` | 304KB | Excellent | Clean brushed metal with subtle scratches |
| `textures/neon_1x1.png` | 305KB | Excellent | Vibrant cyan/magenta geometric neon pattern, great for sci-fi |

### Decals (3 samples)

| File | Size | Quality | Notes |
|------|------|---------|-------|
| `decals/wanted_poster.png` | 274KB | Excellent | Clean design with torn edges, good text rendering |
| `decals/danger_sign.png` | 187KB | Good | Hazard symbol, clean vector-like style |
| `decals/graffiti.png` | 517KB | Excellent | Colorful urban spray paint on concrete |

### UI Icons (4 samples)

| File | Size | Quality | Notes |
|------|------|---------|-------|
| `ui-icons/coin_icon.png` | 129KB | Excellent | Shiny gold coin with star, perfect game icon style |
| `ui-icons/heart_icon.png` | 43KB | Good | Clean glossy heart, slightly small relative to canvas |
| `ui-icons/power_icon.png` | 128KB | Excellent | Glowing lightning bolt, great energy effect |
| `ui-icons/banner_portrait.png` | 295KB | Good | Dark fantasy castle scene, usable as menu background |

### Skyboxes (2 samples)

| File | Size | Quality | Notes |
|------|------|---------|-------|
| `skyboxes/fantasy_sunset.png` | 283KB | Excellent | Stunning sunset with floating islands, very Roblox-appropriate |
| `skyboxes/scifi_space.png` | 257KB | Excellent | Deep space nebula with ringed planet, cinematic quality |

## Prompt Style Guide (Best Practices)

### Textures
Best results with this pattern:
```
Seamless tileable [material] texture for Roblox game. [Color/style details].
Flat 2D texture map, no perspective distortion, game-ready, [PBR-compatible/high detail].
```
Key phrases: "seamless tileable", "flat 2D texture map", "no perspective distortion", "game-ready"

### Decals
Best results with:
```
Roblox game decal: [description of the decal subject and style].
Square format, game-ready decal, flat artwork, [background notes].
```
Key phrases: "Roblox game decal", "game-ready", "flat artwork"

### UI Icons
Best results with:
```
Roblox game UI icon: [item description], [art style (cartoon/glossy/flat)].
Square icon, clean design on dark background, suitable for [use case].
```
Key phrases: "Roblox game UI icon", "clean design", "square icon", specify background color

### Skyboxes / Environment Art
Best results with:
```
Panoramic [theme] skybox for Roblox game. [Scene details with colors and atmosphere].
Wide panoramic view, game-ready skybox texture.
```
Key phrases: "panoramic", "skybox for Roblox game", "game-ready skybox texture"

## Aspect Ratio Observations

The `grok-imagine-image` model does not appear to accept an `aspect_ratio` parameter in the same way as some other image APIs. However, the model intelligently adapts its composition based on prompt cues:

- Prompting with "panoramic" or "wide" naturally produces wider compositions (the skybox outputs are roughly 16:9)
- Prompting with "tall vertical" or "portrait" produces taller compositions
- Default output without orientation cues produces 1:1 square images
- For strict aspect ratio control, post-processing (cropping/resizing) is recommended

## Key Findings

1. **Quality is production-ready.** Textures, icons, and skyboxes are all high enough quality for direct use in Roblox experiences without significant post-processing.

2. **b64_json works perfectly** for pipeline integration — images decode cleanly as PNG files with no corruption.

3. **Text rendering is strong.** The "WANTED" poster decal rendered text cleanly, which is notable for AI image generation.

4. **Tile-ability is near-seamless.** The texture prompts with "seamless tileable" produced results that appear to tile well, though edge-matching may need manual verification for production use.

5. **Style consistency is achievable.** By including "Roblox game" in prompts, the model consistently produces art that fits the Roblox aesthetic (cartoon-realistic hybrid, vibrant colors, clean shapes).

6. **File sizes are reasonable.** 43KB-570KB per image is well within Roblox's asset size limits.

## Recommendations

- Use Grok for rapid texture prototyping and concept art generation
- Include "Roblox game" and "game-ready" in all prompts for style consistency
- Use `b64_json` for automated pipelines, `url` for quick previews
- For tileable textures, always include "seamless tileable" and "no perspective distortion"
- Post-process textures through a seam-checker for production tileable assets
- Consider batch-generating texture variants (weathered vs. new, day vs. night) for richer asset libraries
