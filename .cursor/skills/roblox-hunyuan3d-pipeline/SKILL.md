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
   **Do not** use `fal-ai/hunyuan3d/v2` for final in-game art; v2 is a fast **geometry-first** pass with little or no meaningful PBR paint, so models look flat or “untextured” compared to v3.

2. **Why v2 looked untextured** — Hunyuan3D **v2** optimizes for quick mesh reconstruction. **v3** runs the full texturing / material pipeline (larger GLB, ~2+ minutes, higher cost). If you need a cheap shape check only, v2 is fine; for Roblox inventory/pets, **always v3**.

3. **Auth** — set `FAL_KEY` in the environment. Never hardcode keys in scripts.

## Reference image (critical)

Use the same formula that worked in `memories/3d-experiments` onboarding:

- Single subject, **centered**, **front or three-quarter** view  
- **Pure white background**  
- **Product / studio** lighting  
- Wording for generators: *“white background, front-facing, centered, single object, product photography”*

Place the PNG as `memories/3d-experiments/reference-for-3d.png` or pass a path as the second argument to `submit-hunyuan3d.py`.

## Step 1 — Submit (v3 textured)

```powershell
$env:FAL_KEY = "<your fal key>"
cd "F:\CODE STUFF\Paperclip"
python memories/3d-experiments/submit-hunyuan3d.py
```

Optional: `python .../submit-hunyuan3d.py fal-ai/hunyuan3d-v3/image-to-3d path\to\ref.png memories/3d-experiments`

Poll `status_url` until `COMPLETED` (~2–3 minutes typical).

## Step 2 — Download high-poly GLB

```powershell
python memories/3d-experiments/fetch-result.py <request_id> fal-ai/hunyuan3d-v3 memories/3d-experiments model-highpoly.glb
```

v3 responses usually expose the mesh at **`model_glb.url`** (the fetch script checks `model_glb`, then `model_mesh`, etc.).

## Step 3 — Decimate + bake (Blender)

Repo root script: `decimate.py`  
Uses **voxel remesh** (watertight) then **iterative collapse decimate** until face count is near target, then **diffuse bake** from high-poly to low-poly, exports GLB.

```powershell
& "F:\SteamLibrary\steamapps\common\Blender\blender.exe" --background --python "decimate.py" -- `
  "memories\3d-experiments\model-highpoly.glb" `
  "memories\3d-experiments\model-game.glb" `
  <target_faces> `
  <voxel_size>
```

| Goal | target_faces | voxel_size (starting point) |
|------|----------------|-----------------------------|
| Pet / follower (~300–400 tris) | 340 | 0.032 |
| Prop / medium detail | 1500–2500 | 0.004–0.006 |

**Tuning:** Larger `voxel_size` → fewer faces after remesh → fewer decimate passes. If the script stops above target, lower `target_faces` slightly or increase `voxel_size`. The script loops decimate until roughly `target_faces * 1.08` because one Blender pass often undershoots.

## Fallback — no Blender

`memories/RobloxChassis/models/decimate_trimesh.py` — trimesh + pyfqmr, **no texture bake**. Use only when Blender is unavailable.

## Files

| File | Role |
|------|------|
| `decimate.py` | Blender: voxel + multi-pass decimate + bake + GLB export |
| `memories/3d-experiments/submit-hunyuan3d.py` | Queue v3 image-to-3D (textured) |
| `memories/3d-experiments/fetch-result.py` | Download GLB from completed job |
| `memories/3d-experiments/reference-for-3d.png` | Default reference (replace per asset) |

## Full pipeline (through rigged GLB)

After v3 + decimate, the full pipeline is:

1. **Manual cleanup** (if needed) — remove problematic geometry in Blender, merge vertices
2. **Visual polish** — `polish-pet.py` applies saturation +40%, contrast +15%, brightness +5%, AO bake (texture only, NO geometry smoothing — corrective smooth will explode decimated meshes)
3. **UniRig** — auto-rig with GPU eager attention config (close all GPU apps first)
4. **Import to Roblox Studio** — drive bones with **`PetAnimator.luau`**

See **roblox-3d-asset-pipeline** skill and `PermanentDesignSpecs.md` for full details.

## Example outputs (Tabby Cat)

After v3 + decimate: `memories/3d-experiments/tabby-cat-game-340.glb` (~360 faces, baked texture), `tabby-cat-game-380.glb` (~407 faces).
