# Permanent Design Specifications — Drive A Car Simulator 3D Pets

Canonical reference for the visual style, offline mesh pipeline (Hunyuan → decimate → Anymate rig),
and **in-game** animation/following for 3D pets in Drive A Car Simulator. Any AI agent
creating, modifying, or extending pet assets MUST follow these specifications exactly.

---

## 1. Art Style — Concept Art

### 1.1 Core Aesthetic

- **Chibi / super-deformed** proportions: oversized head (40–50% of body), stubby limbs, round body
- **Toy-like**: smooth surfaces, no sharp edges, simplified anatomy
- **Roblox collectible pet** feel: think Adopt Me / Pet Simulator X tier
- Big expressive eyes with sparkle/star reflections
- Small noses, minimal mouths (smile line or tiny open mouth)
- Colors are vibrant and saturated, not muted or realistic

### 1.2 Reference-Based Concept Art (CRITICAL)

**Always use a reference image of the real character** when generating concept art
for pets based on existing characters (memes, IPs, etc.). The reference image ensures
the generated pet actually looks like the character, not a generic interpretation.

**Two-reference approach:**
1. **Character reference** — a screenshot/image of the actual character (downloaded to
   `memories/3d-experiments/<name>-ref.jpg`). Pass as `reference_image_paths`.
2. **Style enforcement** — the prompt itself enforces chibi toy proportions.

This combination produces pets that are both **recognizable** and **game-style-consistent**.
Without the character reference, concept art tends to drift into generic interpretations
that don't match the source material.

### 1.3 Image Generation Prompt Template

Every pet concept art image MUST use this prompt structure:

```
ONE SINGLE adorable chibi super-deformed Roblox collectible pet toy figure based on
[CHARACTER_NAME]. The character is [BODY_DESCRIPTION from reference — shape, colors, key features].
Key features from the reference: [LIST 3-4 DEFINING VISUAL ELEMENTS].
CHIBI STYLE: oversized head (40-50% of total body), very stubby short [arms/limbs]
in T-pose spread out from body, very stubby short legs. The proportions should look
like a squishy collectible vinyl toy figure - round, smooth, simplified.
Think Funko Pop or Pet Simulator X pet style.
NO [weapons/accessories to exclude] - empty tiny hands.
Vibrant saturated colors, smooth toy-like surfaces.
Only ONE character, no text, no labels.
Centered on pure white background, product photography lighting, studio render,
front three-quarter view.
```

### 1.4 Mandatory Prompt Rules

| Rule | Reason |
|------|--------|
| "ONE SINGLE" at start | Prevents multi-character lineups |
| Always pass character reference image | Ensures accuracy to source material |
| "chibi super-deformed" + "squishy collectible vinyl toy" | Enforces game art style |
| "Think Funko Pop or Pet Simulator X pet style" | Anchors to correct proportions |
| "front three-quarter view" | Best 3D reconstruction angle |
| "no text, no labels" | Prevents species/rarity text overlays |
| "pure white background" | Clean isolation for 3D generation |
| "product photography lighting, studio render" | Consistent soft lighting, no dramatic shadows |
| "T-pose" for humanoids/armed characters | Prevents limb fusion during decimation |
| No brand logos (Nike, Naruto, etc.) | Roblox TOS risk + mangled at low poly |
| No held weapons/accessories | They don't survive decimation — add in Studio instead |
| Clear gaps between appendages | Wings, fins, arms need visible separation for bone placement |
| "very stubby short" for ALL limbs | Prevents tall/lanky proportions that break chibi style |

### 1.5 Reference Images

**Character references** are stored at `memories/3d-experiments/<name>-ref.jpg`.
Download from Know Your Meme, fan wikis, or official sources using a Python script.

**To download a reference image:**
```python
import urllib.request
req = urllib.request.Request(url, headers={
    "User-Agent": "Mozilla/5.0 ...",
    "Referer": "https://knowyourmeme.com/",
})
urllib.request.urlretrieve(url, "memories/3d-experiments/<name>-ref.jpg")
```

