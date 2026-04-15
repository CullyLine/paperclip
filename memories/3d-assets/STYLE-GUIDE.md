# 3D Asset Style Guide (for Agents)

**This document is mandatory reading for any agent working on 3D assets.**

## Philosophy
We maintain **one core pipeline** but support multiple visual directions through **style profiles**. This prevents style bleed (e.g. turning a full-size character into a chibi pet).

- `full-character` (default): Faithful, clean, commercial-quality assets for the Roblox Creator Store.
- `chibi-pets`: The original toy-like style for Drive A Car Simulator pets.
- `prop`: Weapons, tools, and accessories sold alongside characters.

## How to Choose Style
- User says "pet", "chibi", "for the game", or mentions rarity colors → use `chibi-pets`
- User says "asset store", "sell on Roblox", "full size", "realistic proportions", or shows a non-chibi reference → use `full-character` (default)
- User says "weapon", "bat", "accessory", "prop", "tool" → use `prop`
- Always confirm if unclear.

## Core Pipeline (New Unified Command)

```bash
python memories/3d-assets/pipeline.py generate \
  --style full-character \
  --reference path/to/reference.png \
  --name StoreTungTung
```

## Style Profiles Location
`memories/3d-assets/styles/`

Each JSON file contains:
- Prompt modifiers for Hunyuan3D
- Decimation targets (target_faces, voxel_size)
- Polish parameters (saturation, contrast, brightness, AO)
- Rigging strategy
- Post-processing rules

## Reference Image Generation (FLUX Pro)

When you need to create a reference image from scratch (no existing concept art):

**Model:** `fal-ai/flux-pro/v1.1` (text-to-image)

```python
payload = {
    "prompt": "<character/object description>, low poly 3D game asset style, smooth surface, no visible wood grain, no texture lines, centered on pure white background, full length visible, soft even lighting, simple game prop, matte finish",
    "image_size": {"width": 512, "height": 768},
    "num_images": 4,
    "output_format": "png",
    "safety_tolerance": "5",
}
```

**Rules:**
- Always generate **4 variants** and let the user pick the best one
- Avoid photorealistic keywords — match the cartoon 3D style of the target
- For characters: include "low poly 3D game asset style, smooth surface"
- For props: include "simple game prop, matte finish, no knots, no realistic textures"
- Save chosen reference as `<Name>-reference.png` in the asset's output directory

## T-Pose Conversion (full-character only)

Before submitting a character reference to Hunyuan3D, run it through **FLUX.1 Kontext [pro]** (`fal-ai/flux-pro/kontext`) to convert into a T-pose. This is critical because:
- Arms stuck to the body will fuse during mesh generation and decimation
- T-pose gives Anymate much better bone placement on arms/hands
- Kontext preserves the character's exact appearance while only changing the pose

### T-Pose Requirements (CRITICAL)

- Arms stretched straight out horizontally
- **Palms MUST face DOWN (toward the ground)** — NOT up toward the sky
- This is required for Mixamo compatibility and correct animation retargeting
- If palms face up, every animation will have twisted wrists and wrong joint bending
- Include "palms facing downward" explicitly in the Kontext prompt

The prompt template is stored in `full-character.json` under `tpose_conversion`.

```python
payload = {
    "image_url": "<reference image URL or data URL>",
    "prompt": "Change the pose of this character so both arms are stretched straight out horizontally to the sides in a T-pose position, palms facing downward. Keep everything else about the character exactly the same. White background.",
    "guidance_scale": 3.5,
    "safety_tolerance": "5",
}
```

## Object Extraction (SAM 3)

Use **SAM 3** (`fal-ai/sam-3/image`) to extract specific objects from reference images — weapons, tools, accessories, props. Send the image with a text prompt (e.g. `"baseball bat"`, `"sword"`, `"shield"`) and it returns a pixel-perfect mask + isolated image.

