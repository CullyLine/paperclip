---
name: roblox-hunyuan3d-pipeline
description: >
  Image-to-3D for Roblox (fal Hunyuan3D v3 textured mesh) plus Blender decimation
  and texture baking. Use when generating pets, props, or characters from concept
  art, or when the user asks for Hunyuan / fal 3D / low-poly game-ready GLB.
---

# Roblox — Hunyuan3D + decimate pipeline

## Rules (non-negotiable)

1. **Always use textured generation for shipping assets** — queue app  
   `fal-ai/hunyuan3d-v3/image-to-3d` with body `{"input_image_url": "<url or data URL>"}`.  
   **Do not** use `fal-ai/hunyuan3d/v2` for final in-game art; v2 is a fast **geometry-first** pass with little or no meaningful PBR paint, so models look flat or "untextured" compared to v3.

2. **Why v2 looked untextured** — Hunyuan3D **v2** optimizes for quick mesh reconstruction. **v3** runs the full texturing / material pipeline (larger GLB, ~2+ minutes, higher cost). If you need a cheap shape check only, v2 is fine; for Roblox inventory/pets, **always v3**.

3. **Auth** — set `FAL_KEY` in the environment. Never hardcode keys in scripts.

4. **Know which product line you're building for.** The pipeline has three tracks with different parameters:

| Track | Use case | target_faces | voxel_size | Rigging |
|-------|----------|--------------|------------|---------|
| **Pet / follower** | In-game companions (DAC) | 340 | 0.032 | Anymate auto-rig |
| **Commercial humanoid** | Roblox Creator Store / sale | 1000–1500 | 0.012 | **Mixamo** (recommended) or custom skeleton |
| **Creature (non-humanoid)** | 4+ legged, unusual topology | 1000–1500 | 0.012 | Anymate (untested on all creature types) |
| **Prop / accessory** | Weapons, tools, items for sale | 100–200 | 0.025 | None |

## Reference image

### Option A — You have a reference image
Use the same formula that worked in `memories/3d-experiments` onboarding:

- Single subject, **centered**, **front or three-quarter** view  
- **Pure white background**  
- **Product / studio** lighting  

### Option B — Generate a reference with FLUX Pro
When you need to create a reference from scratch (e.g. a meme character, original design):

```python
# fal-ai/flux-pro/v1.1 — text-to-image
payload = {
    "prompt": "<description>, low poly 3D game asset style, smooth surface, centered on pure white background, full length visible, soft even lighting",
    "image_size": {"width": 512, "height": 768},
    "output_format": "png",
    "safety_tolerance": "5",
    "num_images": 4,  # generate 4 variants, pick the best
}
```

Always generate **4 images** and let the user pick. Adjust the prompt for the exact style needed — avoid photorealistic wood grain, detailed textures, etc. if the target is stylized/cartoon.

### T-pose conversion (characters with limbs)
Before submitting a character to Hunyuan3D, run the reference through **FLUX.1 Kontext [pro]** (`fal-ai/flux-pro/kontext`) to convert to T-pose. This is critical because:
- Arms stuck to the body will fuse during mesh generation and decimation
- T-pose gives Anymate much better bone placement on arms/hands
- Kontext preserves the character's exact appearance while only changing the pose

**CRITICAL: Palms must face DOWNWARD (toward the ground).** This is the standard T-pose convention required by Mixamo, SMPL, and all animation retargeting systems. Palms facing up will cause twisted wrists and backwards joint bending in every animation. Always include "palms facing downward" in the prompt.

```python
# fal-ai/flux-pro/kontext — image-to-image pose change
payload = {
    "image_url": "<reference image URL or data URL>",
    "prompt": "Change the pose of this character so both arms are stretched straight out horizontally to the sides in a T-pose position, with palms facing downward toward the ground. Keep everything else about the character exactly the same. White background.",
    "guidance_scale": 3.5,
    "safety_tolerance": "5",
}
```

The T-pose conversion config is also stored in `memories/3d-assets/styles/full-character.json` under `tpose_conversion`.

