# 3D UniRig Rigging

Automatic skeleton + skinning weight generation for 3D models using [VAST-AI-Research/UniRig](https://github.com/VAST-AI-Research/UniRig) (SIGGRAPH 2025).

## Location

`F:\CODE STUFF\tools\UniRig\` -- cloned repo with venv and custom configs.

## Quick Command

```powershell
& "F:\CODE STUFF\tools\UniRig\rig.ps1" -Input "path\to\model.glb"
```

Options: `-Output`, `-Seed`, `-SkeletonOnly`, `-FacesTarget`

## Pipeline (4 steps)

1. **Extract mesh** (bpy) -- instant, bpy crashes on cleanup but output is fine
2. **Skeleton prediction** (CPU, eager attention, 3-beam search) -- ~30-40s
3. **Skinning weights** (GPU, bf16-mixed, spconv) -- ~10s
4. **Merge** rig back into original GLB/FBX -- instant

## Key Setup Details

- Python 3.11 venv (no conda)
- PyTorch 2.6.0+cu124, RTX 3070 8GB
- flash_attn 2.7.4 Windows wheel from lldacing/flash-attention-windows-wheel on HuggingFace
- triton-windows 3.2.0.post21 (must be <3.3 for PyTorch 2.6)
- spconv-cu124, torch_scatter, torch_cluster from PyG
- Model checkpoints auto-download from HuggingFace (~2-3 GB, cached at `~/.cache/huggingface/hub/models--VAST-AI--UniRig`)

## Critical Patches Applied

- `run.py`: Added `torch.serialization.add_safe_globals([Box])` for PyTorch 2.6 compat
- `src/system/ar.py`: Removed `user_mode` gate on npz export so skinning can find `predict_skeleton.npz`
- Custom configs: `*_cpu.yaml` variants use `accelerator: cpu` + `_attn_implementation: eager` + `flash: False`
- `ar_inference_articulationxl_lowvram.yaml`: `num_beams: 3` (down from 15) for 8GB GPUs

## Gotchas

- Skeleton must run on CPU -- GPU beam search with 15 beams OOMs on 8GB and freezes Cursor/desktop
- Skinning MUST run on GPU (spconv is CUDA-only)
- bpy exit code -1073741819 on Windows is normal, output is fine
- Absolute input paths bypass `--output_dir`/`--npz_dir` due to `os.path.join` behavior
- `predict_skeleton.npz` path must be manually bridged between skeleton and skinning steps

## Supported Formats

Input: `.glb`, `.fbx`, `.obj`, `.vrm`
Output: `.glb`, `.fbx`