Never use PowerShell for downloads — always Python.

### 1.6 Concept Art File Convention

Save to: `assets/pet-{name}-concept.png`

The image tool saves to: `C:\Users\lineb\.cursor\projects\f-CODE-STUFF-Paperclip\assets\`

---

## 2. Rarity Color Language

Each rarity tier has a distinct color palette. New pets MUST follow this system.

| Rarity | Color Direction | Example |
|--------|----------------|---------|
| Common | Neutral, natural tones (gray, brown, orange tabby) | Puppy (gray), Tabby Cat (orange) |
| Uncommon | Single accent color, natural base (blue, green tint) | Fox (navy blue w/ snowflake), Owl (white/icy blue) |
| Rare | Bolder colors, slight stylization | Wolf, Eagle |
| Epic | Vivid fantasy colors, elemental themes | Dragon (emerald green + orange flame), Phoenix (orange/gold glow) |
| Legendary | Premium colors, magical effects (glow, wisps, sparkle) | Unicorn (lavender + rainbow), Shadow Panther (black + purple wisps) |
| Mythic | Cosmic/ethereal, translucent/glowing, otherworldly | Cosmic Whale (star-speckled), Jellyfish (bioluminescent cyan) |

### 2.1 Existing Pet Visual Identities (Produced)

| Pet | Key Visual Features |
|-----|-------------------|
| Tabby Cat | Orange tabby stripes, green eyes, white chest patch |
| Cosmic Whale | Dark blue body, star/galaxy patterns, translucent fins |
| Puppy | Soft gray fur, white chest patch, floppy ears, dark sparkle eyes |
| Fox | Deep navy blue, lighter blue chest/tail tip, snowflake forehead mark |
| Owl | Pure white/icy blue feathers, crystal blue eyes, spread wings |
| Dragon Hatchling | Emerald green scales, lighter green belly, orange flame crest, amber eyes |
| Phoenix Chick | Vibrant orange-red-gold feathers, fiery wing tips, blue eyes, warm glow |
| Unicorn | Pastel lavender body, rainbow-streaked white mane/tail, gold horn, violet eyes |
| Shadow Panther | Jet black glossy fur, purple tribal markings, purple wisps, glowing purple eyes |
| Glowing Jellyfish | Translucent cyan dome, bioluminescent blue/purple tendrils, sparkly eyes |
| Cronenberg | Multi-eyed, mixed limbs (crab claw, bird foot, tentacles), sickly green/pink/purple |
| Dachshund | Classic black-and-tan markings, extra-long body, very short legs, floppy ears |

---

## 3. 3D Generation — Hunyuan3D v3

### 3.1 Endpoint

- **Model**: `fal-ai/hunyuan3d-v3/image-to-3d` (ALWAYS v3, NEVER v2)
- **API**: fal.ai queue API (`https://queue.fal.run/`)
- **Auth**: `Authorization: Key <FAL_KEY>`
- **Input**: Base64-encoded PNG data URL in `input_image_url` field
- **Output**: High-poly textured GLB (~18–33 MB, ~100K+ faces)
- **Time**: ~2–5 minutes per model

### 3.2 Why Not v2

v2 (`fal-ai/hunyuan3d/v2`) produces geometry-only or lightly textured meshes.
v3 produces full PBR/textured GLBs suitable for production. Never use v2.

### 3.3 File Convention

- Highpoly output: `memories/3d-experiments/{name}-highpoly.glb`

---

## 4. Decimation — Blender Headless

### 4.1 Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Target faces (standard) | **340** | Produces 300–400 face models |
| Target faces (detailed) | **600–800** | Humanoids with fingers/toes, complex silhouettes |
| Voxel size (standard) | **0.032** | For ~340 face pets |
| Voxel size (detailed) | **0.020–0.025** | For ~600-800 face pets |
| Bake resolution | **1024 x 1024** | Diffuse color bake from high-poly to low-poly |
| Bake engine | Cycles (CPU) | 64 samples, diffuse color pass only |
| UV method | Smart UV Project | angle_limit=1.15192, island_margin=0.02 |
| Max decimate iterations | 12 | Safety cap on collapse passes |

