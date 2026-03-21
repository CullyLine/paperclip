# Drive a Car Simulator — VFX Implementation Guide

**Audience:** Roblox engineers implementing particles, UI, and camera effects.  
**Aesthetic:** Low-poly cartoon — bright, readable at speed, rarity-scaled spectacle.

---

## How to use this doc

Each effect lists **when it runs**, **what to spawn**, **exact numbers** (rates, lifetimes, hex colors), **performance budget**, **mobile LOD**, and **pseudocode** where it saves iteration time. Values assume **60 FPS target** on desktop; scale down on mobile per §Mobile LOD.

---

## Design rules (non-negotiable)

1. **Feedback** — the player must know *what* happened.  
2. **Spectacle** — higher stakes (rarity, rebirth, boost) = bigger, not noisier.  
3. **Performance** — prefer **simple quads + animated textures** over meshes; cap emitters; pool instances where popups repeat.

---

## Global color tokens (hex)

Use these consistently across particles, beams, UI strokes, and flashes.

| Token | Hex | Usage |
|--------|-----|--------|
| `WHITE` | `#FFFFFF` | Low-speed trails, Common burst base |
| `YELLOW` | `#FACC15` | Mid-speed trails, tier transitions |
| `ORANGE` | `#FB923C` | High-speed trails |
| `RED` | `#EF4444` | Max-speed trails |
| `GOLD` | `#FFD700` | Rebirth, coin popups, Legendary accents |
| `DARK_OUTLINE` | `#1C1917` | Stroke on floating currency text |
| `GREEN` | `#22C55E` | Uncommon, distance milestone accent |
| `BLUE` | `#3B82F6` | Rare |
| `PURPLE` | `#A855F7` | Epic, gem popups |
| `CYAN` | `#22D3EE` | Crystal popups |
| `LEGENDARY_ORANGE` | `#F59E0B` | Legendary primary |
| `PLATINUM` | `#E5E7EB` | High rebirth tier sparkle mix |
| `VIGNETTE` | `#0B0F14` | Egg hatch focus (multiply ~0.85 alpha at edges) |

**Mythic rainbow:** drive `ColorSequence` with keys at `0→#FF6B6B`, `0.2→#FFD93D`, `0.4→#6BCB77`, `0.6→#4D96FF`, `0.8→#C084FC`, `1→#FF6B6B` (cycle `Texture` UV or rotate `ColorSequence` offset each frame).

---

## Global performance budgets

| Context | Max simultaneous particles (desktop) | Notes |
|---------|--------------------------------------|--------|
| **Steady driving** | **≤350** total on screen | Hard cap for combined systems |
| Speed trails | **≤100** | Highest priority while driving |
| Currency popups | **≤30** emitter children / billboard stack | Pool `BillboardGui` |
| Pet orbit glow | **≤16 per pet**, **≤8 pets** → **≤128** | Medium priority |
| Ambient world | **≤50** | First to cull |
| Egg hatch spike | **≤200** | <2s typical |
| Rebirth spike | **≤300** | <3s |
| Rarity reveal burst | **50–200** by tier | See §2 Egg hatch |

**Spike allowance:** ≤**500** particles for hatch/rebirth windows **&lt;3s**.  
**Mobile steady-state:** **≤175** particles; **halve** tier counts for hatch/rebirth; **disable ambient** on low-end.

---

## Mobile LOD matrix

| Setting | Low-end | Mid | High |
|---------|---------|-----|------|
| Ambient world | **Off** | 50% rate | Full |
| Speed trail `Rate` | **50%** | 75% | 100% |
| Trail `Lifetime` | −20% | full | full |
| Screen post (blur, CA) | **Off** | blur only | full |
| Pet orbit particles | **8/pet** | 12/pet | 16/pet |
| Egg/Rebirth bursts | **50% count** | 75% | 100% |
| `Lighting.GlobalShadows` | optional reduce | game default | full |

Detect via `UserSettings().GameSettings.SavedQualityLevel` and/or FPS throttle (if &lt;30 for 2s, step LOD down).

---

# 1. Speed trails (driving)

### Purpose

Two parallel streaks **behind rear wheels**, always on while driving; intensity scales with **studs/s** and **boost**.

### Tier mapping (from design)

| Speed (studs/s) | Trail color | Screen / post | Audio (reference) |
|-----------------|-------------|---------------|-------------------|
| 0–40 | `WHITE` wisps | None | Idle |
| 40–60 | `YELLOW` | Subtle motion blur | Mid |
| 60–80 | `ORANGE` | Moderate blur + slight FOV push | High |
| 80–100 | `RED` | Strong blur + FOV + shake | Roar |
| Boost (any, while active) | Rainbow + stars | Max blur + FOV + CA | Sonic boom |