### Prop extraction with SAM 3
To extract a weapon/accessory from a character reference as a separate asset:

```python
# fal-ai/sam-3/image — segment anything
payload = {
    "image_url": "<reference image URL>",
    "prompts": [{"type": "text", "text": "baseball bat"}],  # describe the object
    "apply_mask": True,
}
```

SAM 3 returns a pixel-perfect mask + isolated image. If the extracted object is partially occluded, generate a clean standalone reference with FLUX Pro instead of trying to inpaint.

## Step 1 — Submit (v3 textured)

Set `FAL_KEY` env var, then run from repo root:

```bash
python memories/3d-experiments/submit-hunyuan3d.py fal-ai/hunyuan3d-v3/image-to-3d path/to/ref.png memories/3d-experiments
```

Poll `status_url` until `COMPLETED` (~2–3 minutes typical).

## Step 2 — Download high-poly GLB

```bash
python memories/3d-experiments/fetch-result.py <request_id> fal-ai/hunyuan3d-v3 memories/3d-experiments model-highpoly.glb
```

v3 responses usually expose the mesh at **`model_glb.url`** (the fetch script checks `model_glb`, then `model_mesh`, etc.).

## Step 3 — Decimate + bake (Blender)

Repo root script: `decimate.py`  
Uses **voxel remesh** (watertight) then **iterative collapse decimate** until face count is near target, then **diffuse bake** from high-poly to low-poly, exports GLB.

```bash
& "F:\SteamLibrary\steamapps\common\Blender\blender.exe" --background --python decimate.py -- input-highpoly.glb output-game.glb <target_faces> <voxel_size>
```

For custom decimation scripts (commercial characters, props), see `memories/3d-experiments/StoreAssets/_decimate_tpose.py` and `_decimate_club.py` for reference implementations with verbose logging.

### Voxel size reference (critical — hard-won knowledge)

| voxel_size | Use case | Notes |
|------------|----------|-------|
| 0.006 | Rigging intermediate (5K faces) | Preserves all detail for Anymate bone placement |
| 0.012 | Game mesh characters (1000-1500 faces) | Preserves hand/finger detail in T-pose |
| 0.025 | Simple props (100-200 faces) | Good for bats, clubs, simple weapons |
| 0.032 | Chibi pets (300-400 faces) | Existing default for pet pipeline |
| **0.05+** | **NEVER on thin features** | **Limbs and fingers WILL split apart** |

**Tuning:** Larger `voxel_size` → fewer faces after remesh → fewer decimate passes. If the script stops above target, lower `target_faces` slightly or increase `voxel_size`. The script loops decimate until roughly `target_faces * 1.08` because one Blender pass often undershoots.

## Step 4 — Visual polish

Adjust baked texture saturation, contrast, and optionally bake AO. **No geometry smoothing** — corrective smooth will explode decimated meshes.

| Track | Saturation | Contrast | Brightness | AO |
|-------|-----------|----------|------------|-----|
| Pet | +40% | +15% | +5% | 0.5 |
| Commercial character | +10% | +5% | 0 | 0.6 |
| Prop | +10% | +5% | 0 | 0.6 |

Pet polish: `memories/3d-experiments/polish-pet.py`  
Commercial/prop polish: write a custom script per `memories/3d-experiments/StoreAssets/_polish_club.py`

## Step 5 — Rigging

### Track A: Pets and simple characters — Anymate (primary)
`python memories/3d-experiments/rig-anymate.py <name>` (~15s via HuggingFace API, no local GPU needed, 100% weight coverage). Falls back to **UniRig** (`rig-pet.py`) if Anymate is unavailable.

### Track B: Commercial humanoids — Mixamo (recommended)

Mixamo produces a 25-bone industry-standard skeleton with perfect weights and is compatible with thousands of free animations. Best for any humanoid character that needs precise, editable bones.

