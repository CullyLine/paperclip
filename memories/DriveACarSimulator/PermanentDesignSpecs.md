# Permanent Design Specifications — Drive A Car Simulator 3D Pets

Canonical reference for the visual style, offline mesh pipeline (Hunyuan → decimate → UniRig),
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

### 1.2 Image Generation Prompt Template

Every pet concept art image MUST use this prompt structure:

```
ONE SINGLE cute chibi [CREATURE_DESCRIPTION] pet character for a Roblox game.
[BODY_DESCRIPTION with specific colors, markings, and features].
[EYE_DESCRIPTION]. [DISTINCTIVE_FEATURES].
Simplified rounded toy-like proportions.
Only ONE character, no text, no labels.
Centered on pure white background, product photography lighting, studio render.
```

### 1.3 Mandatory Prompt Rules

| Rule | Reason |
|------|--------|
| "ONE SINGLE" at start | Prevents multi-character lineups |
| "no text, no labels" | Prevents species/rarity text overlays |
| "pure white background" | Clean isolation for 3D generation |
| "product photography lighting, studio render" | Consistent soft lighting, no dramatic shadows |
| "Simplified rounded toy-like proportions" | Enforces chibi style |
| "Centered" | Optimal framing for Hunyuan3D input |
| Front or three-quarter view | Best 3D reconstruction angle |

### 1.4 Reference Image

Use `memories/DriveACarSimulator/ConceptArt/pet-designs-rarity-tiers.png` as a
style reference when generating concept art. Pass it as a reference image to
maintain visual consistency with the established lineup.

### 1.5 Concept Art File Convention

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
| Target faces | **340** | Produces 300–400 face models |
| Voxel size | **0.005** | Controls remesh density; larger = fewer faces |
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
blender --background --python decimate.py -- <input.glb> <output.glb> 340 0.005
```

### 4.4 File Convention

- Game-ready output: `memories/3d-experiments/{name}-game-340.glb`
- Expected size: **400 KB – 1.5 MB** (mesh + packed 1024px texture)

---

## 5. Auto-Rigging — UniRig

### 5.1 Location

- UniRig root: `F:\CODE STUFF\tools\UniRig\`
- Python venv: `F:\CODE STUFF\tools\UniRig\venv\`
- Required env: `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`

### 5.2 Pipeline (4 steps)

1. **Extract** (`src.data.extract`): Converts mesh to internal format
2. **Skeleton** (CPU, `run.py`): Predicts bone structure (~30–120s)
   - Config: `configs/task/quick_inference_skeleton_articulationxl_ar_256_cpu.yaml`
   - Uses eager attention (not flash_attention_2) for CPU compatibility
3. **Skin** (GPU, `run.py`): Predicts skinning weights (~40–600s)
   - Config: `configs/task/quick_inference_unirig_skin.yaml`
   - Requires CUDA (spconv)
4. **Merge** (`src.inference.merge`): Combines rig into original GLB

### 5.3 Critical Path Bridging

The skeleton step saves `predict_skeleton.npz` adjacent to the input model, NOT
in the tmp directory. Before running the skin step, copy it:

```
<input-dir>/<model-name>/predict_skeleton.npz
  → results/<model-name>_skeleton/predict_skeleton.npz
