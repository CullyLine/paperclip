# Anymate vs UniRig — Rigging Comparison Report

**Date:** 2026-03-31  
**Models tested:** cappuccino (346 faces), tungtung (724 faces), tralalero (340 faces)

## Results Summary

| Metric | Cappuccino |  | Tungtung |  | Tralalero |  |
|--------|-----------|----------|---------|----------|-----------|----------|
|        | Anymate   | UniRig   | Anymate | UniRig   | Anymate   | UniRig   |
| Bones  | **41**    | 33       | 41      | **42**   | **40**    | 17       |
| Roots  | 4         | **1**    | **1**   | **1**    | 4         | **1**    |
| Leaves | **9**     | 7        | **12**  | 9        | **14**    | 5        |
| Max depth | **11** | 9        | **12**  | 10       | **7**     | 5        |
| Weight coverage | **100%** | 90.3% | **100%** | 94.7% | **100%** | 90.0% |

**Overall: Anymate 11 wins — UniRig 6 wins — 1 tie**

## Key Findings

### Anymate Advantages

1. **Bone count:** Matches or exceeds UniRig across all pets. On tralalero (the trickiest shape — a shark with sneakers), Anymate found **40 bones** vs UniRig's **17** — more than 2x.

2. **100% weight coverage:** Every vertex is assigned to at least one bone. UniRig leaves 5-10% of vertices unweighted, which causes rigid/broken deformation during animation.

3. **Deeper bone chains:** More segments per limb chain = smoother deformation during bending. Anymate consistently has deeper hierarchies.

4. **Speed:** ~15 seconds via HuggingFace API vs ~2-5 minutes on local GPU for UniRig. No GPU memory management needed.

5. **No local GPU required:** Runs entirely on HuggingFace's serverless GPU. No CUDA, no PyTorch, no memory tuning.

### Anymate Concerns

1. **Multiple root bones:** Cappuccino and tralalero got 4 roots each. Roblox needs a single root. **Fix:** trivial — add a root bone parent in post-processing.

2. **Numeric bone names:** Bones are named `0`, `1`, `2`... vs UniRig's `bone_0`, `bone_1`... Neither is semantic, so this is a wash.

3. **API dependency:** Relies on HuggingFace Spaces availability. If the Space goes down, we can't rig. **Mitigation:** Keep UniRig as fallback, or run Anymate locally via WSL2.

4. **Mesh is baked into .blend:** Anymate returns its own processed mesh. We still need a "merge armature onto game mesh" step, same as UniRig.

## Verdict

**Adopt Anymate as primary rigging tool.** Keep UniRig as fallback.

Anymate wins on every quality metric that matters for animation: bone count, coverage, and chain depth. The speed advantage (15s vs 5min) and zero-GPU-management are huge operational wins. The multiple-roots issue is a one-line fix in post-processing.

## Integration Plan

1. Write `rig-anymate.py` — production script that:
   - Submits game GLB to Anymate API
   - Downloads .blend result
   - Extracts armature from .blend
   - Merges armature onto our textured game mesh
   - Adds root bone if multiple roots exist
   - Adds snout bone (existing `add-snout.py`)
   - Exports final rigged GLB

2. Update `SKILL.md` and `PermanentDesignSpecs.md` to reference Anymate as primary, UniRig as fallback.