```python
payload = {
    "image_url": "<reference>",
    "prompts": [{"type": "text", "text": "baseball bat"}],
    "apply_mask": True,
}
```

**If the extracted object is partially occluded:** Do NOT try to inpaint — inpainting models (FLUX Fill, Kontext) tend to change the style. Instead, generate a clean standalone reference with FLUX Pro text-to-image, matching the color and style of the original.

Reference implementation: `memories/3d-experiments/StoreAssets/_extract_club_sam.py`

## Voxel Size Reference (critical)

This table was built from hard-won experimentation. Follow it strictly.

| voxel_size | Use case | Notes |
|------------|----------|-------|
| **0.006** | Rigging intermediate (5K faces) | Preserves all detail for Anymate bone placement |
| **0.012** | Game mesh characters (1000-1500 faces) | Preserves hand/finger detail in T-pose characters |
| **0.025** | Simple props (100-200 faces) | Good for bats, clubs, simple weapons |
| **0.032** | Chibi pets (300-400 faces) | Standard for pet pipeline |
| **0.05+** | **NEVER on thin features** | **Limbs and fingers WILL split apart. Do NOT use on T-pose characters.** |

## Rigging Strategy: Mixamo vs Anymate

Choosing the right rigging approach depends on the model type:

| Model type | Rigging tool | Why |
|------------|-------------|-----|
| **Humanoid character (commercial)** | **Mixamo** (recommended) | 25-bone industry-standard skeleton, perfect weights, compatible with thousands of free animations. Precise, human-readable, editable bones. |
| **Humanoid character (fallback)** | Custom skeleton script | When Mixamo upload isn't feasible. Builds 22 Mixamo-named bones from mesh landmarks. |
| **Creatures (4+ legs, non-humanoid)** | **Anymate** | Handles arbitrary topologies (dragons, spiders, etc.) that Mixamo can't process. Good enough for game polish and procedural animation. Not tested extensively yet — may need manual cleanup. |
| **Pets (chibi, in-game)** | **Anymate** | Quick auto-rig, good enough for DAC's procedural PetAnimator. Doesn't need precise bones. |
| **Props** | **None** | No rigging. Ship as raw mesh. |

### Mixamo Workflow (humanoid characters)

**Best results for characters that need animations:**