### Implementation — base trail (two `ParticleEmitter` per car, L/R wheel)

**Attachment:** `TrailL`, `TrailR` parented to rear axle `BasePart`, offset ±X so streaks sit **behind** wheels.

| Property | Slow (~20–40) | Fast (~80–100) |
|----------|----------------|-----------------|
| `Rate` | 15–25 | 45–60 |
| `Lifetime` | `NumberRange.new(0.45, 0.55)` | `NumberRange.new(1.35, 1.65)` |
| `Speed` | `NumberRange.new(2, 5)` | `NumberRange.new(8, 14)` |
| `SpreadAngle` | `Vector2.new(8, 8)` | `Vector2.new(15, 12)` |
| `Size` | `NumberSequence.new({...})` **0.35→0.1** studs | **0.55→0.15** studs |
| `Transparency` | NumberSequence **0.55→1** | **0.15→0.85** (more opaque mid) |
| `LightEmission` | 0.35 | 0.65 |
| `RotSpeed` | `NumberRange.new(-30, 30)` | `NumberRange.new(-60, 60)` |
| `Drag` | 2 | 1.2 |
| `Acceleration` | `Vector3.new(0, 0.5, 0)` slight rise | `Vector3.new(0, 1, 0)` |

**Color:** single `ParticleEmitter` — tween or step each frame:

```lua
-- studsPerSecond: number 0..120+
local function trailColor(speed)
	if speed < 40 then return Color3.fromHex("FFFFFF") end
	if speed < 60 then return Color3.fromHex("FACC15"):Lerp(Color3.fromHex("FFFFFF"), (60-speed)/20) end
	if speed < 80 then return Color3.fromHex("FB923C"):Lerp(Color3.fromHex("FACC15"), (80-speed)/20) end
	return Color3.fromHex("EF4444"):Lerp(Color3.fromHex("FB923C"), math.clamp((speed-80)/20, 0, 1))
end
```

**Width:** visual width ~**2–3 studs** via `Size` peak key ~0.2 in lifetime; **taper** tail to ~30% of peak.

**Opacity:** map design “40% → 80%” to transparency: at low speed mid-life **~0.55 alpha**; at max **~0.8 alpha** (adjust `Transparency` NumberSequence middle key).

**Particle budget:** **≤100** total for both wheels + any boost add-ons.

### Boost overlay

- **Trigger:** while boost timer &gt; 0.  
- **Extra emitters:** **1** “star streak” rear center, `Rate` **20–40**, `Lifetime` **0.3–0.6**, rainbow `ColorSequence` (see Mythic).  
- **Screen:** `Camera.FieldOfView` **65 → 75** over **0.2s** `TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)`; restore when boost ends.  
- **Radial blur:** `DepthOfField` or custom fullscreen with **0.15–0.25** intensity at edges only (mobile: **skip**).  
- **Chromatic aberration:** post only on high tier; **off** on mobile LOD low.

---

# 2. Egg hatch animation (full sequence + rarity burst)

### Timeline (seconds) — lock these for UI/audio sync

| Phase | Time | What happens |
|-------|------|----------------|
| **Anticipation** | **0.0–2.0** | Rock, dust, crack lines (rarity color), camera zoom, orbit sparkles |
| **Crack** | **2.0–3.0** | Violent rock, spiderweb cracks, rarity beams, vignette, chime |
| **Reveal** | **3.0–4.5** | Shatter fragments, **rarity burst**, pet float + spin, background flash, name/rarity UI |
| **Celebration** | **4.5–6.0** | Confetti, pet idle, stats card, CTA buttons |

### Phase 1 — Anticipation (0–2s)

- **Egg model:** `CFrame` rock **±4°** yaw sinusoid, period **~0.5s**, amplitude ramps **0→1** over 2s (`math.sin` * envelope).  
- **Dust:** 1 emitter at base, `Rate` **8–15**, `Lifetime` **0.4–0.8**, color `#D4C4A8`, **max particles 20**.  
- **Crack decal/texture:** opacity **0→1** over 1.5s; emissive tint = **rarity hex** at 0.3 intensity.  
- **Camera:** offset **−2 studs** dolly-in, **+5°** pitch, **1.8s** tween, `Sine` in/out.  
- **Sparkle orbit:** 1 emitter `Rate` **10–20**, **2** sec lifetime, orbit via **rotating attachment** or **Beam** ring; **≤30** particles.

### Phase 2 — Crack (2–3s)

