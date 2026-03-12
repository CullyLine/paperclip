# Branching Dialogue Engine for Roblox

A production-ready branching dialogue system for Roblox, targeting anime RPG, adventure, and horror game developers.

## Features

- **Simple text format** — write dialogue trees in plain text, no code needed
- **Lua tables also supported** — use whichever format you prefer
- **Branching choices** — multiple response options with conditional visibility
- **Condition system** — register callbacks to gate choices on game state
- **Actions & flags** — `[set key value]` and `[call actionName]` tags on nodes and choices to set flags and fire functions directly from dialogue
- **Built-in flag store** — `SetFlag`/`GetFlag` with automatic condition checking and variable interpolation
- **Event hooks** — `onNodeEnter`, `onChoice`, `onEnd` callbacks
- **Typewriter text** — character-by-character reveal with rich text safety (never shows broken tags)
- **Auto speaker & portrait** — speaker name and viewport portrait pulled from the NPC model automatically
- **Close button** — dismiss the dialogue from any node via UI button, Escape, or gamepad B
- **Theme system** — full visual customization without editing source
- **Keyboard shortcuts** — press 1-4 to select choices, arrow keys to navigate, Escape to close
- **Gamepad support** — D-pad navigation, A to select, B to close
- **ProximityPrompt integration** — modern NPC interaction (replaces deprecated ClickDetector)
- **Voice/sound playback** — per-node voice lines with automatic cleanup
- **Save/Load state** — persist and resume dialogue progress across sessions
- **Smooth animations** — TweenService-powered open/close/choice-button transitions
- **Auto-advance nodes** — timed auto-advance for cutscenes and narrative sequences
- **UI sound effects** — configurable sounds for open, close, typewriter, choice hover/select
- **Variable interpolation** — `{playerName}` syntax in dialogue text, resolved from registered callbacks
- **Inline text control** — `[pause N]` and `[speed N]` tags for dramatic pacing mid-sentence
- **Visual Designer** — Roblox Studio plugin with drag-and-drop node editor, no coding required

## File Structure

```
DialogueEngine/
├── DialogueEngine.lua    -- Main facade (require this)
├── DialogueRunner.lua    -- Tree processor, conditions, branching
├── DialogueUI.lua        -- ScreenGui, typewriter, input handling
├── DialogueParser.lua    -- Simple text format → tree table converter
├── Theme.lua             -- Default theme + merge utility
├── Types.lua             -- Type definitions
├── build-model.cjs       -- Builds DialogueEngine.rbxmx from the Lua sources
├── DialogueEngine.rbxmx  -- Pre-built Roblox Model (insert into ReplicatedStorage)
├── README.md             -- This file
├── Example/
│   └── ExampleUsage.local.luau  -- Standalone 4-NPC integration example
├── TemplatePlace/        -- Full demo village with 7 NPCs showcasing all features
│   ├── TestDemoLevelHere.server.luau  -- Builds Thornwood Village environment
│   ├── TemplateSetup.local.luau  -- 7-NPC dialogue trees + engine setup
│   └── README.md         -- Setup guide
└── Designer/             -- Visual node-graph editor (Roblox Studio plugin)
    ├── Plugin.server.lua -- Plugin entry point
    ├── Canvas.lua        -- Pannable canvas with grid + drag handling
    ├── NodeWidget.lua    -- Draggable node cards
    ├── ConnectionRenderer.lua -- Lines between nodes
    ├── PropertyPanel.lua -- Right-side node property editor
    ├── Toolbar.lua       -- Import/Export/Save/Undo/Redo
    ├── Serializer.lua    -- Bidirectional text format conversion
    ├── AppState.lua      -- State management with undo/redo
    ├── DesignerTheme.lua -- Plugin UI styling
    ├── build-rbxmx.cjs   -- Builds DialogueDesigner.rbxmx
    └── INSTALL.md        -- Setup instructions
```

## Quick Start

### 1. Install

**Option A — Roblox Model (recommended):**
Insert the **DialogueEngine** model into `ReplicatedStorage` from the Toolbox, or drag `DialogueEngine.rbxmx` directly into Studio. The model includes a `Demo/` folder with ready-to-run example scripts.

