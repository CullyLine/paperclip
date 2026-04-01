# Italian Brainrot Egg — V1 Review & V2 Plan

## Per-Pet Feedback (from V1 review)

### Cappuccino Assassino — FULL REDO
- **Concept art**: Remove Naruto logo from headband (plain blank buckle instead). Remove sword entirely.
- **3D gen**: Regenerate from scratch
- **Bones**: V1 bones went crazy. Ensure arms and legs each have proper bone chains.
- **Status**: Redo from concept art

### Tung Tung Tung Sahur — PARTIAL REDO
- **Concept art**: Remove club entirely. Arms should be raised (T-pose) so they don't fuse with lower torso during decimation.
- **Decimation**: Higher poly — **600–800 faces** (not 340). Keep fingers and toes visible for bone wiggling.
- **Bones**: V1 skeleton was great, keep similar placement.
- **Status**: Redo from concept art (T-pose + no club)

### Tralalero Tralala — BONE FIXES
- **Concept art**: Address Nike logo on shoes (make generic sneakers)
- **Mesh**: V1 mesh looks great
- **Bones needed**: Top fin (missing), right arm (missing), nose (add for cuteness)
- **Status**: May need concept art touch-up for shoes, definitely needs bone fixes

### Bombardiro Crocodilo — BONE FIXES
- **Mesh**: V1 mesh is good (user already edited bomb out)
- **Bones**: V1 has cool back bones BUT only back bones. Needs: wings, head, spine
- **Status**: Bone rework needed, mesh is fine

### Bombombini Gusini — BONE FIX
- **Mesh**: Looks amazing
- **Bones**: Missing bones on wings
- **Status**: Minor bone fix only

## Key Lessons for V2

### Concept Art Rules
1. **T-pose for characters with arms** — prevents limb fusion during decimation
2. **Remove weapons/accessories** that won't survive decimation — simpler silhouettes decimate better
3. **No brand logos** — Roblox TOS risk + they get mangled at low poly anyway
4. **Clear separation between appendages** — fins, wings, arms should have visible gaps

### Decimation Rules
1. Standard pets: **340 faces**, voxel size **0.032**
2. Detailed characters (humanoid with fingers/toes): **600–800 faces**, voxel size **0.020–0.025**
3. Inspect every model after decimation for fused geometry

### Bone Placement Problem
UniRig auto-places bones based on mesh shape. We can't directly control where bones go.

**Possible solutions (need to test):**
- Better mesh shape → better bone placement (T-pose, clear appendages)
- Manual bone addition in Blender after UniRig (add missing bones, parent to existing skeleton)
- Custom bone placement script as post-processing

### Pipeline Gaps — RESOLVED
1. ~~No automated way to validate bone coverage~~ → `validate-bones.py` + `inspect-bones.py`
2. ~~No way to request specific bones from UniRig~~ → Highpoly rig strategy produces 15-20+ bones
3. ~~No post-rig bone editing step documented~~ → `add-bones.py` + `add-snout.py`
4. ~~Concept art iteration loop needs tighter feedback~~ → Rules in PermanentDesignSpecs.md §1.3

### Future: Smart Bone Inference (post-rig analysis)

**Idea:** After UniRig rigging, automatically detect body components by analyzing
mesh geometry, then add missing bones based on detected patterns.

**How it would work:**
1. **Segment the mesh** — identify connected regions extending from the body center
2. **Classify appendages** by spatial orientation:
   - Lateral extensions at mid-height → **wings** or **pectoral fins**
   - Dorsal extensions (top, +Z) → **dorsal fin** or **crest**
   - Frontal extension (forward, -Y) → **snout** (already handled)
   - Posterior extension (back, +Y) → **tail** or **caudal fin**
   - Downward extensions (-Z) → **legs** or **feet**
3. **Check bone coverage** — does each detected appendage have at least one bone nearby?
4. **Auto-generate** missing bones along the appendage axis

**Patterns to detect:**
| Pattern | Detection heuristic | Bones to add |
|---------|-------------------|--------------|
| Wings | Two symmetric lateral mesh extensions, thin profile | 1-2 bones per wing |
| Dorsal fin | Single top-center extension, thin profile | 1-2 fin bones |
| Tail | Posterior extension narrowing toward tip | 1-2 tail bones |
| Pectoral fins | Small lateral extensions below wing level | 1 bone each |
| Antennae | Thin forward-upward extensions from head | 1 bone each |

**Key insight from Cully:** This is NOT about replacing UniRig's output — it's a
complementary post-step that catches the appendages UniRig consistently misses on
low-poly meshes. The highpoly strategy already gets most bones right; smart inference
would handle the remaining 5-10% edge cases.

**Status:** Concept documented. Implementation deferred to after V2 pet production.