1. Export mesh-only FBX (no armature, no rotation applied)
2. Upload to [mixamo.com](https://mixamo.com) — place markers (chin, wrists, elbows, knees, groin)
3. Download T-Pose **"with skin"** (mesh + skeleton + weights)
4. Download animations **"without skin"** (skeleton + animation only)
5. Bundle using `_build_mixamo_bundle.py`:

```bash
& "F:\SteamLibrary\steamapps\common\Blender\blender.exe" --background --python _build_mixamo_bundle.py -- our_mesh.glb T-Pose.fbx anim_folder/ output.glb
```

The script takes Mixamo's rigged mesh + your texture + all animation FBXs → single GLB with all animations.

**Key rules:**
- Do NOT rotate the mesh before Mixamo upload
- Download T-Pose "with skin", all others "without skin"
- Script uses Mixamo's mesh/weights directly, applies your baked texture on top

### Track C: Creatures (non-humanoid) — Anymate

For 4-legged creatures, dragons, spiders, etc. that Mixamo cannot process:

1. Decimate highpoly to **5000 faces** at voxel **0.006** (intermediate mesh)
2. Rig the 5K intermediate via Anymate (better bone placement on detailed mesh)
3. Transfer armature to the game mesh (1000-1500 faces)
4. Run `memories/3d-experiments/name-bones.py` to rename numeric bones

**Note:** Anymate on creatures has not been extensively tested. May produce extra/misplaced bones requiring manual cleanup. Good enough for game polish and procedural animation, but not as precise as Mixamo is for humanoids.

### Track D: Custom skeleton (fallback for humanoids)
When Mixamo upload isn't feasible or Anymate fails:

Use `memories/3d-experiments/StoreAssets/_build_clean_skeleton.py`:
- Builds 22 Mixamo-named bones from mesh geometric landmarks
- Dynamic shoulder detection, side isolation, cubic falloff weights
- Mixamo-compatible bone names (Hips, Spine, LeftArm, etc.)

```bash
& "F:\SteamLibrary\steamapps\common\Blender\blender.exe" --background --python _build_clean_skeleton.py -- input-game.glb output-rigged.glb
```

### Track E: Props — No rigging
Props (weapons, tools, accessories) ship with **no armature**. Skip rigging entirely.

## Step 6 — Thumbnail (commercial assets)

For Creator Store listings, render a thumbnail using Blender + PIL:

1. **Blender render**: Import model(s), set up camera + 3-point lighting, render to PNG  
   See `memories/3d-experiments/StoreAssets/_render_thumbnail.py`
2. **PIL text overlay**: Add character name in Unity Asset Store style (white bold text on dark rounded pill)  
   See `memories/3d-experiments/StoreAssets/_add_text_overlay.py`

## Step 7 — Animation (commercial humanoids, optional)

### Mixamo animations
With a Mixamo-rigged model, browse [mixamo.com](https://mixamo.com) for free animations (idle, walk, dance, attack, etc.) and download as FBX "without skin". Bundle into GLB with `_build_mixamo_bundle.py`.

### AI-generated animations
**HY-Motion** (`fal-ai/hunyuan-motion`) generates text-to-skeleton animations. Outputs SMPL 22-joint FBX. Requires retargeting to your skeleton — works but is lossy between different skeleton proportions. Mixamo pre-made animations generally give better results.

### Roblox animation limitations (CRITICAL)
- **Roblox Creator Store does NOT allow KeyframeSequences in sold models** — the model will be rejected
- **Roblox animations are account-locked** — buyers cannot use your published animation IDs in their games
- **Roblox Animation Editor requires Motor6Ds** — skinned mesh GLB imports don't have these
- **For Roblox:** sell rigged model only (no animations). Include KeyframeSequences only if model is NOT for sale
- **For other platforms** (Sketchfab, itch.io, Unity Asset Store): GLB with embedded animations works perfectly

## Step 8 — Creator Store listing (commercial assets)

**Title formula:** `"[Character Name] + [Accessory] | Low-Poly Rigged Character"`  
**Price range:** $1.99–$4.99 individual, $9.99–$14.99 bundles  
**Tags:** character name, meme/franchise name, "low poly", "rigged", "game ready", genre tags

**Description template:**
```
[Character Name] — fully rigged character with [accessory] accessory.

WHAT'S INCLUDED:
- Rigged [character] (25 Mixamo-standard bones, game-ready)
- Separate [accessory] prop (no armature, attach to hand bone)
- Baked textures on both assets

STATS:
- Character: [X] tris / [Y] verts
- [Accessory]: [X] tris / [Y] verts
- Combined: [X] tris — less than most Roblox accessories
- Total file size: ~[X] MB

RIGGING:
- 17 human-readable bone names (hips, spine, chest, head, upper_arm_L, etc.)
- Clean weight painting with minimal bleed between limbs
- T-pose default — easy to animate

IMPORTANT:
- This is a 3D MODEL ONLY — no scripts, no code, no animations included
- You provide your own scripts and animations

OPTIMIZED FOR ROBLOX:
- Ultra low-poly, runs great even on mobile
- [X] total polys is less than a single default Roblox accessory
- Clean hierarchy, proper scale and orientation
- Ready to drop into any game
```

## Fallback — no Blender

`memories/RobloxChassis/models/decimate_trimesh.py` — trimesh + pyfqmr, **no texture bake**. Use only when Blender is unavailable.

## Files

| File | Role |
|------|------|
| `decimate.py` | Blender: voxel + multi-pass decimate + bake + GLB export |
| `memories/3d-experiments/submit-hunyuan3d.py` | Queue v3 image-to-3D (textured) |
| `memories/3d-experiments/fetch-result.py` | Download GLB from completed job |
| `memories/3d-experiments/name-bones.py` | Rename numeric Anymate bones to human-readable names |
| `memories/3d-experiments/rig-anymate.py` | Auto-rig via HuggingFace Anymate API |
| `memories/3d-experiments/StoreAssets/_build_clean_skeleton.py` | Custom 22-bone Mixamo-named skeleton from mesh landmarks |
| `memories/3d-experiments/StoreAssets/_build_mixamo_bundle.py` | Bundle Mixamo T-Pose + texture + animations → single GLB |
| `memories/3d-experiments/StoreAssets/_apply_mixamo_anim.py` | Apply single Mixamo FBX animation to rigged GLB |
| `memories/3d-experiments/StoreAssets/_generate_animation.py` | Generate AI animation via HY-Motion (fal.ai) |
| `memories/3d-experiments/StoreAssets/_decimate_tpose.py` | Custom decimation for T-pose characters |
| `memories/3d-experiments/StoreAssets/_decimate_club.py` | Custom decimation for props |
| `memories/3d-experiments/StoreAssets/_polish_club.py` | Texture polish for props |
| `memories/3d-experiments/StoreAssets/_render_thumbnail.py` | Blender: side-by-side thumbnail render |
| `memories/3d-experiments/StoreAssets/_add_text_overlay.py` | PIL: Unity-style text banner on thumbnail |
| `memories/3d-experiments/StoreAssets/_generate_club.py` | FLUX Pro: generate prop reference images |
| `memories/3d-experiments/StoreAssets/_extract_club_sam.py` | SAM 3: extract prop from character reference |
| `memories/3d-experiments/StoreAssets/_pipeline_club.py` | Submit prop reference to Hunyuan3D v3 |
| `memories/3d-assets/styles/full-character.json` | Style profile for commercial characters |
| `memories/3d-assets/styles/prop.json` | Style profile for props/accessories |

## Example outputs

| Asset | Track | Faces | Verts | Size | File |
|-------|-------|-------|-------|------|------|
| Tabby Cat (pet) | Pet | ~360 | ~300 | ~500 KB | `memories/3d-experiments/tabby-cat-game-340.glb` |
| Tung Tung Sahur (store) | Commercial | 1,378 | 1,279 | 1,180 KB | `memories/3d-experiments/StoreAssets/StoreTungTung-tpose-FINAL.glb` |
| Tung Tung Bat (store) | Prop | 176 | 158 | 135 KB | `memories/3d-experiments/StoreAssets/StoreTungTung-club.glb` |