**Option B — Manual:**
Place the `DialogueEngine` folder in `ReplicatedStorage` with the 6 ModuleScripts inside it.

**Optional companion:** Install the **Dialogue Designer** plugin for a visual node-graph editor — search "DialogueDesigner" in the Plugin Marketplace or build from `Designer/build-rbxmx.cjs`.

**Included in the model under `Demo/`:**
| Script | What It Does |
|--------|-------------|
| `VerySimpleExampleDialog` | Beginner-friendly — 6 tiny standalone examples teaching one concept each |
| `MoreExampleDialog` | Intermediate — 4 NPCs with conditions, flags, quests, rich text |
| `TestDemoExampleDialog` | Full 7-NPC village dialogue setup for the Thornwood Village demo |
| `TestDemoLevelHere` | Paste into Command Bar to build Thornwood Village in your place |

### 2. Write a Dialogue Tree (Simple Text Format)

```
=== my_npc
start: greeting

# greeting
Welcome, young hero! What brings you here?
> Tell me about the quest. -> quest_info
> Goodbye. -> bye

# quest_info [end]
The dragon threatens our lands... Please help us!

# bye [end]
Safe travels!
```

### 3. Use It

```lua
local DialogueEngine = require(ReplicatedStorage.DialogueEngine.DialogueEngine)
local DialogueParser = require(ReplicatedStorage.DialogueEngine.DialogueParser)

local myTree = DialogueParser.Parse([[
=== my_npc
start: greeting

# greeting
Welcome! What brings you here?
> Tell me about the quest. -> quest_info
> Goodbye. -> bye

# quest_info [end]
The dragon threatens our lands...

# bye [end]
Safe travels!
]])

local engine = DialogueEngine.new()
engine:RegisterTree("my_npc", myTree)

-- npc is the Model the player interacted with
-- Speaker name and viewport portrait are grabbed from it automatically
engine:Start("my_npc", npc, {
    onEnd = function()
        print("Dialogue finished")
    end,
})
```

## Text Format Reference

```
=== tree_id                          -- Name your dialogue tree
start: node_name                     -- Which node to start at

# node_name                          -- Start a new node
# node_name [end]                    -- Start a new node that ends the conversation
# node_name [auto 3]                 -- Auto-advance after typewriter + 3 seconds

Just write your dialogue text here.
Multiple lines get joined together.
Use {variableName} for dynamic values.

@ Speaker Name                       -- Override the speaker (otherwise uses NPC model name)

> Choice text -> target_node                          -- A choice
> Buy for {price} gold -> buy [if gold 500]           -- Variables work in choices too
> Hidden choice -> target [if hasKey true] [hide]      -- Hidden when condition not met

Hello...[pause 1] dramatic pause!    -- Pauses typewriter mid-sentence
[speed 0.08]Slow spooky text...      -- Changes typewriter speed
-- This is a comment (ignored)
```

### Line Types

| Prefix | What it does |
|---|---|
| `=== name` | Sets the tree's ID |
| `start: name` | Sets the starting node |
| `# name` | Starts a new node |
| `# name [end]` | Starts an end node (conversation stops here) |
| `# name [auto N]` | Auto-advances after typewriter + N seconds (no-choice nodes only) |
| `@ Name` | Overrides the speaker name for this node |
| `> text -> target` | Adds a choice pointing to another node |
| `[if key value]` | Condition tag on a choice (e.g. `[if gold 500]`) |
| `[hide]` | Hides the choice when condition isn't met (instead of greying out) |
| `[set key value]` | Sets a flag when the node is entered or choice is clicked |
| `[call name]` | Fires a registered action when the node is entered or choice is clicked |
| `{varName}` | Variable — replaced at runtime with value from `RegisterVariable` |
| `[pause N]` | Pauses the typewriter for N seconds mid-sentence |
| `[speed N]` | Changes typewriter speed to N seconds per character from this point |
| `-- text` | Comment (ignored) |
| anything else | Dialogue text |

## Lua Table Format (Advanced)

