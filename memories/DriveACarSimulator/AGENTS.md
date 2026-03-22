# Drive a Car Simulator — Agent Guidelines

## UI Convention: Pre-Built Instances

**All static UI must be pre-built as Instances in `StarterGui`, not generated at runtime by scripts.**

### Why

Runtime-generated UI is invisible in Roblox Studio's visual editor. Pre-built UI lets the developer (and AI) visually tweak layouts, colors, sizes, and hierarchy directly in Studio without reading code.

### Rule

| Element type | Where it lives | How scripts access it |
|---|---|---|
| Static shells (root frames, title bars, scroll containers) | Pre-built under `StarterGui.DACMain` | `sg:WaitForChild("PanelRoot")` |
| Static labels, buttons, progress bars | Pre-built as children of the shell | `root:WaitForChild("ClaimBtn")` |
| Layout objects (UIListLayout, UIGridLayout, UICorner, UIStroke) | Pre-built inside their parent | Already present; scripts find via `FindFirstChildOfClass` if needed |
| Data-driven rows (pet cards, leaderboard entries, store items) | Created at runtime with `Instance.new` | Parented to the pre-built scroll container |
| Ephemeral effects (flash text, celebration overlays, sparkles) | Created at runtime with `Instance.new` | Destroyed after animation completes |

### Building pre-built UI

Use the Roblox Studio MCP `execute_luau` tool to create Instance hierarchies under `game.StarterGui.DACMain`. Then update the corresponding script with `set_script_source` to reference those instances via `WaitForChild()` instead of `Instance.new()`.

### Pattern

```lua
-- CORRECT
function MyPanel.init()
    local sg = MenuHub.getScreenGui()
    local root = sg:WaitForChild("MyRoot") :: Frame
    MenuHub.registerPanel("mypanel", root)
    local titleBar = root:WaitForChild("TitleBar") :: Frame
    titleBar:WaitForChild("Close").MouseButton1Click:Connect(function()
        root.Visible = false
    end)
    local scroll = root:WaitForChild("Scroll") :: ScrollingFrame
    -- dynamic content still uses Instance.new
    for _, item in items do
        local row = Instance.new("Frame"); row.Parent = scroll
    end
end
```

```lua
-- WRONG — do not generate static UI at runtime
function MyPanel.init()
    local sg = MenuHub.getScreenGui()
    local root = Instance.new("Frame")
    root.Name = "MyRoot"
    root.Parent = sg
end
```

## Visual Design Guide

**The Pets Inventory panel is the canonical reference.** See `DAC/Inventory Pets.PNG`. All other panels in `DAC/*.PNG` also demonstrate the style. Study them before creating or modifying any UI.

### Panel anatomy (every panel must follow this)

1. **Tab bar** (if multi-tab) — White pill container centered above the panel with dark silhouette icons.
2. **Title** — Floats *outside* the panel frame, above-left. Colorful icon + bold white GothamBlack text with dark TextStroke.
3. **Close button** — Bright red rounded square (`#FF2222`), white ✕, top-right corner.
4. **Panel body** — Pastel pink (`#FFD6EE`) to lavender (`#E0D6FF`) background with subtle watermark pattern (faded silhouettes). Thick dark border (2-3px charcoal `#2A2A40`). Large corner radius (14px+).
5. **Content area** — Scrollable grid or list inside the body.
6. **Bottom bar** (optional) — Action buttons + filter icons + search.

### Colors

- Positive actions: Emerald green `#2ECC71` (Equip, Claim, Rebirth)
- Negative/off: Red `#FF4444` (No Pets, disabled toggles)
- Title text: White with black TextStroke
- Body text: Dark `#1E1E1E` on light backgrounds
- Section headers: Gray rounded bars with bold dark text

### Shape language

- Everything rounded and chunky — no thin lines, sharp corners, or minimal design
- Panel corners `14px`, button corners `8px`, card corners `8px`
- Tab bars fully rounded (pill shape)
- Bold, bubbly, saturated — standard Roblox simulator aesthetic

### Typography

- **GothamBlack** — panel titles, major headers
- **GothamBold** — buttons, labels, card text
- **Gotham** — secondary text only
- Never thin/light/serif fonts. Always high contrast and large sizes.

### What NOT to do

- Do not use dark/navy panel body backgrounds
- Do not put titles inside the panel frame
- Do not use flat/minimal/Material Design
- Do not make small cramped text — everything big, bold, bubbly

## Other Conventions

- Read `README.md` for game design, project structure, and Rojo setup.
- Read `STUDIO_TEMPLATES.md` for model naming conventions.
- All scripts use `--!strict` mode.
- Sound effects go through `SoundFacade`, visual effects through `VFXFacade`.
- Panel registration uses `MenuHub.registerPanel()` (or `uiController.registerPanel()` for TrophyCasePanel).