### 4.2 Process

1. Import high-poly GLB
2. Duplicate mesh (original kept as bake source)
3. Voxel remesh duplicate (watertight, uniform topology)
4. Iterative collapse decimate until ≤ target × 1.08
5. Smart UV project on low-poly
6. Create 1024×1024 bake target image + Principled BSDF material
7. Bake diffuse from original → low-poly (selected-to-active, cage extrusion 0.05)
8. Pack image, delete original, export GLB

### 4.3 Script

`decimate.py` at repo root. Usage:

```
blender --background --python decimate.py -- <input.glb> <output.glb> 340 0.032
```

### 4.4 Manual Cleanup (if needed)

After decimation, inspect the model in Blender. If any geometry is problematic
(e.g. appendages that decimated into inappropriate shapes), manually edit:

1. Open the decimated GLB in Blender
2. Enter edit mode, select and delete problematic vertices/faces
3. Select remaining open edges → Merge at Center (or By Distance)
4. Adjust merged vertices if needed for a clean silhouette
5. Export as GLB, overwriting the same file

### 4.5 File Convention

- Game-ready output: `memories/3d-experiments/{name}-game-340.glb`
- Expected size: **400 KB – 1.5 MB** (mesh + packed 1024px texture)

---

## 5. Visual Polish — Texture Enhancement + AO

After decimation (and any manual cleanup), apply visual polish. This step enhances
the baked texture without modifying geometry.

### 5.1 What It Does

| Enhancement | Value | Effect |
|-------------|-------|--------|
| Shade smooth | normals only | Soft lighting on faces, no vertex movement |
| Saturation boost | **+40%** | Vibrant toy-like colors |
| Contrast boost | **+15%** | Crisper definition between color regions |
| Brightness lift | **+5%** | Midtones feel more alive |
| Ambient occlusion | bake × multiply (30% floor) | Depth in crevices without extra geometry |

### 5.2 Script

`memories/3d-experiments/polish-pet.py`. Usage:

```
blender --background --python polish-pet.py -- <input.glb> <output.glb>
```

Input and output can be the same file (in-place polish).

### 5.3 CRITICAL: No Geometry Smoothing

**NEVER** apply Corrective Smooth, Laplacian Smooth, Subdivision Surface, or any
modifier that moves vertices on decimated meshes. These meshes have non-manifold
geometry (disconnected faces from voxel remesh + collapse) and geometry-modifying
modifiers will "explode" the mesh — pulling faces apart at seams.

**Only shade smooth is safe** — it changes normal direction for rendering, not vertex positions.

### 5.4 File Convention

Polish is applied in-place to `{name}-game-340.glb`. No separate filename needed.

---

## 6. Auto-Rigging — Anymate (Primary) + UniRig (Fallback)

### 6.1 Anymate (Primary — HuggingFace API)

**Anymate is the default rigging tool.** It runs on HuggingFace Spaces (`yfdeng/Anymate`),
requires no local GPU, and produces superior rigs in every tested metric.

- **API**: HuggingFace Spaces Gradio client (`gradio_client`)
- **Auth**: `HF_TOKEN` env var (optional, for rate limits)
- **Speed**: ~15 seconds per model (vs 2-5 minutes for UniRig)
- **No local GPU required**: runs entirely on HuggingFace's serverless GPU

#### Why Anymate over UniRig

Tested 2026-03-31 on cappuccino, tungtung, tralalero (see `anymate-vs-unirig-report.md`):

| Metric | Anymate | UniRig | Winner |
|--------|---------|--------|--------|
| Bone count | 40–41 | 17–42 | Anymate (2x on tricky shapes) |
| Weight coverage | **100%** | 90–95% | Anymate |
| Bone chain depth | 7–12 | 5–10 | Anymate |
| Speed | ~15s | 2–5 min | Anymate |
| GPU required | No | Yes (8GB+) | Anymate |

