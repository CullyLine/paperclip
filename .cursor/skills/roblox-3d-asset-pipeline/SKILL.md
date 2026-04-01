---
name: roblox-3d-asset-pipeline
description: >
  Pipeline for game-ready rigged 3D assets from concept art: Hunyuan3D v3 mesh
  generation, Blender decimation with texture baking, visual polish, and UniRig
  automatic rigging. In-game animation is done in Roblox Studio (Luau), not in
  Blender. Use when the user asks to create a 3D model, rig a model, generate a
  pet/prop/character, or run the art-to-rigged-asset pipeline.
---

# Roblox 3D Asset Pipeline

**Shipping pipeline:** **concept art → Hunyuan3D v3 → decimate + bake → manual cleanup (if needed) → texture polish + AO → UniRig → rigged GLB → import Roblox Studio → animate in Studio (Luau)**

> **IMPORTANT**: Before creating or modifying any pet asset, read the permanent
> design specifications at `memories/DriveACarSimulator/PermanentDesignSpecs.md`.
> That document is the canonical source for art style, prompt templates, rarity
> color language, decimation/rigging parameters, file naming, Roblox integration,
> and procedural animation in Studio. This SKILL.md covers the offline technical
> commands up to **rigged GLB**.

> **Animation**: Do **not** treat Blender batch animation (`universal-animate.py`,
> `batch-animate.py`) as a production step. Pets are animated with **`PetAnimator.luau`**
> + **`PetController.luau`** in the game client. Legacy Blender scripts in
> `memories/3d-experiments/` are optional reference only.

## Prerequisites

| Tool | Location | Purpose |
|------|----------|---------|
| Blender 5.0+ | `F:\SteamLibrary\steamapps\common\Blender\blender.exe` | Decimate + texture bake + polish |
| UniRig | `F:\CODE STUFF\tools\UniRig\` | Auto-rigging (skeleton + skinning) |
| UniRig venv | `F:\CODE STUFF\tools\UniRig\venv\` | Python env with PyTorch |
| FAL_KEY | Paperclip agent env or manual | Hunyuan3D API auth |
| decimate.py | Repo root | Blender voxel remesh + collapse + bake |
| polish-pet.py | `memories/3d-experiments/` | Texture saturation + contrast + AO bake |
| open-glb.py | `memories/3d-experiments/` | Open GLB for inspection (Pose Mode, Material Preview) |

### Blender Setup (IMPORTANT)

**Always use the Steam install** (`F:\SteamLibrary\steamapps\common\Blender\blender.exe`),
never the standalone tools install. The Steam version has the user's custom keybinds.

**Opening models for inspection:** Always use `open-glb.py`, never raw `blender <file>`:
```bash
blender --python memories/3d-experiments/open-glb.py -- <file.glb>
```
This handles: deferred import (fixes armature crash), Material Preview shading,
Pose Mode with Move tool, auto-framing, and preserves user keybinds.

**Never call `bpy.ops.wm.read_factory_settings()`** — it destroys user keybinds.
To get a clean scene, use `bpy.ops.object.select_all(action='SELECT')` + `bpy.ops.object.delete()`.

**Keybind backup:** `memories/DriveACarSimulator/blender-config/` contains `userpref.blend`
and `startup.blend`. Run `restore-blender-prefs.py` to restore after Blender updates.

## Step 1 — Concept Art (Reference-Based)

**Always use a reference image of the real character** when creating pets based on
existing characters (memes, IPs, etc.). This is critical — without it, the concept art
drifts into generic interpretations that don't match the source.

### 1a. Download character reference
Save a screenshot/image of the actual character to `memories/3d-experiments/<name>-ref.jpg`.
Use Python (never PowerShell) to download from Know Your Meme, fan wikis, etc.

### 1b. Generate concept art with reference
Pass the reference image via `reference_image_paths` AND use the chibi toy prompt template
from `PermanentDesignSpecs.md` §1.3. The prompt must include:
- "chibi super-deformed Roblox collectible pet toy figure"
- "Think Funko Pop or Pet Simulator X pet style"
- "very stubby short" limbs, T-pose, no weapons
- Key visual features listed from the reference

This two-reference approach (character image + style prompt) produces pets that are both
**recognizable** as the character AND **consistent** with the game's art style.

Save to `assets/pet-<name>-concept.png` (image tool default location).

## Step 2 — Hunyuan3D v3 (Image-to-3D)

**Always use v3** for shipping assets. v2 is geometry-only and looks untextured.

```bash
FAL_KEY="<key>" python memories/3d-experiments/submit-hunyuan3d.py \
  fal-ai/hunyuan3d-v3/image-to-3d \
  "memories/3d-experiments/<name>-concept.png" \
  "memories/3d-experiments"
