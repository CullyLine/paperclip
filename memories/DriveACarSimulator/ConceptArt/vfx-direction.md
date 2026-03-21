# Drive a Car Simulator — VFX Direction Guide

## Design Philosophy

Every visual effect must serve two purposes:
1. **Feedback** — tell the player what just happened
2. **Spectacle** — make the player feel awesome

Effects should be bright, colorful, readable at speed, and scale with rarity/importance. Mobile performance is critical — use particle emitters efficiently, cap particle counts, and rely on simple quads with animated textures rather than complex meshes.

---

## 1. Speed Trails (Driving VFX)

### Base Speed Trail
- **Trigger:** Always active while driving
- **Visual:** Two parallel semi-transparent colored streaks behind the car's rear wheels
- **Color:** White at low speed, transitioning to yellow → orange → red as speed increases
- **Length:** Scales with speed (short wisps at 40 studs/s → long dramatic trails at 100 studs/s)
- **Width:** 2-3 studs, slight taper toward tail
- **Opacity:** 40% at base, increasing to 80% at max speed
- **Lifetime:** 0.5s at low speed, 1.5s at high speed

### Boost Speed Trail
- **Trigger:** When boost power-up is active
- **Visual:** Full-width rainbow streak behind entire car + radial speed lines on screen edges
- **Color:** Animated rainbow gradient cycling through hues
- **Screen effect:** Slight FOV increase (65° → 75°), radial blur at screen edges
- **Particles:** Small star-shaped particles ejecting backward from car
- **Duration:** Matches boost timer

### Speed Tiers Visual Cues
| Speed Range | Trail Color | Screen Effect | Audio Cue |
|-------------|-------------|---------------|-----------|
| 0–40 | White wisps | None | Engine idle |
| 40–60 | Yellow streaks | Subtle motion blur | Engine mid |
| 60–80 | Orange flames | Moderate blur + slight FOV push | Engine high |
| 80–100 | Red fire trails | Strong blur + FOV push + screen shake | Engine roar |
| 100+ (boost) | Rainbow trails | Max blur + FOV + chromatic aberration | Sonic boom |

---

## 2. Egg Hatching Sequence

### Phase 1: Anticipation (0–2s)
- Egg begins rocking side to side on its pedestal
- Small dust particles puff from base
- Crack lines appear on surface, glowing with rarity color
- Camera zooms in slightly on the egg
- Suspenseful sparkle particles orbit the egg

### Phase 2: The Crack (2–3s)
- Egg rocks violently
- Larger cracks spiderweb across surface
- Light beams shoot from cracks in rarity color
- Screen darkens slightly around edges (vignette) to focus attention
- Rising musical note / chime sound

### Phase 3: The Reveal (3–4.5s)
- Egg explodes into fragments that fly outward and fade
- Massive rarity-colored particle burst (see Rarity Reveal system below)
- Pet emerges from center, floating upward with glow
- Background flash in rarity color
- Pet does a small spin/pose animation
- Text popup: pet name + rarity badge with appropriate styling

### Phase 4: Celebration (4.5–6s)
- Confetti particles rain down (colored to match rarity)
- Pet bounces/idles happily
- UI card slides in showing pet stats
- "EQUIP" and "HATCH AGAIN" buttons appear with glow

---

## 3. Rarity Reveal Particle System

Each rarity tier has a distinct explosion pattern at the moment of reveal:

### Common (White)
- **Particles:** 20 small white circles burst outward
- **Pattern:** Simple radial burst
- **Glow:** None
- **Sound:** Soft pop
- **Duration:** 0.5s

### Uncommon (Green)
- **Particles:** 30 green circles + 10 small stars
- **Pattern:** Radial burst with slight spiral
- **Glow:** Faint green aura around pet for 1s
- **Sound:** Gentle chime
- **Duration:** 0.7s

### Rare (Blue)
- **Particles:** 50 blue circles + 20 stars + light beams
- **Pattern:** Radial burst with 4 directional light rays
- **Glow:** Blue aura pulse
- **Sound:** Rising chime sequence
- **Screen effect:** Subtle blue flash
- **Duration:** 1.0s

### Epic (Purple)
- **Particles:** 80 purple circles + 30 stars + spiraling energy wisps
- **Pattern:** Spiral burst with 6 light rays
- **Glow:** Purple pulsing aura + floating particles remain around pet
- **Sound:** Dramatic chord
- **Screen effect:** Purple flash + slight screen shake
- **Duration:** 1.5s

### Legendary (Orange)
- **Particles:** 120 orange/gold circles + 50 stars + energy bolts + confetti
- **Pattern:** Massive radial explosion with 8 light rays + spiraling ring
- **Glow:** Intense gold aura + floating star particles orbit pet permanently
- **Sound:** Epic orchestral hit + crowd cheer
- **Screen effect:** Gold flash + screen shake + brief slow-motion
- **Duration:** 2.0s

### Mythic (Rainbow)
- **Particles:** 200 rainbow cycling circles + 80 stars + energy bolts + fire wisps + confetti
- **Pattern:** Massive spherical explosion → collapses inward → second explosion outward
- **Glow:** Animated rainbow aura + fire particles orbit pet permanently + rainbow trail when walking
- **Sound:** Thunder crack + angelic choir + bass drop
- **Screen effect:** Rainbow flash → brief whiteout → chromatic aberration → slow-motion reveal
- **Text:** "MYTHIC!!!" text with rainbow animated gradient, bouncing in with spring physics
- **Duration:** 3.5s
- **Server announcement:** "{Player} hatched a MYTHIC {PetName}!" chat message with rainbow text