**Overall: Anymate 11 wins — UniRig 6 wins — 1 tie.**

### 6.2 Production Pipeline — Anymate (4 steps)

**Production script:** `memories/3d-experiments/rig-anymate.py`

```bash
python memories/3d-experiments/rig-anymate.py <pet_name>       # single
python memories/3d-experiments/rig-anymate.py pet1 pet2 pet3   # batch
python memories/3d-experiments/rig-anymate.py --all            # all pets
```

Expects: `<pet>-game-340.glb` (decimated + polished)
Produces: `<pet>-game-340_rigged.glb` (final rigged model)

1. **Submit to Anymate API** — uploads game GLB to HuggingFace, runs 4 Gradio endpoints:
   - `/process_input` — upload mesh
   - `/get_all_results` — DBSCAN joint clustering (eps=0.03, min_samples=1)
   - `/vis_all` — build visualization
   - `/prepare_blender_file` — export `.blend` with armature + skinning
   - Cached: reuses existing `<pet>-anymate.blend` on reruns
2. **Merge armature onto game mesh** (Blender headless) — aligns Anymate armature
   to game mesh coordinate space, transfers vertex weights via `DATA_TRANSFER`
   modifier (`POLYINTERP_NEAREST` mapping)
3. **Fix multiple roots + add snout bone** — Anymate sometimes produces 2-4 root
   bones; script adds a master `root` parent. Snout bone auto-added for nose wiggle.
4. **Validate** — checks bone count, root count, weight coverage %, snout bone presence

### 6.3 Anymate Known Behaviors

| Behavior | Impact | Handling |
|----------|--------|----------|
| Multiple root bones (2-4) | Roblox needs single root | Auto-fixed: master root bone added in step 3 |
| Numeric bone names (`0`, `1`, `2`...) | Non-semantic but functional | Same as UniRig (`bone_0`...) — no real difference |
| API dependency (HuggingFace Spaces) | Can't rig if Space is down | Fall back to UniRig (§6.5) |
| Cached `.blend` files | Prevents re-submission | Delete `<pet>-anymate.blend` to force re-run |

### 6.4 Expected Skeleton Output (Anymate)

Anymate consistently produces high bone counts with 100% weight coverage.

| Shape | Typical Bones | Coverage |
|-------|--------------|----------|
| Humanoid (cappuccino — coffee cup ninja) | 41 | 100% |
| Biped (tungtung — stick figure) | 41 | 100% |
| Fish/shark (tralalero — shark with sneakers) | 40 | 100% |
| Quadruped (cat, dog, fox) | 35–45 | 100% |
| Amorphous (jellyfish, whale) | 25–35 | 100% |

### 6.5 Fallback — UniRig (Local GPU)

If Anymate is unavailable, use UniRig as fallback.