You can also define trees as Lua tables directly if you prefer:

```lua
local myTree = {
    id = "npc_greeting",
    startNodeId = "hello",
    nodes = {
        hello = {
            text = "Welcome, young hero!",
            choices = {
                {
                    text = "Tell me about the quest.",
                    targetNodeId = "quest_info",
                },
                {
                    text = "Goodbye.",
                    targetNodeId = "bye",
                },
            },
        },
        quest_info = {
            text = "The dragon threatens our lands...",
            isEndNode = true,
        },
        bye = {
            text = "Safe travels!",
            isEndNode = true,
        },
    },
}
```

Optional fields on nodes: `speaker` (overrides NPC name), `portraitImageId`, `npcModel` (overrides the model passed to Start), `voiceSoundId`, `isEndNode`, `autoAdvanceDelay` (seconds, auto-advance after typewriter finishes), `actions` (array of `{type, key, value}` — set flags or call registered actions when the node is entered).

Optional fields on choices: `conditions`, `hideWhenUnavailable`, `actions` (same format — fired when the choice is clicked).

## Conditions

Gate choices behind game state using condition callbacks:

```lua
engine:RegisterCondition(function(key, value)
    if key == "hasItem" then
        return PlayerInventory:HasItem(value)
    elseif key == "level" then
        return PlayerData.Level >= value
    end
    return false
end)
```

In the simple text format:
```
> Show me the ancient sword. -> ancient_sword [if hasItem dragonScale]
> Secret option -> secret [if level 10] [hide]
```

In Lua table format:
```lua
{
    text = "Show me the ancient sword.",
    targetNodeId = "ancient_sword",
    conditions = { hasItem = "dragonScale" },
    hideWhenUnavailable = false, -- false = greyed out, true = hidden
}
```

## Actions & Flags

Fire functions and set flags directly from dialogue — no external if/else chains needed.

### Built-in Flag Store

The engine has a built-in key-value flag store that conditions automatically check:

```lua
engine:SetFlag("gold", 1000)
engine:SetFlag("hasKey", false)

-- Read flags back
local gold = engine:GetFlag("gold")

-- Flags are also available as variables: {gold} in dialogue text resolves automatically
```

### Setting Flags from Dialogue

Use `[set key value]` on nodes (fires when entered) or choices (fires when clicked):

```
# quest_accepted [set acceptedQuest true]
Great! Talk to the elder in the village.
> On my way! -> farewell [set gold 500]
```

In Lua table format:

```lua
{
    text = "Great! Talk to the elder.",
    isEndNode = true,
    actions = {
        { type = "set", key = "acceptedQuest", value = true },
    },
    choices = {
        {
            text = "On my way!",
            targetNodeId = "farewell",
            actions = {
                { type = "set", key = "gold", value = 500 },
            },
        },
    },
}
```

### Calling Functions from Dialogue

Register named actions, then trigger them with `[call name]`:

```lua
engine:RegisterAction("playCashSound", function()
    SoundService.CashRegister:Play()
end)

engine:RegisterAction("startCutscene", function()
    CutsceneManager:Play("intro")
end)

engine:RegisterAction("giveReward", function()
    local gold = engine:GetFlag("gold") or 0
    engine:SetFlag("gold", gold + 200)
    PlayerInventory:AddItem("DragonScale")
end)
```

Then in dialogue:

```
# bought_sword [end] [set hasSword true] [call playCashSound]
Enjoy your new sword!

> Accept the quest -> quest_start [set questActive true] [call startCutscene]
```

### Quest Example (Cross-NPC)

Elon asks you to deliver a message to Helper Bot. The choice only appears once you've talked to Helper Bot:

```
-- In Elon's tree:
# greeting
Hey, do me a favor? Go talk to Helper Bot.
> Sure! -> errand_accepted [set errandActive true] [call showQuestMarker]
> I already did! -> errand_complete [if talkedToBot true]

-- In Helper Bot's tree:
# greeting
> Elon sent me. -> elon_errand [if errandActive true]

# elon_errand [set talkedToBot true]
Tell Elon everything's green!

-- Back in Elon's tree:
# errand_complete [end] [call giveReward]
You did it! Here's your reward.
```

