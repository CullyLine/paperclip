# 3D Auto-Rigging

## Primary: Anymate (HuggingFace API)

**Anymate is the default rigging tool** as of 2026-03-31. Runs on HuggingFace Spaces
(`yfdeng/Anymate`), ~15 seconds per model, no local GPU needed, 100% weight coverage.

### Quick Command

```bash
python memories/3d-experiments/rig-anymate.py <pet_name>
```

### Why Anymate

Tested against UniRig on 3 pets — Anymate won 11-6 overall. 2x more bones on tricky
shapes, 100% weight coverage (UniRig: 90-95%), deeper bone chains, 15s vs 2-5 min.
See `memories/3d-experiments/anymate-vs-unirig-report.md`.

---

## Fallback: UniRig (Local GPU)

Automatic skeleton + skinning weight generation using [VAST-AI-Research/UniRig](https://github.com/VAST-AI-Research/UniRig) (SIGGRAPH 2025). **Only use when Anymate is down.**

### Location

`F:\CODE STUFF\tools\UniRig\` -- cloned repo with venv and custom configs.

### Quick Command

```bash
python memories/3d-experiments/rig-pet.py <pet_name>
```

### Pipeline (6 steps via rig-pet.py)

1. **Extract mesh** from highpoly (bpy) -- bpy crashes on cleanup but output is fine
2. **Skeleton prediction** (GPU, eager attention) -- ~20-30s
3. **Copy NPZ** to bridge path bug between skeleton/skinning steps
4. **Skinning weights** (GPU, spconv) -- ~40-90s
5. **Merge** rig onto lowpoly game model
6. **Snout bone** auto-addition

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