- UniRig root: `F:\CODE STUFF\tools\UniRig\`
- Python venv: `F:\CODE STUFF\tools\UniRig\venv\`
- Required env: `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`
- Production script: `memories/3d-experiments/rig-pet.py`
- Uses **highpoly rig strategy**: rig from highpoly → merge skeleton onto lowpoly
- Requires local GPU (8GB+), CUDA, closing other GPU apps first
- Uses `eager` attention (NOT `flash_attention_2` — WDDM deadlocks on Windows)

See `rig-pet.py` for the full 6-step UniRig pipeline. Only use when Anymate is down.

### 6.6 Post-Rig Bone Validation & Manual Fixes

Both Anymate and UniRig may occasionally miss thin appendages. The validation and
manual fix workflow applies to either tool's output.

**After every rig, validate:**
```bash
blender --background --python memories/3d-experiments/validate-bones.py -- <rigged.glb>
```

**If bones are missing, add them:**
```bash
blender --background --python memories/3d-experiments/add-bones.py -- <rigged.glb> <output.glb> <bones.json>
```

The `bones.json` specifies new bones with head/tail positions and optional parent.
The script auto-parents to the nearest existing bone and re-calculates vertex weights.

### 6.7 File Convention

- Anymate cache: `memories/3d-experiments/{name}-anymate.blend`
- Rigged output: `memories/3d-experiments/{name}-game-340_rigged.glb`
- Expected size: rigged GLB is ~5–15% larger than decimated GLB
- **Next step:** import into Roblox Studio and animate in **Luau** (§7). Do not require Blender batch animation for shipping.

---

## 7. Animation — Roblox Studio (Canonical)

**Production animation is in the game client**, not in Blender. Offline pipeline output is a **rigged GLB**; after import into Studio, **`PetAnimator.luau`** drives `Bone.Transform` each frame.

### 7.1 Standard States

| State | When |
|-------|------|
| **idle** | Player mostly stationary |
| **walk** | Player moving |
| **float** | Driving / roof-ride, or flying locomotion pets |

### 7.2 Implementation

| Module | Role |
|--------|------|
| `DACReplicatedStorage/PetAnimator.luau` | Registry (`_generic`, `jellyfish`, `whale`, …), `osc()` in Luau, skeleton analysis, `start` / `setAnim` / `stop` |
| `DACStarterPlayerScripts/Controllers/PetController.luau` | V-formation, roof-ride, calls PetAnimator |

### 7.3 The `osc()` Helper (Luau)

Same math as the old Blender reference; time is continuous (`os.clock()`), not frame index:

```lua
local function osc(t: number, cycles: number, amplitude: number, phase: number?): number
    return amplitude * math.sin(t * cycles * 2 * math.pi + (phase or 0))