## Theming

Override any theme property:

```lua
local engine = DialogueEngine.new({
    backgroundColor = Color3.fromRGB(30, 0, 0),
    speakerColor = Color3.fromRGB(255, 100, 100),
    typewriterSpeed = 0.02,
    voiceVolume = 0.8,
    choiceHighlightColor = Color3.fromRGB(100, 50, 50),
})
```

Or change at runtime:

```lua
engine:SetTheme({ typewriterSpeed = 0.01 })
```

### Theme Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `backgroundColor` | Color3 | `(15, 15, 25)` | Dialogue box background |
| `backgroundTransparency` | number | `0.15` | Background transparency |
| `textColor` | Color3 | `(230, 230, 240)` | Main dialogue text |
| `speakerColor` | Color3 | `(255, 200, 80)` | Speaker name color |
| `choiceColor` | Color3 | `(35, 35, 55)` | Choice button normal |
| `choiceHoverColor` | Color3 | `(60, 60, 100)` | Choice button hover |
| `choiceHighlightColor` | Color3 | `(80, 80, 140)` | Keyboard/gamepad highlight |
| `choiceTextColor` | Color3 | `(200, 200, 220)` | Choice button text |
| `choiceUnavailableColor` | Color3 | `(80, 80, 80)` | Greyed-out choices |
| `font` | Enum.Font | `GothamMedium` | Body text font |
| `speakerFont` | Enum.Font | `GothamBold` | Speaker name font |
| `textSize` | number | `18` | Body text size |
| `speakerTextSize` | number | `20` | Speaker name size |
| `choiceTextSize` | number | `16` | Choice button text size |
| `cornerRadius` | UDim | `(0, 8)` | UI corner rounding |
| `typewriterSpeed` | number | `0.03` | Seconds per character |
| `voiceVolume` | number | `1` | Voice line volume (0-1) |
| `animationSpeed` | number | `1` | Animation speed multiplier (0 = disable animations) |
| `sfxVolume` | number | `1` | UI sound effects volume (0-1) |
| `openSoundId` | string? | `nil` | Sound played when dialogue opens |
| `closeSoundId` | string? | `nil` | Sound played when dialogue closes |
| `typewriterSoundId` | string? | `nil` | Sound played per character during typewriter |
| `typewriterSoundPitch` | number | `0.1` | Random pitch variation range for typewriter sound |
| `choiceHoverSoundId` | string? | `nil` | Sound played when hovering/highlighting a choice |
| `choiceSelectSoundId` | string? | `nil` | Sound played when selecting a choice |

## Auto-Advance Nodes

For cutscenes and narrative sequences, nodes can automatically advance without player input:

### Text Format
```
# narration_1 [auto 3]
The camera pans across the battlefield...

# narration_2 [auto 2]
A lone figure emerges from the smoke.

# narration_3 [end]
The warrior speaks: "It's over."
```

### Lua Table Format
```lua
narration_1 = {
    text = "The camera pans across the battlefield...",
    autoAdvanceDelay = 3, -- seconds after typewriter finishes
},
```

Auto-advance is ignored on nodes that have choices. Players can still click/tap/press to advance immediately.

## Animations

The dialogue box uses smooth TweenService animations:

- **Open:** slides up + fades in + slight scale pop (0.3s)
- **Close:** fades out + slides down (0.2s)
- **Choice buttons:** stagger-animate in from the right (0.05s between each)

Control animation speed via the `animationSpeed` theme property:

```lua
local engine = DialogueEngine.new({
    animationSpeed = 1.5,  -- faster animations
})

-- Or disable animations entirely:
local engine = DialogueEngine.new({
    animationSpeed = 0,
})
```

## Variable Interpolation

Insert dynamic runtime values into dialogue text using `{variableName}`:

```
# shopkeeper_greeting
Hello, {playerName}! You have {gold} gold. What would you like to buy?
> Buy sword (500g) -> buy_sword [if gold 500]
```

Register a resolver to provide values:

