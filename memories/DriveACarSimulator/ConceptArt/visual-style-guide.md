# Drive a Car Simulator — Visual Style Guide

## Art Direction Summary

**Core aesthetic:** Low-poly, vibrant, hyper-saturated cartoon. Pet Simulator X meets arcade racing.
**Target mood:** Bright, energetic, irresistible to tap. Every screen should look like a party.
**Design philosophy:** Visual clarity first — every element must read instantly at mobile resolution on Roblox's discovery feed thumbnails.

---

## 1. Color Palette

### Primary Palette
| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Sky Blue | Bright cheerful blue | `#4FC3F7` | Backgrounds, sky, calm surfaces |
| Grass Green | Vivid saturated green | `#66BB6A` | Grasslands world, confirm/go buttons |
| Coin Gold | Warm rich gold | `#FFD54F` | Coins, premium highlights, rewards |
| Alert Red | Bright warm red | `#EF5350` | Low fuel, danger, urgency |

### Secondary Palette
| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Gem Purple | Deep royal purple | `#AB47BC` | Gems currency, rare elements |
| Crystal Blue | Electric cyan | `#29B6F6` | Crystals currency, speed effects |
| Skull Magenta | Hot pink-magenta | `#EC407A` | Skulls currency, rebirth elements |
| Cloud White | Soft white | `#F5F5F5` | Text, clean surfaces |

### Rarity Colors (Pets & Items)
| Rarity | Color | Hex | Glow Intensity |
|--------|-------|-----|----------------|
| Common | White/Light Gray | `#E0E0E0` | None |
| Uncommon | Soft Green | `#81C784` | Subtle |
| Rare | Sky Blue | `#42A5F5` | Moderate |
| Epic | Rich Purple | `#AB47BC` | Strong |
| Legendary | Bright Orange | `#FFA726` | Intense |
| Mythic | Rainbow Gradient | `#FF4081→#FFD740→#69F0AE→#40C4FF→#E040FB` | Maximum (animated) |

### World Color Themes
| World | Primary | Secondary | Accent | Sky |
|-------|---------|-----------|--------|-----|
| Grasslands | `#66BB6A` green | `#8D6E63` brown | `#FFD54F` gold | `#4FC3F7` blue |
| Scorching Desert | `#FFB74D` orange | `#A1887F` tan | `#FF7043` red | `#FFF176` pale yellow |
| Frozen Tundra | `#B3E5FC` ice blue | `#E0E0E0` white | `#80DEEA` cyan | `#90CAF9` pale blue |
| Neon City | `#E040FB` magenta | `#40C4FF` electric blue | `#76FF03` neon green | `#311B92` deep indigo |

---

## 2. Typography Direction

### Font Style
- **Primary:** Bold, rounded sans-serif (Fredoka One, Nunito Bold, or GothamRounded Bold)
- **Numbers:** Extra-bold weight for currency/stats — must pop
- **Body:** Medium weight rounded sans-serif, high x-height for mobile readability

### Size Hierarchy (relative to screen)
| Element | Relative Size | Weight |
|---------|---------------|--------|
| Currency counters | XL | Extra Bold |
| Button labels | L | Bold |
| Panel titles | L | Bold |
| Item names | M | Semi-Bold |
| Descriptions | S | Regular |
| Tooltips | XS | Regular |

### Text Styling Rules
- White text with dark drop shadow (2px offset, 50% opacity black) on all gameplay text
- Colored text for emphasis: gold for premium, green for positive, red for negative
- Never use thin/light weights — everything must be readable on low-res mobile screens
- Letter spacing: slightly expanded (+2%) on button labels for clarity

---

## 3. Button Styles

### Primary Action Buttons (DRIVE, BUY, HATCH)
- Rounded rectangle with 12px corner radius (at 1920 reference)
- Vertical gradient fill: lighter shade on top → saturated shade on bottom
- 3px darker border matching the gradient's bottom color
- Subtle inner glow (white, top edge, 20% opacity)
- Drop shadow: 4px offset, 30% opacity, matching hue
- **Press state:** darken 15%, compress 2px vertically
- **Hover state:** brighten 10%, grow 2px

### Color Variants
| Action | Top Gradient | Bottom Gradient | Usage |
|--------|-------------|-----------------|-------|
| Primary / Go | `#81C784` | `#43A047` | Drive, Confirm, Equip |
| Purchase (Coins) | `#FFD54F` | `#F9A825` | Buy with coins |
| Purchase (Gems) | `#CE93D8` | `#8E24AA` | Buy with gems |
| Purchase (Crystals) | `#4FC3F7` | `#0288D1` | Buy with crystals |
| Special / Rebirth | `#FF8A65` | `#E64A19` | Rebirth, special actions |
| Close / Cancel | `#EF9A9A` | `#C62828` | Close, cancel, back |
| Navigation | `#90CAF9` | `#1565C0` | Tabs, menu items |

### Icon Buttons (small, circular)
- Circle shape, solid fill, white icon centered
- Same gradient and shadow treatment as rectangles but circular
- Used for: close (X), settings (gear), info (i)