```

Poll status (~2-3 min), then fetch:

```bash
python memories/3d-experiments/fetch-result.py <request_id> \
  fal-ai/hunyuan3d-v3 memories/3d-experiments <name>-highpoly.glb
```

## Step 3 — Decimate + Texture Bake

Voxel remesh → iterative collapse decimate → diffuse bake from high-poly to low-poly.

```bash
blender --background --python decimate.py -- \
  "memories/3d-experiments/<name>-highpoly.glb" \
  "memories/3d-experiments/<name>-game-340.glb" \
  340 0.032
```

| Goal | target_faces | voxel_size |
|------|-------------|------------|
| Pet / follower (~300–400 tris) | 340 | 0.032 |
| Prop / medium detail | 1500–2500 | 0.004–0.006 |

Larger `voxel_size` → fewer faces after remesh. Script loops decimate passes until ≈ `target * 1.08`.

## Step 3.5 — Manual Cleanup (if needed)

After decimation, inspect the model in Blender. Decimation can merge appendages
into awkward shapes (weapons fusing into bodies, limbs becoming phallic, etc.).

1. Open the decimated GLB in Blender (`open-glb.py`)
2. Enter edit mode, select and delete problematic vertices/faces
3. Select remaining open edges → **Merge at Center** (or By Distance)
4. Adjust merged vertices for a clean silhouette
5. Export as GLB, overwriting the same `{name}-game-340.glb` file

## Step 4 — Visual Polish (texture only, NO geometry changes)

Enhance baked textures and add ambient occlusion. Input and output can be the same file.

```bash
blender --background --python memories/3d-experiments/polish-pet.py -- \
  "memories/3d-experiments/<name>-game-340.glb" \
  "memories/3d-experiments/<name>-game-340.glb"
```

| Enhancement | Value | Effect |
|-------------|-------|--------|
| Shade smooth | normals only | Soft lighting on faces, zero vertex movement |
| Saturation boost | **+40%** | Vibrant toy-like colors |
| Contrast boost | **+15%** | Crisper definition between color regions |
| Brightness lift | **+5%** | Midtones feel more alive |
| Ambient occlusion | bake × multiply (30% floor) | Depth in crevices without extra geometry |

### CRITICAL: No Geometry Smoothing

**NEVER** apply Corrective Smooth, Laplacian Smooth, Subdivision Surface, or any
modifier that moves vertices on decimated meshes. These meshes have non-manifold
geometry (disconnected faces from voxel remesh + collapse) and geometry-modifying
modifiers will **"explode" the mesh** — pulling faces apart at seams.

**Only shade smooth is safe** — it changes normal direction for rendering, not vertex positions.

## Step 5 — Auto-Rig (UniRig) — Highpoly Strategy

UniRig predicts a skeleton then skinning weights. **Key insight:** rigging from the
**highpoly** model produces significantly better bones (17+ vs 10 on lowpoly), because
UniRig's internal decimation to 50K faces preserves more geometric detail for bone
placement. The skeleton is then **merged onto the lowpoly** game model.

**Before rigging:** close Blender, Roblox Studio, Discord, browsers to free VRAM.

### Production script: `rig-pet.py`

```bash
# Single pet
python memories/3d-experiments/rig-pet.py tralalero

# Multiple pets
python memories/3d-experiments/rig-pet.py tungtung bombombini tralalero