```

### 5.4 Known Issues

- `bpy` crash on exit (code 3221225477 / -1073741819): harmless, output is fine
- `rig.ps1` has a `$Input` parameter conflict with PowerShell — run steps manually
- Seed: **12345** (default, consistent results)
- faces_target_count for extract: **50000**

### 5.5 Expected Skeleton Output

UniRig produces ~8–20 bones named `bone_0` through `bone_N`. The exact count and
hierarchy varies per model shape. Typical ranges:

| Shape | Bones | Notes |
|-------|-------|-------|
| Quadruped (cat, dog, fox, panther) | 10–15 | Spine chain + limb branches |
| Bird (owl, phoenix) | 8–14 | Spine + wing branches |
| Biped (dragon sitting) | 8–12 | Spine + arm/leg stubs |
| Amorphous (jellyfish, whale) | 8–14 | Long spine chain + appendage branches |
| Aberrant (cronenberg) | 10–18 | Unpredictable branching |

### 5.6 File Convention

- Rigged output: `memories/3d-experiments/{name}-game-340_rigged.glb`
- Expected size: rigged GLB is ~5–15% larger than decimated GLB
- **Next step:** import into Roblox Studio and animate in **Luau** (§6). Do not require Blender batch animation for shipping.

---

## 6. Animation — Roblox Studio (Canonical)

**Production animation is in the game client**, not in Blender. Offline pipeline output is a **rigged GLB**; after import into Studio, **`PetAnimator.luau`** drives `Bone.Transform` each frame.

### 6.1 Standard States

| State | When |
|-------|------|
| **idle** | Player mostly stationary |
| **walk** | Player moving |
| **float** | Driving / roof-ride, or flying locomotion pets |

### 6.2 Implementation

| Module | Role |
|--------|------|
| `DACReplicatedStorage/PetAnimator.luau` | Registry (`_generic`, `jellyfish`, `whale`, …), `osc()` in Luau, skeleton analysis, `start` / `setAnim` / `stop` |
| `DACStarterPlayerScripts/Controllers/PetController.luau` | V-formation, roof-ride, calls PetAnimator |

### 6.3 The `osc()` Helper (Luau)

Same math as the old Blender reference; time is continuous (`os.clock()`), not frame index:

```lua
local function osc(t: number, cycles: number, amplitude: number, phase: number?): number
    return amplitude * math.sin(t * cycles * 2 * math.pi + (phase or 0))
end
```

### 6.4 Jellyfish and Custom Sets

Per-pet overrides live in **`PetAnimator`** `ANIM_REGISTRY` (e.g. slower tendril motion for jellyfish). Add a new entry there when a species needs bespoke motion.

### 6.5 Legacy Blender Scripts (Non-Shipping)

The repo may still contain `memories/3d-experiments/universal-animate.py`, `batch-animate.py`, and related files from an earlier **Blender keyframe** experiment. **Do not** document them as part of the shipping pipeline or require them for new pets. They are optional historical reference only.

---

## 7. Batch Pipeline Scripts

All in `memories/3d-experiments/`:

| Script | Purpose |
|--------|---------|
| `batch-submit.py` | Submit images to Hunyuan3D v3, saves request IDs to `batch-tracker.json` |
| `batch-fetch.py` | Poll and download all completed GLBs |
| `batch-decimate.py` | Decimate all highpoly GLBs to 340 faces |
| `batch-rig.py` | Auto-rig all decimated models with UniRig |
| `batch-animate.py` | *(legacy; optional)* — old Blender NLA experiment; **not** shipping |
| `batch-tracker.json` | Central state tracker (may still list legacy `animated` steps) |

---

## 8. File Naming Convention

```
{name}-concept.png          → Concept art (in assets/)
{name}-highpoly.glb         → Raw Hunyuan3D output (~18-33 MB)
{name}-game-340.glb         → Decimated game-ready (~0.4-1.5 MB)
{name}-game-340_rigged.glb  → **Shipping offline output** — skeleton + skin weights, import to Studio
```

Optional legacy files (e.g. `*_animated.glb` from old Blender scripts) are **not** part of the pipeline.

All 3D files live in `memories/3d-experiments/`.

---

## 9. Quality Targets

| Metric | Target | Acceptable Range |
|--------|--------|-----------------|
| Face count | 340 | 300–400 |
| Texture resolution | 1024×1024 | 512–1024 |
| Rigged GLB size | < 1.5 MB | Up to 2 MB |
| Bone count | 8–18 | Whatever UniRig produces |
| In-game motion | idle / walk / float (Luau) | `PetAnimator` + `PetController` |

---

## 10. Roblox Integration

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
| group_member | `"puppy"` | (shares puppy model) | 25 |

### Runtime animation (see also §6)

Animations are **procedural via Luau** (not published `Animation` assets). Implementation: **`PetAnimator.luau`** (bone transforms + registry) and **`PetController.luau`** (placement + LOD). API and `osc()` details: **§6**.

### Locomotion Types

Each pet in `PetConfig.luau` has a `locomotion` field:
- `"ground"` — follows at 2 studs above ground
- `"flying"` — follows at 4 studs above ground

### MAX_FOLLOWING

`PetConfig.MAX_FOLLOWING = 5`. Only the N strongest equipped pets (by power) are
visually spawned. Applies to both local and remote pet displays.

---

## 11. Pet Following System

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

## 12. Produced Pet Inventory

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