```lua
engine:RegisterVariable(function(varName)
    if varName == "playerName" then return player.Name end
    if varName == "gold" then return PlayerData.Gold end
    if varName == "questName" then return CurrentQuest.Name end
    return nil -- unresolved variables stay as {varName}
end)
```

Variables are resolved at display time, so they always reflect the current game state. Multiple resolvers can be registered — the first one to return a non-nil value wins. Variables also work in choice text.

## Inline Text Control

Add dramatic pacing to dialogue with `[pause N]` and `[speed N]` tags:

```
# dramatic_reveal
The door opens slowly...[pause 1] and behind it...[pause 2]
[speed 0.08]Nothing. Absolutely nothing.[pause 0.5]
[speed 0.01]JUST KIDDING! A DRAGON!
```

| Tag | Effect |
|---|---|
| `[pause N]` | Pauses the typewriter for N seconds at that point |
| `[speed N]` | Changes typewriter speed to N seconds per character for the rest of the text |

These tags are stripped from the displayed text. Players can still skip through pauses by clicking/tapping. Speed resets to the theme default on each new node.

## Sound Effects

Add UI sounds via theme configuration. All are optional — if nil or empty, no sound plays:

```lua
local engine = DialogueEngine.new({
    openSoundId = "rbxassetid://123456",
    closeSoundId = "rbxassetid://123457",
    typewriterSoundId = "rbxassetid://123458",
    typewriterSoundPitch = 0.15,
    choiceHoverSoundId = "rbxassetid://123459",
    choiceSelectSoundId = "rbxassetid://123460",
    sfxVolume = 0.8,
})
```

The typewriter sound uses a pool of 3 Sound instances to avoid cutting itself off during rapid-fire playback.

## Input Controls

### Keyboard
- **1-4**: Instantly select choice by number
- **Up/W, Down/S**: Navigate highlight between choices
- **Enter/Space**: Confirm highlighted choice or skip typewriter
- **Escape**: Close dialogue immediately
- **Click/Tap**: Skip typewriter animation

### Gamepad
- **D-Pad Up/Down**: Navigate choices
- **A Button**: Confirm choice or skip typewriter
- **B Button**: Close dialogue (skips typewriter first if animating)

## Save & Load State

Persist dialogue progress for cross-session continuity:

```lua
-- Save current state
local state = engine:SaveState("npc_greeting")
-- state = { treeId, currentNodeId, visitedNodes, timestamp }

-- Store `state` in DataStore (you manage the DataStore)

-- Later, resume from saved state (npc is the NPC model)
engine:StartFromState("npc_greeting", savedState, npc, callbacks)

-- Check which nodes the player has visited
local visited = engine:GetVisitedNodes("npc_greeting")
if visited["secret_room"] then
    -- Player has seen the secret room dialogue
end
```

## API Reference

### DialogueEngine

| Method | Description |
|---|---|
| `DialogueEngine.new(themeOverrides?)` | Create new engine instance |
| `:RegisterTree(treeId, data)` | Register a dialogue tree (Lua table or parsed text) |
| `:RegisterCondition(callback)` | Add condition evaluator |
| `:RegisterVariable(resolver)` | Add variable resolver for `{varName}` interpolation |
| `:Start(treeId, npcModel?, callbacks?)` | Start dialogue (model is optional, provides speaker name + viewport portrait) |
| `:StartFromState(treeId, state, npcModel?, callbacks?)` | Resume from saved state |
| `:Skip()` | Skip typewriter animation |
| `:Close()` | Close dialogue UI |
| `:SetTheme(overrides)` | Update theme at runtime |
| `:SaveState(treeId?)` | Get serializable state table |
| `:LoadState(treeId, state)` | Load state without starting UI |
| `:GetVisitedNodes(treeId)` | Get visited node set |
| `:Destroy()` | Clean up all resources |

### DialogueParser

| Method | Description |
|---|---|
| `DialogueParser.Parse(source)` | Convert a text-format string into a dialogue tree table |

### Callbacks

```lua
{
    onNodeEnter = function(nodeId) end,
    onChoice = function(nodeId, choiceIndex) end,
    onEnd = function() end,
}
```

## License

MIT