- Rock amplitude **×1.8**.  
- Secondary crack layer alpha **0→1** in **0.4s**.  
- **Beams:** 3–6 `Beam` parts from cracks, `Color` = rarity, `Transparency` 0.2→1 in **0.8s**.  
- **Vignette:** `ColorCorrection.TintColor` toward `#0B0F14`, **~15%** darker at corners (use UI ImageLabel fullscreen multiply **0.85** alpha radial).

### Phase 3 — Reveal (3–4.5s)

- **Fragments:** welded parts + `BodyVelocity`/`LinearVelocity` impulse **outward 40–80 studs/s**, `AngularVelocity` random; fade **1.2s**.  
- **Rarity burst:** spawn **one** `Attachment` at egg center; run table below (**exact counts**).  
- **Pet:** anchor float **+2 studs** over **0.6s**, spin **360°** over **0.8s** `Back` out.  
- **Background flash:** fullscreen solid rarity color **0.15s** fade **1→0** alpha.

### Phase 4 — Celebration (4.5–6s)

- **Confetti:** `Rate` **25–40** for **1.2s** only, gravity **35**, rarity-tinted sheets. **≤60** particles this phase.  
- **UI:** card slides **0.35s** from bottom, buttons pulse scale **1→1.05** loop 2×.

### Rarity burst — particle counts & patterns (exact)

Spawn from **one** radial burst attachment unless noted. “Stars” = second emitter with star texture.

| Rarity | Hex anchor | Particles | Pattern | Extra | Duration | Screen |
|--------|------------|-----------|---------|-------|----------|--------|
| **Common** | `#FFFFFF` | **20** circles | Radial | — | **0.5s** | none |
| **Uncommon** | `#22C55E` | **30** + **10** stars | Radial + slight spiral (`Angle` + `RotSpeed`) | Faint aura **1s** on pet (`PointLight` range **6`, brightness **0.8→0`) | **0.7s** | none |
| **Rare** | `#3B82F6` | **50** + **20** stars + **4** beams | Radial + **4** directional rays | Blue aura pulse **1** pulse | **1.0s** | Subtle `#3B82F6` flash **0.1s** |
| **Epic** | `#A855F7` | **80** + **30** + wisps **20** | Spiral + **6** rays | Pulsing aura + **10** lingering floaters **3s** | **1.5s** | Purple flash + **shake 0.2s** amp **0.35** |
| **Legendary** | `#F59E0B` | **120** + **50** stars + bolts **16** + confetti **24** | Radial + **8** rays + **1** expanding ring | Gold aura + **permanent** orbit stars (**Rate 4**, cap **20**) | **2.0s** | Gold flash + shake **0.35s** + **0.25s** hitstop |
| **Mythic** | Rainbow | **200** + **80** + bolts **24** + fire wisps **40** + confetti **40** | **Sphere out → collapse → second out** | Rainbow aura + **permanent** fire orbit (**Rate 6**, cap **24**) + pet **rainbow trail** when moving | **3.5s** | Rainbow flash → **whiteout 0.12s** → CA **0.4s** + slow-mo **0.25s** |

**Mythic “MYTHIC!!!” UI:** `TextLabel` with `UIGradient` rotating offset; **spring** scale: overshoot **1.2** at **0.15s**, settle **0.35s**.  
**Server chat:** `"{Player} hatched a MYTHIC {PetName}!"` — use `TextChatService` with rich text rainbow if available.

**Burst pseudocode:**

```lua
local function spawnBurst(tier, origin)
	local spec = BURST_TABLE[tier] -- counts, duration, shake, hitstop
	local att = Instance.new("Attachment")
	att.WorldPosition = origin
	-- emitters: Core, Stars, Optional Wisps
	-- for Mythic: tween attachment scale 1->0.3->1.2 over duration
	task.delay(spec.duration, function() att:Destroy() end)
end
```

---

# 3. Rebirth effect

### Trigger

Player confirms at **Rebirth Altar**.

### Timeline — **3.0s total** (lock UI to this)

| Segment | Time | VFX |
|---------|------|-----|
| **Charge** | **0.0–1.0** | Golden streams converge on player; camera **−4 studs** pull back; pitch ramp audio |
| **Burst** | **1.0–1.5** | Full-screen warm flash `#FFD700` → white core **0.08s**; radial rays; outward particle blow |
| **Transform** | **1.5–2.5** | Model **gold** `ColorShift` / highlight; float **+1.5 studs** **0.35s** then slam down; **shockwave** ring mesh scale **0→40 studs** in **0.45s**, fade alpha |
| **Celebration** | **2.5–3.0** | Gold confetti **Rate 35** for **0.5s**; “REBIRTH {N}!” with fire gradient; stat numbers **count lerp**; new multiplier flash **green** `#22C55E` |