1. Build initial mesh (Hunyuan3D → decimate → polish)
2. Export mesh-only FBX (no armature, no rotation): `_build_mixamo_bundle.py` or manual export
3. Upload to [mixamo.com](https://mixamo.com) — let Mixamo auto-rig (place chin, wrists, elbows, knees, groin markers)
4. Download T-Pose **"with skin"** — this gives you Mixamo's skeleton + perfect weights on your mesh
5. Download any animations **"without skin"** — just skeleton + animation data
6. Bundle everything: `_build_mixamo_bundle.py` takes the T-Pose FBX (with skin), your textured GLB, and animation FBXs → outputs a single GLB with all animations

```bash
& "F:\SteamLibrary\steamapps\common\Blender\blender.exe" --background --python memories/3d-experiments/StoreAssets/_build_mixamo_bundle.py -- our_mesh.glb T-Pose.fbx anim_folder/ output.glb
```

**Mixamo gives you 25 bones:** the 22-joint SMPL standard plus HeadTop_End, LeftToe_End, RightToe_End.

**Key rules:**
- Do NOT rotate the mesh before uploading to Mixamo — let Mixamo handle orientation
- Download T-Pose "with skin" for weights, all other animations "without skin"
- The bundle script uses Mixamo's mesh + weights directly, applies YOUR texture on top

### Anymate Workflow (creatures, pets)

For non-humanoid models where Mixamo won't work:

```bash
python memories/3d-experiments/rig-anymate.py <name>
```

Anymate typically produces 30-50+ bones with numeric names. Run `name-bones.py` afterward to rename. Quality varies — may need manual bone cleanup in Blender.

## Custom Skeleton (fallback rigging)

When Anymate produces a bad skeleton (extra/misplaced bones, severe weight bleed, quota exceeded), use the custom skeleton builder:

```bash
& "F:\SteamLibrary\steamapps\common\Blender\blender.exe" --background --python memories/3d-experiments/StoreAssets/_build_clean_skeleton.py -- input.glb output-rigged.glb
```

What it does:
- Builds **22 Mixamo-compatible bones** from mesh geometric landmarks (not from AI prediction)
- Uses **Mixamo bone names** (Hips, Spine, Spine1, Spine2, LeftArm, RightUpLeg, etc.)
- Detects shoulder line by finding where mesh width expands significantly
- Calculates shoulder offset dynamically from torso half-width
- **Side isolation**: left bones only affect left-side vertices, and vice versa
- **Cubic falloff weights** (1/d³) with 0.15 threshold to prevent bleed between limbs

### 22-Bone Skeleton (Mixamo-compatible)

The skeleton matches the SMPL/Mixamo 22-joint standard exactly:

| Bone | Parent | Purpose |
|------|--------|---------|
| Hips | ROOT | Root/pelvis |
| Spine | Hips | Lower spine |
| Spine1 | Spine | Mid spine |
| Spine2 | Spine1 | Chest |
| Neck | Spine2 | Neck |
| Head | Neck | Head |
| LeftShoulder / RightShoulder | Spine2 | Collar bones |
| LeftArm / RightArm | Shoulder | Upper arms |
| LeftForeArm / RightForeArm | Arm | Forearms |
| LeftHand / RightHand | ForeArm | Hands |
| LeftUpLeg / RightUpLeg | Hips | Thighs |
| LeftLeg / RightLeg | UpLeg | Shins |
| LeftFoot / RightFoot | Leg | Feet |
| LeftToeBase / RightToeBase | Foot | Toes |

**Why Mixamo names matter:** Any animation downloaded from Mixamo, or any SMPL-based AI animation, will map directly to these bones with zero retargeting.

### Applying Mixamo Animations

```bash
& "F:\SteamLibrary\steamapps\common\Blender\blender.exe" --background --python memories/3d-experiments/StoreAssets/_apply_mixamo_anim.py -- character.glb animation.fbx output.glb
```

The script strips the `mixamorig:` prefix and applies the action directly. Works with Blender 5.x layered actions.

**When to use custom skeleton:**
1. Anymate GPU quota exceeded
2. Anymate skeleton has extra/misplaced leg joints or foot bones
3. Arm joints are positioned too high or too far into the torso
4. Weight bleed: rotating one limb moves adjacent limbs

**Recommended workflow for best animation results:**
1. Build skeleton with `_build_clean_skeleton.py`
2. Manually adjust bone positions in Blender if needed
3. Export mesh-only FBX (no armature) for Mixamo upload
4. Let Mixamo auto-rig and apply animation
5. Download FBX "with skin" and use directly

## Prop Pipeline (no rigging)

For weapons, tools, and accessories sold alongside characters:

1. **Get reference**: SAM 3 extraction from character reference, OR generate standalone with FLUX Pro
2. **Submit to Hunyuan3D v3**: Same as characters
3. **Decimate**: target_faces=150, voxel_size=0.025
4. **Polish**: saturation +10%, contrast +5%
5. **Export GLB**: No armature, no bones — pure mesh + texture
6. Verify poly count is in 100-200 range

Reference implementations in `memories/3d-experiments/StoreAssets/`:
- `_generate_club.py` — FLUX Pro reference generation
- `_pipeline_club.py` — Hunyuan3D submission
- `_decimate_club.py` — Blender decimation
- `_polish_club.py` — Texture polish

## Thumbnail Pipeline

For Creator Store listings, render a professional thumbnail:

### Step 1: Blender render
Import all models into a scene, set up camera + 3-point lighting (key, fill, rim), render at 1024x1024.

Reference: `memories/3d-experiments/StoreAssets/_render_thumbnail.py`

Key settings:
- Dark gray background (0.25, 0.25, 0.28)
- 50mm lens, Cycles renderer, 128 samples
- Models placed side-by-side, character on left, accessory on right
- Camera distance: `max(height, width) * 2.1`

### Step 2: PIL text overlay
Add character name in Unity Asset Store style — white bold text on a dark rounded pill at the bottom.

Reference: `memories/3d-experiments/StoreAssets/_add_text_overlay.py`

Note: PIL is not available in Blender's Python — run the overlay as a separate step with system Python.

## Creator Store Listing

### Title formula
`"[Character Name] + [Accessory] | Low-Poly Rigged Character"`

### Price guidance
- Individual character + accessory: $1.99–$4.99
- Character bundle (5-10 characters): $9.99–$14.99
- $2.99 is a strong starting price for trending characters

### Tags
Include: character name, meme/franchise name, "low poly", "rigged", "game ready", "character model", genre-specific tags

### Description template
```
[Character Name] — fully rigged character with [accessory] accessory.

WHAT'S INCLUDED:
- Rigged [character] character ([N] named bones, game-ready)
- Separate [accessory] prop (no armature, attach to hand bone)
- Baked textures on both assets

STATS:
- Character: [X] tris / [Y] verts
- [Accessory]: [X] tris / [Y] verts
- Combined: [X] tris — less than most Roblox accessories
- Total file size: ~[X] MB

RIGGING:
- 25 Mixamo-standard bone names (Hips, Spine, Spine1, Spine2, LeftArm, RightUpLeg, etc.)
- Clean weight painting (Mixamo auto-weights)
- T-pose default — easy to animate
- Compatible with industry-standard animation tools

IMPORTANT:
- This is a 3D MODEL ONLY — no scripts, no code included
- Roblox version: no animations (Roblox Creator Store does not allow KeyframeSequences in sold models)
- Other platforms (Sketchfab, itch.io): animations can be bundled in the GLB

OPTIMIZED FOR ROBLOX:
- Ultra low-poly, runs great even on mobile
- [X] total polys is less than a single default Roblox accessory
- Clean hierarchy, proper scale and orientation
- Ready to drop into any game
```

### Animation distribution
- **Roblox Creator Store does NOT allow selling models with KeyframeSequences** — the model will be blocked from sale
- **Roblox animations are account-locked** — other players cannot use your published animation IDs
- **Roblox Animation Editor requires Motor6Ds** — skinned mesh imports from GLB don't have these
- **For Roblox:** sell the rigged model only (no animations). Animations must be distributed separately (Google Drive link, or sold on other platforms)
- **For other platforms** (Sketchfab, Unity Asset Store, itch.io): sell the GLB with all animations embedded — it just works
- **Mixamo workflow:** Download animations "without skin" from Mixamo, bundle into GLB using `_build_mixamo_bundle.py`. The 22-bone Mixamo-compatible skeleton ensures direct compatibility

### Promotion strategy
- Roblox Ads Manager only supports Experiences, not Creator Store models
- Sponsored Items only works for Marketplace avatar items, not models
- Effective channels: DevForum Community Resources, TikTok/YouTube Shorts, Discord dev communities
- Volume matters: build a collection (5-10 models in a series) for better discoverability
- Timing matters: trending meme characters should be listed quickly while the trend is hot

## Rules for Agents
1. **Never hardcode chibi keywords** unless `--style chibi-pets` is explicitly used.
2. For commercial Asset Store models, prioritize clean topology, proper bone naming, good edge flow, and commercial-friendly scale/orientation.
3. Always load the style JSON at the start of any 3D task.
4. When in doubt, default to `full-character`.
5. Props ship with **no rigging** — do not add bones to weapons/accessories.
6. Always verify final poly count with a check script before declaring done.
7. Generate thumbnails for any asset intended for sale.

This system allows us to support both the existing Roblox game **and** a line of sellable 3D assets without conflict.

Last updated: April 14, 2026