---

## 4. Rebirth Effect

### Trigger
Player activates rebirth at the Rebirth Altar.

### Sequence (3s total)
1. **Charge (0–1s):** Golden energy swirls converge on the player from all directions. Rising pitch sound. Camera pulls back slightly.
2. **Burst (1–1.5s):** Screen-wide golden explosion. Radial light rays. Screen flash to white. All nearby particles blown outward.
3. **Transformation (1.5–2.5s):** Player model glows golden, floats up slightly, then slams back down. Shockwave ring expands outward across the ground. Counter displays new rebirth tier.
4. **Celebration (2.5–3s):** Golden confetti rain. "REBIRTH {N}!" text with fire effect. Stats reset animation (numbers counting down rapidly). New multiplier flashes green.

### Visual Scaling
Each rebirth tier increases the effect intensity:
- Rebirths 1–5: Standard gold effect
- Rebirths 6–10: Gold + silver sparkles, larger burst
- Rebirths 11–20: Gold + platinum, screen shake
- Rebirths 21+: Rainbow gold, maximum particle count, bass-heavy audio

---

## 5. Currency Popup (Floating Numbers)

### Coin Earned
- **Text:** "+{amount}" in bold gold with dark outline
- **Position:** Rises from point of earning (car position during drive)
- **Animation:** Floats upward 50 studs over 1s, slight random X drift
- **Scale:** Starts at 100%, grows to 120%, then shrinks to 80% before fading
- **Opacity:** 100% → 0% over 1s with ease-out
- **Combo multiplier:** If earning rapid coins, numbers stack and combine: "+500" becomes "+1,250" with size boost

### Gem / Crystal Earned
- Same base behavior as coins but:
  - Gems: purple text with purple sparkle particles
  - Crystals: cyan text with ice crystal particles
  - Slightly larger base size (more rare = more exciting)

### Distance Milestone
- When passing a distance marker sign:
- Large text: "{distance} studs!" in white with green glow
- Banner animation: slides in from right, holds 1s, slides out
- Small coin bonus popup simultaneously

---

## 6. Pet Equip / Summon Effect

### Equipping a Pet
- **Duration:** 0.8s
- **Visual:** Small portal/ring appears next to player, rarity-colored. Pet pops out of portal with a bounce. Portal collapses.
- **Particles:** Rarity-colored sparkles spray outward from portal
- **Sound:** Pop + sparkle sound scaled to rarity
- **Post-equip:** Pet begins orbiting player at assigned slot position

### Unequipping a Pet
- **Duration:** 0.5s
- **Visual:** Pet shrinks with a spiral, gets sucked into a small portal, portal closes
- **Sound:** Reverse pop

### Pet Orbit Behavior
- Pets float at head height, orbiting in a circle around the player
- Orbit radius: 4 studs per ring (first ring = 4 studs, second ring = 8 studs if >4 pets)
- Orbit speed: gentle rotation, ~10s per full circle
- Pets bob up and down slightly (0.5 stud amplitude, 2s period)
- Each pet has a faint rarity-colored glow while orbiting
- Mythic pets leave a faint rainbow trail while orbiting

---

## 7. World Transition Effect

### Unlocking a New World
- **Duration:** 2s
- **Visual:** World portal opens with dramatic swirling energy in the new world's color theme. Camera pushes through the portal. New world skybox fades in.
- **Particles:** Theme-colored energy spirals converging toward portal center
- **Sound:** Whoosh + ethereal chime + new world's ambient intro

### Teleporting Between Worlds
- **Duration:** 1s
- **Visual:** Quick zoom effect (camera rushes forward), screen blurs, new world pops in
- **Fade:** 0.3s fade to black → 0.3s hold → 0.4s fade in at new location

---

## 8. Ambient World VFX (Grasslands)

### Environmental Particles
- Floating pollen/dandelion seeds drifting on the wind (very subtle, 10-15 particles visible)
- Butterflies near flower patches (2-3 visible, simple quad billboards)
- Gentle grass sway (vertex animation on grass meshes)
- Distant birds (2D silhouettes crossing sky occasionally)

### Highway Markers
- Distance signs glow briefly as the player passes them
- Small particle burst when crossing a milestone threshold

### Lobby Ambient
- Egg pedestals: gentle glow pulse and slow-rising sparkle particles
- Rebirth altar: smoldering golden embers, faint heat shimmer
- Car showroom: rotating spotlight beams, floor reflection
- Pet shop: cute ambient sounds, pet idle animations visible through windows

---

## Performance Budget

| Effect Category | Max Active Particles | Priority |
|-----------------|---------------------|----------|
| Speed trails | 100 | High (always visible) |
| Currency popups | 30 | High (core feedback) |
| Pet orbit glow | 16 per pet × 8 pets max = 128 | Medium |
| Ambient world | 50 | Low (cull first) |
| Egg hatch | 200 (brief spike) | High (momentary) |
| Rebirth | 300 (brief spike) | High (momentary) |
| Rarity reveal | 50–200 (scales with rarity) | High (momentary) |

**Total steady-state target:** ≤350 particles on screen during driving
**Spike allowance:** ≤500 particles during hatch/rebirth events (lasts <3s)
**Mobile LOD:** Halve particle counts and disable ambient particles on low-end devices