# All brainrot pets
python memories/3d-experiments/rig-pet.py --all
```

**Requires** both files to exist in `memories/3d-experiments/`:
- `<pet>-highpoly.glb` (Hunyuan3D output, ~500K faces)
- `<pet>-game-340.glb` (decimated + polished)

**Pipeline (6 steps, fully automated):**
1. Extract mesh from **highpoly** (UniRig internal decimate to 50K)
2. Skeleton prediction on highpoly (GPU eager, ~20-30s)
3. Copy `predict_skeleton.npz` to **both** `results/` AND `tmp/results/` (fixes path bug)
4. Skinning (GPU, ~40-90s)
5. Merge rig onto **lowpoly** game model
6. Auto-add snout bone (for nose wiggle animation)

**Output:** `<pet>-game-340_rigged.glb`

### Why highpoly rigging?

| Approach | Typical bones | Coverage |
|----------|--------------|----------|
| Rig lowpoly (340 faces) | 8–12 | Misses arms, fins, wing tips |
| Rig highpoly → merge lowpoly | 15–20+ | Picks up all appendages, more segments |

### NPZ path fix (CRITICAL)

The skeleton step saves `predict_skeleton.npz` in a folder named after the **input
filename** (e.g. `tralalero-highpoly/predict_skeleton.npz`), but the skinning step
looks for it in `tmp/results/<skeleton_name>/predict_skeleton.npz`.

`rig-pet.py` handles this automatically with `find_npz()` (searches all possible
locations) and `copy_npz_to_all_locations()` (copies to both `results/` and `tmp/results/`).

If running manually, you MUST copy the npz to both locations:
```python
shutil.copy2(npz_src, os.path.join("results", skel_name, "predict_skeleton.npz"))
shutil.copy2(npz_src, os.path.join("tmp", "results", skel_name, "predict_skeleton.npz"))
```

### Snout bone (automatic)

Every pet gets a snout bone automatically in step 6. The script finds the frontmost
bone, extends it toward the nose of the mesh, and transfers weights. This enables
a "nose wiggle" animation in `PetAnimator.luau`.

Can also be run standalone:
```bash
blender --background --python memories/3d-experiments/add-snout.py -- <rigged.glb> <output.glb>
```

### UniRig GPU memory management (CRITICAL for 8GB cards)

| Rule | Reason |
|------|--------|
| Close all GPU-heavy apps before rigging | Frees ~2-3 GB VRAM |
| Use `eager` attention, NEVER `flash_attention_2` | flash_attn causes WDDM deadlocks on Windows |
| Use `num_beams=1` (minVRAM system config) | Reduces beam search memory from 3x to 1x |
| Set `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` | Reduces memory fragmentation |
| Run skeleton on GPU, not CPU | CPU mode hits 2GB allocation limit on some systems |

### UniRig gotchas

- **bpy crash on exit** (code -1073741819): harmless Windows cleanup crash, output is fine.
- **predict_skeleton.npz path**: see NPZ path fix above. `rig-pet.py` handles this automatically.
- **PyTorch 2.6 pickle error**: already patched in `run.py` with `torch.serialization.add_safe_globals([Box])`.
- **GPU configs**: `quick_inference_skeleton_articulationxl_ar_256_gpu_eager.yaml` uses eager attention + `ar_inference_articulationxl_minvram` system (1 beam).
- **RTX 3070 (8GB)**: Works with all apps closed. Skeleton needs ~5-6 GB VRAM.
- **`--time` argument**: The extract step requires `--time=<timestamp>`. `rig-pet.py` generates this automatically.

## Step 5.5 — Validate & Fix Bones (pet-specific)

The highpoly rig + snout bone covers most needs. For pet-specific adjustments
(e.g. extra wing bones, back fin, tail), validate and add manually.

```bash
# Check bone coverage
blender --background --python memories/3d-experiments/validate-bones.py -- <rigged.glb>

# Inspect bone hierarchy
blender --background --python memories/3d-experiments/inspect-bones.py -- <rigged.glb>
```

**If bones are missing**, create a `bones.json` and add them:

```bash
blender --background --python memories/3d-experiments/add-bones.py -- \
  <rigged.glb> <output.glb> <bones.json>