---

## 4. Panel & Card Styles

### Main Panels (Shop, Inventory, Pets)
- Dark semi-transparent background: `rgba(20, 20, 40, 0.85)`
- Rounded corners: 16px
- Subtle colored border: 2px, matching panel theme color at 60% opacity
- Inner padding: 16px
- Drop shadow: 8px blur, 30% opacity black

### Item Cards (Pet cards, car cards, egg cards)
- White or light gray background: `#F5F5F5`
- Rounded corners: 8px
- Colored top border strip: 4px height, rarity color
- Content: centered icon/image (60% of card height), name below, stats/price at bottom
- **Equipped state:** pulsing glow border in rarity color
- **Hover state:** slight scale up (105%), brighter border

### Rarity Card Borders
Each rarity tier has a distinct border treatment:
- **Common:** 2px solid `#E0E0E0` — no glow
- **Uncommon:** 2px solid `#81C784` — faint green glow
- **Rare:** 2px solid `#42A5F5` — moderate blue glow
- **Epic:** 3px solid `#AB47BC` — purple glow + subtle sparkle particles
- **Legendary:** 3px solid `#FFA726` — orange glow + star particles
- **Mythic:** 3px animated rainbow gradient border — intense rainbow glow + fire particles

---

## 5. Currency Icons

### Coins
- Shape: Classic gold coin, slightly 3D with bevel
- Color: Bright gold `#FFD54F` face, darker gold `#F9A825` edge
- Detail: "$" or star embossed in center
- Size: 24x24 reference, scales with UI

### Gems
- Shape: Cut diamond / hexagonal gem viewed from top
- Color: Deep purple `#AB47BC` with white highlight facets
- Detail: Inner glow, light refraction lines
- Size: 24x24 reference

### Crystals
- Shape: Elongated hexagonal crystal cluster
- Color: Electric cyan `#29B6F6` with white sparkle
- Detail: Transparent with inner glow, geometric facets
- Size: 24x24 reference

### Skulls (Rebirth currency)
- Shape: Cute rounded skull face
- Color: Hot pink/magenta `#EC407A` with white eyes
- Detail: Cartoonish, not scary — small heart-shaped eye sockets
- Size: 24x24 reference

---

## 6. HUD Layout

### Gas Bar (Top Center)
- Horizontal bar, rounded ends, 300px wide x 24px tall (reference)
- Gradient fill from left to right: `#42A5F5` (blue/full) → `#EF5350` (red/empty)
- The fill percentage reflects remaining fuel
- White border 2px, drop shadow
- Small car silhouette icon at left end
- Numeric percentage at right end (white, bold)

### Currency Display (Top Right)
- Vertical stack of currency rows, right-aligned
- Each row: [icon 20x20] [amount in bold white with shadow]
- Background: subtle dark pill shape `rgba(0,0,0,0.4)` behind each row
- Coins on top, then Gems, then Crystals, then Skulls (if applicable)

### Speed Display (Bottom Left)
- Large bold number showing current speed
- "mph" or "studs/s" label below in smaller text
- Subtle speedometer arc graphic behind the number
- Color shifts from white → yellow → orange → red as speed increases

### Action Buttons (Bottom Center)
- Row of circular icon buttons for quick actions
- Boost, Jump, Horn — each with distinct icon and color

---

## 7. Gradient & Glow Patterns

### The "Simulator Glow" Effect
The hallmark of Roblox simulator UI — apply liberally:
- **Button glow:** Soft colored glow extending 4-8px beyond button edges, matching button color at 30% opacity
- **Rarity glow:** Surrounding items, intensity scales with rarity (none for common, intense for mythic)
- **Notification glow:** Pulsing glow on elements that need attention (new items, available upgrades)
- **Selection glow:** Bright white or gold glow on currently selected/hovered items

### Gradient Applications
- **Panel headers:** Left-to-right gradient matching panel theme
- **Button fills:** Top-to-bottom gradient (lighter top, saturated bottom)
- **Background accents:** Radial gradients behind key elements (shop items, featured content)
- **Progress bars:** Multi-color gradient showing progression

### Particle Sparkles
- Small 4-pointed star particles on premium/rare elements
- Rise slowly upward, fade out, respawn
- Color matches the element's accent color
- Density: sparse for uncommon, dense for mythic

---

## 8. Thumbnail & Marketing Screenshots

### Composition Rules
- Character/car in center-left, large and close
- Bright explosion of color/particles behind
- Key UI elements visible but not cluttering
- "NEW" or "UPDATE" badge in top-right corner (red burst with white text)
- Title text: ultra-bold, white with colored outline and strong shadow
- Minimum 3 eye-catching elements per thumbnail (car + pet + egg, etc.)

### Screenshot Color Boosting
- Increase saturation 15-20% beyond in-game values for marketing materials
- Add a subtle vignette (dark edges)
- Boost highlights and contrast
- The discovery feed compresses images — over-saturate to compensate