### Tier scaling (rebirth count)

| Rebirth # | Visual add |
|-----------|------------|
| **1–5** | Base gold only |
| **6–10** | + **silver** sparkles (`#E5E7EB`), burst scale **×1.15** |
| **11–20** | + **platinum** tint mix, **screen shake** amp **0.25**, duration **0.15s** |
| **21+** | **Rainbow gold** (warm gradient on particles), **max particle** table row, bass-heavy mix |

### Particle budget

**≤300** simultaneous during burst; **≤120** steady by **2.0s** (fade aggressors).

### Pseudocode (camera + shake)

```lua
local ti = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
TweenService:Create(camera, ti, {FieldOfView = camera.FieldOfView + 8}):Play() -- charge
task.delay(1.0, function()
	shake:Impulse(0.35, 0.4) -- burst
	flash:Stroke(Color3.fromHex("FFD700"), 0.15)
end)
```

---

# 4. Currency popup numbers

### Coin (+amount)

| Property | Value |
|----------|--------|
| Text | `"+{amount}"` **bold**, fill `#FFD700`, stroke `#1C1917` **thickness 2** |
| Billboard | `Size = UDim2.fromOffset(200, 64)`, `StudsOffsetWorldSpace` above earn point |
| Motion | **+50 studs** world Y over **1.0s** |
| X drift | `Random.new():NextNumber(-3, 3)` studs added via `CFrame` offset or parallel tween |
| Scale | **1.0 → 1.2** at **0.25s**, then **→ 0.8** by **1.0s** (`Quad` out) |
| Transparency | **0 → 1** over **1.0s** `EaseOut` |
| Max concurrent | **≤30** popups; **merge** rapid fires (see below) |

**Combo merge:** if next coin event **&lt;0.15s** after previous, **reuse** same `BillboardGui`, **add** amounts, **bump** scale to **1.35** briefly, reset fade timer.

### Gems / crystals

- **Gems:** fill `#A855F7`, **+15%** default `TextSize` vs coins; **8** purple sparkles parented, `Rate` **12**, **0.5s** life.  
- **Crystals:** fill `#22D3EE`, **+20%** `TextSize`; **ice** shard texture sparkles, same cap.

### Distance milestone (signs)

- Banner: `"{distance} studs!"` white `#FFFFFF`, **green** glow `#22C55E` (`UIStroke` + `TextColor3`).  
- **Slide:** from **+400px** X to **0** in **0.25s**, hold **1.0s**, exit **0.25s**.  
- Simultaneous **small coin popup** (same rules, **+10–50** typical).

```lua
local function popupCoin(at: Vector3, amount: number)
	local gui = pool:Get() -- BillboardGui
	gui.Adornee = attachPart
	local goal = at + Vector3.new(rand:NextNumber(-3,3), 50, 0)
	TweenService:Create(attachPart, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = goal -- or CFrame tween
	}):Play()
	TweenService:Create(text, TweenInfo.new(1), {TextTransparency = 1}):Play()
	task.delay(1, function() pool:Release(gui) end)
end
```

---

# 5. Pet orbit glow (follow VFX)

### Orbit (reference from design)

- **Height:** head height.  
- **Radius:** ring **1 = 4 studs**, ring **2 = 8 studs** if &gt;4 pets.  
- **Period:** **~10s** per revolution (`2π / 10` rad/s).  
- **Bob:** amplitude **0.5 studs**, period **2s** sine on Y.

### Glow by rarity (scaled)

| Rarity | `PointLight` | Extra VFX | Particle cap / pet |
|--------|----------------|-----------|---------------------|
| **Common** | **Off** or brightness **0.2**, range **4**, `#FFFFFF` | — | **0** |
| **Uncommon** | **0.6**, range **6**, `#22C55E` | — | **4** |
| **Rare** | **0.9**, range **8**, `#3B82F6` | Soft `Beam` halo ring | **8** |
| **Epic** | **1.1**, range **10**, `#A855F7` | Pulse light + **6** motes | **12** |
| **Legendary** | **1.3**, range **12**, `#F59E0B` | **Permanent** orbit stars **Rate 4**, cap **20** shared | **16** |
| **Mythic** | **1.2** cycling hue | Rainbow `Trail` or **Ribbon** + **fire** motes **Rate 6**, cap **24** | **16** |

**Mythic trail while orbiting:** same rainbow sequence as boost; **mobile LOD:** **disable trail**, keep **PointLight** only.

### Equip / summon (0.8s)

