---
name: roblox-3d-asset-pipeline
description: >
  Pipeline for game-ready rigged 3D assets from concept art: Hunyuan3D v3 mesh
  generation, Blender decimation with texture baking, and UniRig automatic rigging.
  In-game animation is done in Roblox Studio (Luau), not in Blender. Use when the user
  asks to create a 3D model, rig a model, generate a pet/prop/character, or run the
  art-to-rigged-asset pipeline.
---

# Roblox 3D Asset Pipeline

**Shipping pipeline:** **concept art → Hunyuan3D v3 → decimate + bake → UniRig → rigged GLB → import Roblox Studio → animate in Studio (Luau)**

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
| Blender 5.0+ | `F:\CODE STUFF\tools\blender-5.0.1-windows-x64\blender.exe` | Decimate + texture bake only |
| UniRig | `F:\CODE STUFF\tools\UniRig\` | Auto-rigging (skeleton + skinning) |
| UniRig venv | `F:\CODE STUFF\tools\UniRig\venv\` | Python env with PyTorch |
| FAL_KEY | Paperclip agent env or manual | Hunyuan3D API auth |
| decimate.py | Repo root | Blender voxel remesh + collapse + bake |

## Step 1 — Concept Art

Generate or source a reference image. For best 3D results:

- Single subject, **centered**, **front or three-quarter** view
- **Pure white background**, product/studio lighting
- Prompt keywords: *"white background, front-facing, centered, single object, product photography"*
- Match the game's art style (reference `memories/DriveACarSimulator/ConceptArt/pet-designs-rarity-tiers.png`)

Save to `memories/3d-experiments/<name>-concept.png`.

## Step 2 — Hunyuan3D v3 (Image-to-3D)

**Always use v3** for shipping assets. v2 is geometry-only and looks untextured.

```powershell
$env:FAL_KEY = "<key>"
cd "F:\CODE STUFF\Paperclip"
python memories/3d-experiments/submit-hunyuan3d.py fal-ai/hunyuan3d-v3/image-to-3d `
  "memories\3d-experiments\<name>-concept.png" `
  "memories\3d-experiments"
```

Poll status (~2-3 min), then fetch:

```powershell
python memories/3d-experiments/fetch-result.py <request_id> fal-ai/hunyuan3d-v3 `
  memories/3d-experiments <name>-highpoly.glb
```

## Step 3 — Decimate + Texture Bake

Voxel remesh → iterative collapse decimate → diffuse bake from high-poly to low-poly.

```powershell
& "F:\CODE STUFF\tools\blender-5.0.1-windows-x64\blender.exe" --background `
  --python "decimate.py" -- `
  "memories\3d-experiments\<name>-highpoly.glb" `
  "memories\3d-experiments\<name>-game-340.glb" `
  340 0.032
```

| Goal | target_faces | voxel_size |
|------|-------------|------------|
| Pet / follower (~300–400 tris) | 340 | 0.032 |
| Prop / medium detail | 1500–2500 | 0.004–0.006 |

Larger `voxel_size` → fewer faces after remesh. Script loops decimate passes until ≈ `target * 1.08`.

## Step 4 — Auto-Rig (UniRig)

UniRig predicts a skeleton then skinning weights. Skeleton runs on **CPU** (avoids GPU OOM on 8GB cards). Skinning runs on **GPU** (spconv requires CUDA).

Run each step manually (the `rig.ps1` wrapper has a `$Input` conflict with PowerShell):

```powershell
cd "F:\CODE STUFF\tools\UniRig"
$env:PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True"
$MODEL = "<absolute-path-to-game-glb>"
$NAME  = "<model-name-without-extension>"

# 1. Extract mesh
$ts = Get-Date -Format "yyyy_MM_dd_HH_mm_ss"
& .\venv\Scripts\python.exe -m src.data.extract `
  --config=configs/data/quick_inference.yaml `
  --require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm `
  --force_override=true --num_runs=1 --id=0 --time=$ts `
  --faces_target_count=50000 --input=$MODEL --output_dir=tmp

# 2. Skeleton (CPU, ~30-60s)
& .\venv\Scripts\python.exe run.py `
  --task=configs/task/quick_inference_skeleton_articulationxl_ar_256_cpu.yaml `
  --seed=12345 --input=$MODEL `
  --output="results\${NAME}_skeleton.fbx" --npz_dir=tmp

# 3. Copy predict_skeleton.npz to where skinning expects it
$src = "<model-parent-dir>\$NAME\predict_skeleton.npz"
$dst = "tmp\results\${NAME}_skeleton"
New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item $src "$dst\predict_skeleton.npz" -Force

# 4. Skinning (GPU, ~40-90s)
& .\venv\Scripts\python.exe run.py `
  --task=configs/task/quick_inference_unirig_skin.yaml `
  --seed=12345 --input="results\${NAME}_skeleton.fbx" `
  --output="results\${NAME}_skin.fbx" `
  --npz_dir=tmp --data_name=predict_skeleton.npz

# 5. Merge rig into original model
& .\venv\Scripts\python.exe -m src.inference.merge `
  --require_suffix=obj,fbx,FBX,dae,glb,gltf,vrm `
  --num_runs=1 --id=0 `
  --source="results\${NAME}_skin.fbx" `
  --target=$MODEL `
  --output="<output-path>/${NAME}_rigged.glb"
```

### UniRig gotchas

- **bpy crash on exit** (code -1073741819): harmless Windows cleanup crash, output is fine.
- **predict_skeleton.npz path**: skeleton step saves the npz next to the input model, not in `tmp/`. Copy it to `tmp/results/<skeleton_name>/predict_skeleton.npz` before skinning.
- **PyTorch 2.6 pickle error**: already patched in `run.py` with `torch.serialization.add_safe_globals([Box])`.
- **CPU skeleton configs**: `quick_inference_skeleton_articulationxl_ar_256_cpu.yaml` + `unirig_ar_350m_1024_81920_float32_cpu.yaml` use `eager` attention and `accelerator: cpu`.

## Step 5 — Import Studio + Animate (Luau)

**End product of this pipeline** is **`{name}-game-340_rigged.glb`** (or your chosen naming). Import into Roblox Studio, place under `ReplicatedStorage.PetModels`, scale as needed.

**In-game animation** (canonical):

- `DACReplicatedStorage/PetAnimator.luau` — procedural `Bone.Transform` per frame (idle / walk / float)
- `DACStarterPlayerScripts/Controllers/PetController.luau` — formation + calls into PetAnimator

See **PermanentDesignSpecs.md** § Roblox Integration and § Animation — Roblox Studio.

## Files (shipping pipeline)

| File | Role |
|------|------|
| `decimate.py` | Blender voxel + decimate + bake + GLB export |
| `memories/3d-experiments/submit-hunyuan3d.py` | Queue Hunyuan3D v3 |
| `memories/3d-experiments/fetch-result.py` | Download completed GLB |
| `memories/3d-experiments/batch-*.py` | Batch submit/fetch/decimate/rig (no animate) |
| `F:\CODE STUFF\tools\UniRig\rig.ps1` | UniRig wrapper (has `$Input` bug) |

## Example outputs

| Asset | Faces | Offline pipeline |
|-------|-------|------------------|
| Tabby Cat | ~354 | v3 + decimate(340, 0.032) + UniRig → rigged GLB |
| Cosmic Whale | ~354 | v3 + decimate(340, 0.032) + UniRig → rigged GLB |