end
```

### 7.4 Scale Breathing

All pets have a subtle squishy scale pulse applied by `PetAnimator`:
- **Speed**: 1.2 Hz (gentle, not frantic)
- **Amount**: 3% scale oscillation around base size
- Uses `Model:ScaleTo()` — one call per frame, very cheap
- Base scale is stored on start and restored on stop (no drift)
- This applies to ALL pets globally, not just specific species

### 7.5 Jellyfish and Custom Sets

Per-pet overrides live in **`PetAnimator`** `ANIM_REGISTRY` (e.g. slower tendril motion for jellyfish). Add a new entry there when a species needs bespoke motion.

### 7.6 Legacy Blender Scripts (Non-Shipping)

The repo may still contain `memories/3d-experiments/universal-animate.py`, `batch-animate.py`, and related files from an earlier **Blender keyframe** experiment. **Do not** document them as part of the shipping pipeline or require them for new pets. They are optional historical reference only.

---

## 8. Batch Pipeline Scripts

All in `memories/3d-experiments/`:

| Script | Purpose |
|--------|---------|
| `batch-submit.py` | Submit images to Hunyuan3D v3, saves request IDs to `batch-tracker.json` |
| `batch-fetch.py` | Poll and download all completed GLBs |
| `batch-decimate.py` | Decimate all highpoly GLBs to 340 faces |
| `rig-anymate.py` | **Production rig (primary)**: Anymate API → merge armature → fix roots → snout bone |
| `submit-anymate.py` | Standalone Anymate submission (outputs .blend, no merge) |
| `rig-pet.py` | **Fallback rig**: UniRig highpoly rig → lowpoly merge → snout bone (local GPU, use when Anymate is down) |
| `add-snout.py` | Standalone snout bone addition |
| `rig-brainrot.py` | Legacy batch rigging (lowpoly only, superseded) |
| `polish-pet.py` | Texture polish: saturation, contrast, brightness, AO bake |
| `polish-all-brainrot.py` | Batch decimate + polish + open for review |
| `batch-animate.py` | *(legacy; optional)* — old Blender NLA experiment; **not** shipping |
| `batch-tracker.json` | Central state tracker (may still list legacy `animated` steps) |

---

## 9. File Naming Convention

```
{name}-concept.png          → Concept art (in assets/)
{name}-highpoly.glb         → Raw Hunyuan3D output (~18-33 MB)
{name}-game-340.glb         → Decimated game-ready (~0.4-1.5 MB)
{name}-game-340_rigged.glb  → **Shipping offline output** — skeleton + skin weights, import to Studio
```

Optional legacy files (e.g. `*_animated.glb` from old Blender scripts) are **not** part of the pipeline.

All 3D files live in `memories/3d-experiments/`.

---

## 10. Quality Targets

| Metric | Target | Acceptable Range |
|--------|--------|-----------------|
| Face count | 340 | 300–400 |
| Texture resolution | 1024×1024 | 512–1024 |
| Rigged GLB size | < 1.5 MB | Up to 2 MB |
| Bone count | 35–45 | Whatever Anymate produces (25–45 typical) |
| In-game motion | idle / walk / float (Luau) | `PetAnimator` + `PetController` |

---

## 11. Roblox Integration

### Model Location

All pet models live in `game.ReplicatedStorage.PetModels`. Each model is a `Model`
containing a `MeshPart` named "material" with `Bone` children for the skeleton,
an `InitialPoses` folder, and an `AnimationController`.

### PetConfig modelName Mapping

`PetConfig.luau` maps each pet's `modelName` field to the model name in
`ReplicatedStorage.PetModels`. The `getPetTemplateName()` function resolves this.

| Pet ID | modelName | Roblox Model | Bones |
|--------|-----------|-------------|-------|
| tabby_cat | `"tabby"` | ReplicatedStorage.PetModels.tabby | 13 |
| puppy | `"puppy"` | ReplicatedStorage.PetModels.puppy | 25 |
| dachshund | `"dachshund"` | ReplicatedStorage.PetModels.dachshund | 32 |
| fox | `"fox"` | ReplicatedStorage.PetModels.fox | 27 |
| owl | `"owl"` | ReplicatedStorage.PetModels.owl | 12 |
| dragon_hatchling | `"dragon"` | ReplicatedStorage.PetModels.dragon | 18 |
| phoenix_chick | `"phoenix"` | ReplicatedStorage.PetModels.phoenix | 20 |
| jellyfish | `"jellyfish"` | ReplicatedStorage.PetModels.jellyfish | 5 |
| shadow_panther | `"panther"` | ReplicatedStorage.PetModels.panther | 26 |
| unicorn | `"unicorn"` | ReplicatedStorage.PetModels.unicorn | 24 |
| cosmic_whale | `"whale"` | ReplicatedStorage.PetModels.whale | 11 |
| tung_tung | `"tungtung"` | ReplicatedStorage.PetModels.tungtung | 41 |
| tralalero | `"tralalero"` | ReplicatedStorage.PetModels.tralalero | 40 |
| bombardiro | `"bombardiro"` | ReplicatedStorage.PetModels.bombardiro | — |
| cappuccino | `"cappuccino"` | ReplicatedStorage.PetModels.cappuccino | 41 |
| bombombini | `"bombombini"` | ReplicatedStorage.PetModels.bombombini | — |
| group_member | `"puppy"` | (shares puppy model) | 25 |

### Runtime animation (see also §6)

Animations are **procedural via Luau** (not published `Animation` assets). Implementation: **`PetAnimator.luau`** (bone transforms + registry) and **`PetController.luau`** (placement + LOD). API and `osc()` details: **§7**.

### Locomotion Types

Each pet in `PetConfig.luau` has a `locomotion` field:
- `"ground"` — follows at 2 studs above ground
- `"flying"` — follows at 4 studs above ground

### MAX_FOLLOWING

`PetConfig.MAX_FOLLOWING = 8`. Only the N strongest equipped pets (by power) are
visually spawned. Applies to both local and remote pet displays.

---

## 12. Pet Following System

### V-Formation

Pets follow the local player in a V-formation behind them:
- Lead pet: directly behind player (`FORM_BASE_BACK` studs, default **4**)
- Pet 2: offset left + 1 row back
- Pet 3: offset right + 1 row back
- Pet 4: offset left + 2 rows back, etc.

Spacing: **4.5** studs lateral, **3** studs back per row (`V_LATERAL_SPACING`, `V_BACK_SPACING` in `PetController.luau`).

**Walk vs idle:** Driven by player horizontal velocity and `Humanoid.MoveDirection`
(not a distance dead zone).

**Facing:** Pets face their movement direction via `CFrame.lookAt`.

**Vertical bob:** `math.sin(time * 2 + index) * 0.5` layered on top of formation
positions for gentle floating motion (preserved from original orbit system).

### Roof-Ride Mode

When `DrivingController.isInRun()` is true and the player's character has a `Car`
model with a PrimaryPart, pets switch to roof-ride mode:
- Positioned above `Car.PrimaryPart` with 2 studs Y offset
- Arranged in a compact row (`ROOF_LATERAL_SPACING`, default **2** studs)
- All pets play `float` animation
- Remote players do NOT see other players' roof-riding pets (hidden during runs)

### Cross-Player Pet Replication

**Server:** `PetService` broadcasts `PetEquipSync` to all clients on equip,
unequip, fuse, and player join/leave events.

**Client:** `PetController` listens for `PetEquipSync` and spawns/despawns
remote players' pet models in `workspace.ActivePets`.

**Settings:**
- `otherPets` (default ON): When OFF, no remote pets are spawned (zero overhead)
- `otherPetAnimations` (default ON): When OFF, remote pet bone animation is
  disabled (just float-bob positioning). When ON, full procedural animation runs.

### Preserved Visual Polish

All VFX from the original pet system are preserved:
- Rarity-based orbit glow (PointLight + sparkle motes + orbit stars for legendary/mythic)
- Equip entrance animation (scale-from-zero pop-in, burst particles, SFX, FOV punch)
- Unequip suck-in particle effect
- Non-colliding BaseParts (CanCollide=false, CanQuery=false)

---

## 13. Produced Pet Inventory

| # | Pet | Rarity | Faces | Rigged GLB (~) | Roblox Model | Bones | Status |
|---|-----|--------|-------|----------------|-------------|-------|--------|
| 1 | Tabby Cat | common | 354 | ~1.1 MB | tabby | 13 | In game |
| 2 | Cosmic Whale | mythic | 354 | ~1.2 MB | whale | 11 | In game |
| 3 | Puppy | common | ~340 | 1049 KB | puppy | 25 | In game |
| 4 | Fox | uncommon | ~340 | 861 KB | fox | 27 | In game |
| 5 | Owl | uncommon | ~340 | 1164 KB | owl | 12 | In game |
| 6 | Dragon Hatchling | epic | ~340 | 1166 KB | dragon | 18 | In game |
| 7 | Phoenix Chick | epic | ~340 | 1311 KB | phoenix | 20 | In game |
| 8 | Unicorn | legendary | ~340 | 1152 KB | unicorn | 24 | In game |
| 9 | Shadow Panther | legendary | ~340 | 1058 KB | panther | 26 | In game |
| 10 | Glowing Jellyfish | epic | ~340 | 1436 KB | jellyfish | 5 | In game |
| 11 | Dachshund | common | ~340 | 572 KB | dachshund | 32 | In game |

### Removed from production

| Pet | Reason |
|-----|--------|
| Cronenberg | Roblox moderation risk (grotesque multi-eyed body horror) |

### Not yet produced

| Pet | Rarity | Notes |
|-----|--------|-------|
| Hamster | common | Removed from PetConfig (no model) |
| Wolf | rare | Removed from PetConfig (no model) |
| Eagle | rare | Removed from PetConfig (no model) |
| Golden Dragon | legendary | Removed from PetConfig (no model) |
| Void Serpent | mythic | Removed from PetConfig (no model) |
| Neon Firefly | epic | Removed from PetConfig (no model) |