- Torus/ring mesh at spawn: **rarity color**, scale **0→1.2 studs** in **0.15s**, shrink **0.1s**.  
- Spark burst: **tier-scaled** count **12–40** (use **50%** on mobile).  
- Pet **bounce** **+0.8 studs** **0.2s** `Back` out.

### Unequip (0.5s)

- Pet **scale 1→0**, **0.45s** `Quad` in; spiral **axis** via **CFrame** lerp + **AngularVelocity**; suction portal **0.35s** shrink.

---

# 6. Lap completion flash

*Cross-reference:* highway markers in ambient doc — treat **lap line** as a **milestone** with **stronger** feedback than a normal sign.

### Implementation

- **Trigger:** `Touched` / checkpoint **forward** plane crossed once per lap.  
- **Duration:** **0.35s** total primary read.

| Layer | Spec |
|-------|------|
| **Fullscreen flash** | White `#FFFFFF` **→** rarity run accent `#FACC15` edge **0.08s** fade; peak alpha **0.35** (not full whiteout unless final lap variant) |
| **Vignette pulse** | Inverse: center stays clear, **+10%** edge darken **0.15s** |
| **Chromatic aberration** | **Optional** high only; **0.12s** |
| **Radial streaks** | 8–12 `Beam` or masked UI rays, rotate **90°/s** for **0.25s** |
| **Particles** | **16** directional streaks from **bottom-center** (speed sense), `Lifetime` **0.4s` |
| **Sound** | Short **whoosh + ding**; pitch **+0.1** if PB |

**Budget:** **≤40** particles + **1** fullscreen UI; **mobile:** flash **only** (no CA, **12** particles).

```lua
local function lapFlash(isPersonalBest: boolean)
	local peak = isPersonalBest and 0.45 or 0.35
	flashFrame.BackgroundTransparency = 1 - peak
	TweenService:Create(flashFrame, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
	if isPersonalBest then
		confettiBurst({ count = 24, duration = 0.6 })
	end
end
```

---

# 7. World transition (portal / teleport)

### New world unlock — **2.0s**

- Portal swirl: **theme color** particles **Rate 40**, cap **80** over **2s**.  
- Camera **dolly** through portal: **FOV +12** in **1s**, **CFrame** lerp through portal frame.  
- Sky **crossfade** **1.2s** (`Lighting.Ambient` / `OutdoorAmbient` tween + `Atmosphere` if used).

### Teleport between worlds — **1.0s**

- **0.3s** fade to black → **0.3s** hold → **0.4s** fade in.  
- Optional **motion blur** mid only (desktop).

---

# 8. Ambient world VFX (Grasslands)

| System | Budget | Notes |
|--------|--------|--------|
| Pollen / seeds | **10–15** visible | `Rate` **2–4**, large lifetime, slow drift |
| Butterflies | **2–3** billboards | Simple texture swap animate |
| Grass | Vertex shader / **no** particles | |
| Birds | Silhouette quads | Occasional spawn, **≤2** active |
| **Highway markers** | **Burst ≤12** on pass | Brief **glow** on sign emissive **0.25s** |
| **Lobby pedestals** | **≤20** sparkles | Slow pulse emissive on egg base |
| **Rebirth altar** | **≤25** embers | Warm `#FFD700` / `#FB923C`, low `Rate` |
| **Showroom** | Spot cones + floor gloss | Non-particle |
| **Pet shop** | Idle anims visible | Audio only |

**Cull order:** ambient first → pet motes → currency → trails last.

---

## Rarity scaling — quick reference (all systems)

| Tier | Particle bias | Light | Screen FX |
|------|---------------|-------|-----------|
| Common | Minimal | None | None |
| Uncommon | Low | Soft | None |
| Medium Rare | Mid | Medium | Light flash |
| Epic | High | Strong | Shake |
| Legendary | Very high | Very strong | Shake + hitstop |
| Mythic | Max + multi-phase | Max + rainbow | Whiteout + CA + slow-mo |

---

## Checklist before shipping

- [ ] Steady drive **≤350** particles; spikes **≤500** &lt;3s  
- [ ] Mobile: ambient off, counts halved, no CA on lap/hatch  
- [ ] All rarity hex values from **Global color tokens**  
- [ ] Egg hatch **6.0s** master timeline synced with UI  
- [ ] Currency pool prevents **&gt;30** simultaneous texts  
- [ ] Lap flash readable in **&lt;0.4s** without full whiteout (unless PB variant)

---

*Derived from `vfx-direction.md`; this file adds Roblox-specific implementation numbers, budgets, and code hooks for engineering handoff.*