```

Example `bones.json`:
```json
[
  {"name": "wing_tip_L", "head": [-0.3, 0.4, 0.35], "tail": [-0.45, 0.45, 0.38], "parent": "bone_5"},
  {"name": "back_fin", "head": [-0.015, 0.309, 0.909], "tail": [-0.011, 0.500, 0.650], "parent": "bone_8"}
]
```

Get bone positions from `inspect-bones.py` output or by examining the model in Pose Mode.
The script auto-parents to nearest bone if parent is omitted, and re-calculates vertex weights.

**Open the result for review:**
```bash
blender --python memories/3d-experiments/open-glb.py -- <output.glb>
```

## Step 6 — Import Studio + Animate (Luau)

**End product of this pipeline** is **`{name}-game-340_rigged.glb`**. Import into Roblox Studio, place under `ReplicatedStorage.PetModels`, scale as needed.

**In-game animation** (canonical):

- `DACReplicatedStorage/PetAnimator.luau` — procedural `Bone.Transform` per frame (idle / walk / float) + scale breathing (3% pulse at 1.2 Hz)
- `DACStarterPlayerScripts/Controllers/PetController.luau` — V-formation + roof-ride + calls PetAnimator

See **PermanentDesignSpecs.md** § Roblox Integration and § Animation — Roblox Studio.

## Files (shipping pipeline)

| File | Role |
|------|------|
| `decimate.py` | Blender voxel + decimate + bake + GLB export |
| `memories/3d-experiments/polish-pet.py` | Texture saturation + contrast + brightness + AO bake |
| `memories/3d-experiments/submit-hunyuan3d.py` | Queue Hunyuan3D v3 |
| `memories/3d-experiments/fetch-result.py` | Download completed GLB |
| `memories/3d-experiments/validate-bones.py` | Check bone coverage on rigged model |
| `memories/3d-experiments/inspect-bones.py` | Dump bone hierarchy, positions, parents |
| `memories/3d-experiments/add-bones.py` | Add manual bones + re-calculate weights |
| `memories/3d-experiments/batch-*.py` | Batch submit/fetch/decimate/rig |
| `memories/3d-experiments/rig-pet.py` | **Production rig script**: highpoly rig → lowpoly merge → auto snout |
| `memories/3d-experiments/add-snout.py` | Standalone snout bone addition |
| `memories/3d-experiments/rig-brainrot.py` | Legacy batch rigging (lowpoly only, superseded by rig-pet.py) |
| `memories/3d-experiments/polish-all-brainrot.py` | Batch decimate + polish + open for review |
| `memories/3d-experiments/open-glb.py` | Open GLB in Blender GUI for inspection |

## Pipeline summary (quick reference)

```
concept art (.png)
  ↓ Hunyuan3D v3
highpoly (.glb, ~500K faces)
  ↓ decimate.py (voxel 0.032, target 340 or 600-800 for detailed)
game-340 (.glb, ~340 faces)
  ↓ manual cleanup in Blender (if needed)
game-340 (.glb, cleaned)
  ↓ polish-pet.py (sat +40%, contrast +15%, brightness +5%, AO)
game-340 (.glb, polished)
  ↓ rig-pet.py (highpoly rig → lowpoly merge → auto snout bone)
  │  [1] extract from highpoly (50K internal decimate)
  │  [2] skeleton on highpoly (GPU eager)
  │  [3] copy npz to BOTH results/ AND tmp/results/
  │  [4] skinning (GPU)
  │  [5] merge rig onto lowpoly game model
  │  [6] auto-add snout bone
game-340_rigged (.glb, auto-rigged + snout)
  ↓ validate-bones.py + inspect-bones.py (check coverage)
  ↓ add-bones.py (pet-specific bones if needed) [+ open-glb.py for visual review]
game-340_rigged (.glb, final)
  ↓ import to Roblox Studio
PetModels/<name> (in game)
```

## Example outputs

| Asset | Faces | Offline pipeline |
|-------|-------|------------------|
| Tabby Cat | ~354 | v3 + decimate(340, 0.032) + polish + UniRig → rigged GLB |
| Cosmic Whale | ~354 | v3 + decimate(340, 0.032) + polish + UniRig → rigged GLB |
| Tung Tung Sahur | ~390 | v3 + decimate(340, 0.032) + polish + UniRig → rigged GLB |
| Bombardiro Crocodilo | ~328 | v3 + decimate(340, 0.032) + manual bomb removal + polish + UniRig → rigged GLB |
