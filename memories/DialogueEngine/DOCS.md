# Branching Dialogue Engine — Complete Documentation

**Version:** 1.0  
**For:** Roblox developers making RPGs, adventure games, and horror experiences

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Text Format Reference](#2-text-format-reference)
3. [Lua Table Format](#3-lua-table-format)
4. [Theming Guide](#4-theming-guide)
5. [Conditions & Events](#5-conditions--events)
6. [Portraits](#6-portraits)
7. [Input Controls](#7-input-controls)
8. [Save / Load State](#8-save--load-state)
9. [Variable Interpolation](#9-variable-interpolation)
10. [Inline Text Control](#10-inline-text-control)
11. [API Reference](#11-api-reference)
12. [FAQ / Troubleshooting](#12-faq--troubleshooting)
13. [Changelog](#13-changelog)

---

## 1. Quick Start

This section gets you from zero to a working dialogue in about five minutes.

### Step 1 — Install

Place the `DialogueEngine` folder inside `ReplicatedStorage` in Roblox Studio. Your Explorer should look like this:

```
ReplicatedStorage
└── DialogueEngine
    ├── DialogueEngine.lua
    ├── DialogueParser.lua
    ├── DialogueRunner.lua
    ├── DialogueUI.lua
    ├── Theme.lua
    └── Types.lua
```

### Step 2 — Create a LocalScript

Create a **LocalScript** in `StarterPlayerScripts`. All dialogue runs on the client.

### Step 3 — Write Your First Dialogue Tree (Text Format)

Paste this into your LocalScript:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueEngine = require(ReplicatedStorage.DialogueEngine.DialogueEngine)
local DialogueParser = require(ReplicatedStorage.DialogueEngine.DialogueParser)

-- Write the dialogue tree as plain text
local myTree = DialogueParser.Parse([[
=== shopkeeper
start: greeting

# greeting
Hello there, traveler! What can I do for you?
> Tell me about this town. -> town_info
> Do you have any supplies? -> supplies
> Goodbye! -> farewell

# town_info
This town has stood for 300 years. The old ruins to the east are worth exploring.
> Thanks for the info. -> farewell

# supplies
I've got potions and rope. Take what you need — the dungeon ahead is rough.
> I'll take a look. -> farewell

# farewell [end]
Safe travels! Come back if you need anything.
]])

-- Create the engine and register your tree
local engine = DialogueEngine.new()
engine:RegisterTree("shopkeeper", myTree)
```

### Step 4 — Start the Dialogue

When the player interacts with an NPC (via ProximityPrompt, click, etc.), call:

```lua
-- npc = the NPC Model in Workspace
-- The engine automatically reads the NPC's name and builds a portrait from it
engine:Start("shopkeeper", npc, {
    onEnd = function()
        print("Conversation ended!")
    end,
})
```

If you don't have an NPC model yet, you can omit it entirely:

```lua
engine:Start("shopkeeper", {
    onEnd = function()
        print("Done!")
    end,
})
```

### Step 5 — Hook Up a ProximityPrompt

Here's a complete real-world setup with a ProximityPrompt:

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueEngine = require(ReplicatedStorage.DialogueEngine.DialogueEngine)
local DialogueParser = require(ReplicatedStorage.DialogueEngine.DialogueParser)

local engine = DialogueEngine.new()

local shopkeeperTree = DialogueParser.Parse([[
=== shopkeeper
start: greeting

# greeting
Welcome to my shop!
> Browse items -> browse
> Goodbye -> bye

# browse [end]
Here are my finest wares. Come back anytime!

# bye [end]
Farewell, traveler!
]])

engine:RegisterTree("shopkeeper", shopkeeperTree)

-- Find the NPC in Workspace
local npc = workspace:WaitForChild("Shopkeeper")
local head = npc:FindFirstChild("Head")

-- Add a ProximityPrompt
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Talk"
prompt.ObjectText = npc.Name
prompt.MaxActivationDistance = 8
prompt.Parent = head

-- Trigger dialogue when player walks up
prompt.Triggered:Connect(function(player)
    if player == Players.LocalPlayer then
        engine:Start("shopkeeper", npc)
    end
end)
```

That's it — you're done! The engine handles all the UI, typewriter animation, choice buttons, keyboard/gamepad input, and portrait display automatically.

---

## 2. Text Format Reference

The text format is the easiest way to write dialogue trees. It's plain text with a few special symbols — no Lua knowledge required for the actual content.

### Basic Structure

```
=== tree_id
start: first_node_name

# first_node_name
Your dialogue text goes here.
> Choice one -> another_node
> Choice two -> yet_another_node

# another_node [end]
End of this path.

# yet_another_node
More dialogue here.
> Go back -> first_node_name
```

### Every Line Type Explained

| Line starts with | What it does | Example |
|---|---|---|
| `=== name` | Sets the tree's ID | `=== village_elder` |
| `start: name` | Which node to begin at | `start: greeting` |
| `# name` | Starts a new node | `# greeting` |
| `# name [end]` | Node that ends the conversation | `# farewell [end]` |
| `@ Name` | Overrides the speaker name for this node | `@ The Ancient One` |
| `> text -> target` | A choice button pointing to a node | `> Yes, I'll go. -> accept` |
| `[if key value]` | Condition tag on a choice | `> Enter -> door [if hasKey true]` |
| `[hide]` | Hides choice when condition fails (instead of greying out) | `> Secret path -> hidden [if rank 5] [hide]` |
| `{varName}` | Variable placeholder — replaced at runtime via `RegisterVariable` | `Hello, {playerName}! You have {gold} gold.` |
| `[pause N]` | Pauses the typewriter for N seconds at that point in the text | `The door creaks...[pause 1] and opens.` |
| `[speed N]` | Changes typewriter speed to N seconds per character from this point | `[speed 0.08]Slow, spooky text...` |
| `-- comment` | Ignored by the parser | `-- TODO: add more branches` |
| Anything else | Dialogue text | `Come in, young one.` |

### Multi-Line Dialogue

Multiple consecutive text lines in the same node are joined with a space:

```
# long_speech
The forest has been cursed for a hundred years.
Nobody who enters ever returns.
You would be wise to stay away.
```

This becomes: `"The forest has been cursed for a hundred years. Nobody who enters ever returns. You would be wise to stay away."`

### Rich Text

Roblox rich text works in dialogue content — you can use bold, italic, color, and more:

```
# dramatic_reveal
<b>The treasure was inside us all along.</b>
> That makes no sense. -> confused
> <i>*wipes tear*</i> Beautiful. -> emotional
```

Supported tags: `<b>`, `<i>`, `<u>`, `<s>`, `<font color='#rrggbb'>`, `<font size='N'>`, `<br/>`

The typewriter effect is rich-text safe — it never reveals broken partial tags.

### Speaker Override

By default, the speaker name is pulled from the NPC Model's `.Name` property. Use `@` to override it for a specific node:

```
# ghost_appears
@ The Ghost of Captain Redbeard
I have waited three centuries for someone brave enough to face me.
```

### Conditions on Choices

Gate a choice behind a condition using `[if key value]`:

```
# treasure_chest
A golden chest sits before you.
> Open it -> open_chest [if hasKey true]
> Take it -> steal_chest [if strength 10]
> Walk away -> leave
```

- When the condition fails, the choice is **greyed out** by default (still visible, not clickable)
- Add `[hide]` to make it completely invisible when the condition fails:

```
> Secret path -> secret [if isVIP true] [hide]
```

The `value` after the key is automatically parsed:
- `true` / `false` → boolean
- `500` → number
- `anything_else` → string

### Complete Example

```
=== elder_quest
start: intro

# intro
@ Elder Mira
Welcome, young hero. The village needs your help.
> What happened? -> explain
> I'm too busy. -> decline

# explain
Dark creatures have been spotted near the old mill.
We need someone brave to investigate.
> I'll go. -> accept
> Sounds dangerous. -> hesitate

# hesitate
It is dangerous. But you look capable enough.
Show me the Hero's Crest and I'll give you protection.
> Here it is! -> show_crest [if hasCrest true]
> I don't have it. -> no_crest

# no_crest
Then you must find it first. Check the old shrine to the west.
> I'll find it. -> leave_intro [end]

# show_crest
@ Elder Mira
Remarkable. You ARE the chosen one. Here, take this amulet.
> Thank you! -> accept

# accept [end]
@ Elder Mira
Be careful out there. The creatures are stronger after dark.
Return when the threat is gone.

# decline [end]
I understand. Come back if you change your mind.

# leave_intro [end]
Good luck. The shrine is west of the crossroads.
```

---

## 3. Lua Table Format

For developers who want full programmatic control over dialogue trees, you can define them as Lua tables directly. This lets you dynamically build trees at runtime, generate them from data stores, or add fields the text format doesn't support.

### Basic Structure

```lua
local myTree = {
    id = "npc_greeting",        -- tree ID (used in RegisterTree / Start)
    startNodeId = "hello",      -- which node to start at
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
            text = "The dragon threatens our lands. Please help!",
            isEndNode = true,
        },
        bye = {
            text = "Safe travels!",
            isEndNode = true,
        },
    },
}

local engine = DialogueEngine.new()
engine:RegisterTree("npc_greeting", myTree)
engine:Start("npc_greeting", npcModel)
```

### Full Node Schema

Here are all the fields a node can have:

```lua
some_node = {
    -- Required
    text = "What the NPC says.",

    -- Optional
    speaker = "Speaker Name",          -- overrides NPC model name
    portraitImageId = "rbxassetid://123456789",  -- custom portrait image
    npcModel = someModelInstance,       -- per-node model override for viewport portrait
    voiceSoundId = "rbxassetid://987654321",     -- audio to play when this node shows
    isEndNode = true,                   -- true = conversation ends after this node
    autoAdvanceDelay = 2,               -- seconds before auto-advancing (no-choice nodes only)

    -- Choices (omit for end nodes or auto-advance nodes)
    choices = {
        {
            text = "Choice button text",
            targetNodeId = "target_node",
            conditions = { hasItem = "dragonScale" },  -- optional condition table
            hideWhenUnavailable = false,  -- false = grey out, true = hide entirely
        },
    },
}
```

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `text` | string | Yes | The NPC's dialogue line |
| `speaker` | string | No | Speaker name shown above text. Falls back to NPC model name |
| `portraitImageId` | string or number | No | Asset ID for portrait image. Overrides viewport portrait |
| `npcModel` | Model | No | Model to use for viewport portrait on this specific node |
| `voiceSoundId` | string or number | No | Sound asset ID played when the node appears |
| `isEndNode` | boolean | No | If true, the dialogue ends after this node with no choices |
| `autoAdvanceDelay` | number | No | Seconds to wait then auto-advance (only for nodes with no choices) |
| `choices` | table | No | Array of choice objects. If omitted, node auto-ends or auto-advances |

### Choice Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `text` | string | Yes | The button label shown to the player |
| `targetNodeId` | string | Yes | Which node to navigate to when selected |
| `conditions` | table | No | Map of `{ conditionKey = expectedValue }` |
| `hideWhenUnavailable` | boolean | No | `false` = grey out when condition fails, `true` = hide entirely |

### Example with Conditions

```lua
local tree = {
    id = "merchant",
    startNodeId = "greet",
    nodes = {
        greet = {
            text = "Ah, a customer! What are you looking for?",
            choices = {
                {
                    text = "The legendary sword.",
                    targetNodeId = "sword_offer",
                    conditions = { gold = 500 },        -- requires gold >= 500
                    hideWhenUnavailable = false,         -- greyed out if broke
                },
                {
                    text = "[Secret] The back room...",
                    targetNodeId = "back_room",
                    conditions = { isMember = true },   -- members only
                    hideWhenUnavailable = true,          -- completely hidden for non-members
                },
                {
                    text = "Just browsing.",
                    targetNodeId = "browse",
                },
            },
        },
        sword_offer = {
            text = "500 gold for this blade. It's never missed.",
            isEndNode = true,
        },
        back_room = {
            text = "Ah, you know about the guild stock. Right this way.",
            isEndNode = true,
        },
        browse = {
            text = "Take your time. I'll be here.",
            isEndNode = true,
        },
    },
}
```

---

## 4. Theming Guide

The engine ships with five built-in themes and a full customization system. You can use a preset as-is, override individual properties, or combine a preset with your own tweaks.

### Using the Default Theme

Just create the engine with no arguments:

```lua
local engine = DialogueEngine.new()
```

The default is the **Dark** theme — a sleek dark UI suitable for most games.

### Using a Built-In Preset

Require the Theme module and pass a preset:

```lua
local Theme = require(ReplicatedStorage.DialogueEngine.Theme)
local engine = DialogueEngine.new(Theme.Presets.Fantasy)
```

### Built-In Presets

| Preset | Look & Feel | Best For |
|---|---|---|
| `Dark` | Deep dark background, gold speaker name, muted blue choices | Default. Anime RPGs, action games, modern aesthetics |
| `Fantasy` | Warm brown parchment tones, Merriweather serif font, amber accents | Medieval RPGs, fantasy adventures, classic JRPGs |
| `SciFi` | Near-black background, neon cyan accents, Ubuntu mono font, fast typewriter | Cyberpunk, space games, futuristic settings |
| `Bubblegum` | Bright pink-white pastels, FredokaOne font, large rounded corners | Tycoons, simulators, kid-friendly games, cozy experiences |
| `Horror` | Near-black background, blood-red accents, Antique font, very slow typewriter | Horror, survival, thriller, psychological games |

### Overriding Individual Properties

Pass a table of overrides to `DialogueEngine.new()`:

```lua
local engine = DialogueEngine.new({
    backgroundColor = Color3.fromRGB(10, 0, 20),   -- deep purple-black
    speakerColor = Color3.fromRGB(180, 0, 255),     -- purple speaker name
    typewriterSpeed = 0.05,                          -- slower text reveal
    textSize = 20,                                   -- bigger text
})
```

Only the fields you specify are changed — everything else uses the Dark default.

### Preset + Overrides with `Theme.Extend()`

Start from a preset and change just what you need:

```lua
local Theme = require(ReplicatedStorage.DialogueEngine.Theme)

-- Start from Fantasy preset but speed up the typewriter and make text bigger
local engine = DialogueEngine.new(
    Theme.Extend("Fantasy", {
        typewriterSpeed = 0.02,
        textSize = 20,
    })
)
```

### Changing Theme at Runtime

Use `engine:SetTheme()` to change the theme mid-game (e.g., for a different zone or different NPC):

```lua
-- Switch to horror theme when entering the haunted mansion
engine:SetTheme(Theme.Presets.Horror)

-- Later, switch back
engine:SetTheme(Theme.Presets.Dark)
```

### Per-NPC Themes

Pass a `theme` field inside callbacks to use a different theme for one NPC without permanently changing the engine:

```lua
engine:Start("elder", elderModel, {
    theme = Theme.Presets.Fantasy,  -- only used for this conversation
    onEnd = function() end,
})
```

When the conversation ends, the engine automatically reverts to the base theme.

### All Theme Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `backgroundColor` | Color3 | `(15, 15, 25)` | Main dialogue box background color |
| `backgroundTransparency` | number | `0.15` | 0 = fully opaque, 1 = fully transparent |
| `textColor` | Color3 | `(230, 230, 240)` | Main dialogue text color |
| `speakerColor` | Color3 | `(255, 200, 80)` | Speaker name color |
| `choiceColor` | Color3 | `(35, 35, 55)` | Choice button normal background |
| `choiceHoverColor` | Color3 | `(60, 60, 100)` | Choice button hover background |
| `choiceHighlightColor` | Color3 | `(80, 80, 140)` | Keyboard/gamepad selected choice highlight |
| `choiceTextColor` | Color3 | `(200, 200, 220)` | Choice button text color |
| `choiceUnavailableColor` | Color3 | `(80, 80, 80)` | Greyed-out choice button color |
| `font` | Enum.Font | `GothamMedium` | Main dialogue text font |
| `speakerFont` | Enum.Font | `GothamBold` | Speaker name font |
| `textSize` | number | `18` | Dialogue text size in pixels |
| `speakerTextSize` | number | `20` | Speaker name text size |
| `choiceTextSize` | number | `16` | Choice button text size |
| `cornerRadius` | UDim | `UDim(0, 8)` | Corner rounding of all UI elements |
| `portraitSize` | UDim2 | `UDim2(0, 100, 0, 100)` | Portrait frame size |
| `dialogueBoxSize` | UDim2 | `UDim2(0.8, 0, 0, 180)` | Dialogue box size |
| `dialogueBoxPosition` | UDim2 | `UDim2(0.1, 0, 1, -200)` | Dialogue box position on screen |
| `typewriterSpeed` | number | `0.03` | Seconds per character during typewriter animation |
| `voiceVolume` | number | `1` | Volume of voice sound lines (0–1) |
| `padding` | UDim | `UDim(0, 12)` | Internal UI padding |
| `animationSpeed` | number | `1` | Multiplier for all tween durations. Set to `0` to disable animations |
| `sfxVolume` | number | `1` | Volume for UI sound effects (0–1) |
| `openSoundId` | string | nil | Sound asset ID played when dialogue opens |
| `closeSoundId` | string | nil | Sound asset ID played when dialogue closes |
| `typewriterSoundId` | string | nil | Sound asset ID played per character during typewriter |
| `typewriterSoundPitch` | number | `0.1` | Random pitch variation range for typewriter sound |
| `choiceHoverSoundId` | string | nil | Sound asset ID played when hovering a choice |
| `choiceSelectSoundId` | string | nil | Sound asset ID played when selecting a choice |

---

## 5. Conditions & Events

### Conditions

Conditions let you gate choices behind game state — player's gold, inventory items, quest flags, level, or anything else you track.

#### Step 1: Register a Condition Callback

```lua
engine:RegisterCondition(function(key, value)
    if key == "hasItem" then
        return Inventory:HasItem(value)  -- value = item name
    elseif key == "gold" then
        return PlayerData.gold >= value  -- value = minimum amount
    elseif key == "level" then
        return PlayerData.level >= value
    elseif key == "questDone" then
        return QuestManager:IsComplete(value)
    end
    return false  -- unknown condition = not met
end)
```

You can register multiple callbacks. The engine checks all of them for each condition — if any returns `true`, the condition passes.

#### Step 2: Use Conditions in Your Dialogue

**Text format:**
```
# shop_node
I have something special for the right buyer.
> Show me the sword! -> buy_sword [if gold 500]
> I need the back room key. -> key_offer [if questDone mainQuest] [hide]
> Nothing for me today. -> farewell
```

**Lua table format:**
```lua
{
    text = "I have something special for the right buyer.",
    choices = {
        {
            text = "Show me the sword!",
            targetNodeId = "buy_sword",
            conditions = { gold = 500 },
            hideWhenUnavailable = false,  -- grey out if broke
        },
        {
            text = "I need the back room key.",
            targetNodeId = "key_offer",
            conditions = { questDone = "mainQuest" },
            hideWhenUnavailable = true,   -- completely hide if quest not done
        },
        {
            text = "Nothing for me today.",
            targetNodeId = "farewell",
        },
    },
}
```

#### `hideWhenUnavailable`

| Value | Behaviour |
|---|---|
| `false` (default) | Choice is visible but greyed out and unclickable |
| `true` | Choice is completely hidden when condition isn't met |

Greying out is good when you want players to know a choice exists but they don't qualify yet (encourages them to level up or get the item). Hiding is better for secret paths that shouldn't be spoiled.

### Event Hooks

Event hooks fire Lua functions at key moments during dialogue, letting you tie dialogue directly to game logic.

#### `onNodeEnter`

Fires every time a dialogue node is displayed:

```lua
engine:Start("quest_giver", npcModel, {
    onNodeEnter = function(nodeId)
        if nodeId == "quest_accepted" then
            QuestManager:StartQuest("rescue_mission")
            print("Quest started!")
        end
        if nodeId == "item_granted" then
            Inventory:GiveItem("HeroAmulet")
        end
    end,
})
```

#### `onChoice`

Fires when the player selects a choice:

```lua
engine:Start("elder", elderModel, {
    onChoice = function(nodeId, choiceIndex)
        print("Player at node", nodeId, "chose option", choiceIndex)
        
        -- Track choices for analytics
        Analytics:RecordChoice(nodeId, choiceIndex)
    end,
})
```

#### `onEnd`

Fires when the dialogue ends (either via end node, close button, or Escape key):

```lua
engine:Start("tutorial_npc", npc, {
    onEnd = function()
        TutorialManager:MarkComplete("npc_greeting")
        GuiService:HideHint("talk_to_npc")
    end,
})
```

#### Putting It All Together

Here's a complete quest-giver NPC that rewards the player:

```lua
local gaveReward = false

engine:Start("quest_giver", questGiverModel, {
    onNodeEnter = function(nodeId)
        -- Give reward when player reaches the completion node
        if nodeId == "reward_given" and not gaveReward then
            gaveReward = true
            Inventory:GiveItem("MagicSword")
            PlayerData:AddGold(200)
            QuestLog:Complete("slay_the_dragon")
        end
    end,
    onChoice = function(nodeId, choiceIndex)
        -- If player declines the quest, mark it as declined
        if nodeId == "quest_offer" and choiceIndex == 2 then
            QuestLog:Decline("slay_the_dragon")
        end
    end,
    onEnd = function()
        -- Cooldown before they can talk again
        task.delay(30, function()
            prompt.Enabled = true
        end)
        prompt.Enabled = false
    end,
})
```

---

## 6. Portraits

The dialogue engine automatically displays an NPC portrait in the corner of the dialogue box. It supports two methods: auto-viewport portraits from the NPC model, and custom image portraits.

### Auto-Viewport Portrait (Default)

When you pass an NPC model to `engine:Start()`, the engine automatically:
1. Finds the `HumanoidRootPart` or `Head` on the model
2. Creates a `ViewportFrame` and clones a snapshot of the model into it
3. Positions the camera to show the NPC's face

This works for any standard Roblox character or humanoid model — no setup required.

```lua
-- Just pass the NPC model — portrait happens automatically
engine:Start("villager", workspace.NPCs.Villager, {
    onEnd = function() end,
})
```

### Custom Portrait Image

Override the auto-viewport portrait with a specific image by setting `portraitImageId` on a node:

```lua
-- In Lua table format:
nodes = {
    intro = {
        text = "I am the ancient dragon.",
        portraitImageId = "rbxassetid://123456789",  -- your image asset ID
    },
}
```

```
-- In text format: use [portraitImageId] is not directly supported in text format
-- Use the Lua table format for per-node image portraits
```

When `portraitImageId` is set, the engine displays it as a flat image instead of the viewport model.

### Per-Node Model Override

You can swap the NPC model on specific nodes — useful for cutscenes with multiple characters or expressions:

```lua
nodes = {
    intro = {
        speaker = "Merchant",
        text = "This is a fine sword indeed.",
        npcModel = workspace.NPCs.Merchant,  -- uses this model's portrait
    },
    response = {
        speaker = "Guard Captain",
        text = "I'll need to inspect it first.",
        npcModel = workspace.NPCs.GuardCaptain,  -- switches portrait to guard
    },
}
```

### No Portrait

If you don't pass an NPC model and don't set `portraitImageId`, the portrait area is simply left empty. This is fine for narration-style dialogue or tutorial text boxes.

```lua
-- No model = no portrait
engine:Start("narrator_text", nil, { onEnd = function() end })
```

---

## 7. Input Controls

Players can control the dialogue using keyboard, gamepad, or mouse/touch. All input methods are handled automatically — you don't need to set anything up.

### Keyboard

| Key | Action |
|---|---|
| `1`, `2`, `3`, `4` | Instantly select choice by number |
| `Up` / `W` | Move highlight up through choices |
| `Down` / `S` | Move highlight down through choices |
| `Enter` / `Space` | Confirm highlighted choice, or skip typewriter animation |
| `Escape` | Close dialogue immediately |
| `Click` / `Tap` | Skip typewriter animation |

### Gamepad

| Button | Action |
|---|---|
| `D-Pad Up` | Move highlight up through choices |
| `D-Pad Down` | Move highlight down through choices |
| `A Button` | Confirm highlighted choice, or skip typewriter animation |
| `B Button` | Close dialogue (finishes typewriter first if still animating, then closes on second press) |

### Mouse & Touch

| Input | Action |
|---|---|
| Click anywhere on the dialogue box | Skip typewriter animation |
| Click a choice button | Select that choice |

### Typewriter Skip Behaviour

When text is still animating:
- Pressing `Enter`, `Space`, `A` (gamepad), or clicking anywhere will **instantly reveal the full text**
- A second press/click then **confirms the choice or advances**

This two-step behaviour prevents accidental choice selection while text is still revealing.

---

## 8. Save / Load State

The save/load system lets you remember where a player left off in a conversation — useful for games where NPCs remember past interactions or for saving mid-quest dialogue state.

### Saving State

Call `engine:SaveState()` to get a serializable table you can store in a DataStore:

```lua
-- Save after the player finishes talking (e.g., in onEnd)
engine:Start("quest_giver", npc, {
    onEnd = function()
        local state = engine:SaveState("quest_giver")
        -- state = {
        --     treeId = "quest_giver",
        --     currentNodeId = "farewell",
        --     visitedNodes = { greeting = true, quest_offer = true, farewell = true },
        --     timestamp = 1234567890,
        -- }
        
        -- Store it in a DataStore (you manage the DataStore)
        DataStore:SetAsync("DialogueState_" .. player.UserId, state)
    end,
})
```

### Loading State

When the player returns, load the state and resume from where they left off:

```lua
-- Load the saved state from DataStore
local savedState = DataStore:GetAsync("DialogueState_" .. player.UserId)

if savedState then
    -- Resume from the saved node
    engine:StartFromState("quest_giver", savedState, npc, {
        onEnd = function()
            -- Save updated state when done
            local newState = engine:SaveState("quest_giver")
            DataStore:SetAsync("DialogueState_" .. player.UserId, newState)
        end,
    })
else
    -- First time — start from the beginning
    engine:Start("quest_giver", npc)
end
```

### Checking Visited Nodes

Use `GetVisitedNodes()` to check which parts of a dialogue the player has seen:

```lua
local visited = engine:GetVisitedNodes("quest_giver")

if visited["quest_accepted"] then
    -- Player already accepted the quest — show a different greeting
    engine:Start("quest_giver_reminder", npc)
else
    engine:Start("quest_giver", npc)
end
```

### Complete DataStore Integration Example

```lua
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local dialogueStore = DataStoreService:GetDataStore("DialogueStates")

local function getStateKey(player, treeId)
    return player.UserId .. "_" .. treeId
end

local function saveDialogueState(player, treeId, state)
    local key = getStateKey(player, treeId)
    local success, err = pcall(function()
        dialogueStore:SetAsync(key, state)
    end)
    if not success then
        warn("Failed to save dialogue state:", err)
    end
end

local function loadDialogueState(player, treeId)
    local key = getStateKey(player, treeId)
    local success, result = pcall(function()
        return dialogueStore:GetAsync(key)
    end)
    if success then
        return result
    end
    return nil
end

-- When player talks to NPC
local function startNPCDialogue(player, npc, treeId)
    local savedState = loadDialogueState(player, treeId)
    
    local callbacks = {
        onEnd = function()
            local state = engine:SaveState(treeId)
            saveDialogueState(player, treeId, state)
        end,
    }
    
    if savedState then
        engine:StartFromState(treeId, savedState, npc, callbacks)
    else
        engine:Start(treeId, npc, callbacks)
    end
end
```

---

## 9. Variable Interpolation

Insert dynamic runtime values into dialogue text using `{variableName}` syntax. Variables work in both dialogue text and choice text, and are resolved at display time so they always reflect current game state.

### Basic Usage

```
# shopkeeper_greeting
Hello, {playerName}! You have {gold} gold. What can I get you?
> Buy sword (500g) -> buy_sword [if gold 500]
> Buy the {specialItem} ({specialPrice}g) -> buy_special
> Goodbye. -> farewell
```

### Registering a Variable Resolver

Use `engine:RegisterVariable()` to supply values:

```lua
engine:RegisterVariable(function(varName)
    if varName == "playerName" then return Players.LocalPlayer.Name end
    if varName == "gold" then return PlayerData.gold end
    if varName == "questName" then return QuestManager:GetActiveName() end
    return nil  -- unresolved variables stay as {varName} in the text
end)
```

You can call `RegisterVariable()` multiple times to register multiple resolvers. The engine checks all of them in registration order — the first non-nil return value wins.

### Unresolved Variables

If no resolver returns a value for a variable, the raw tag stays in the displayed text exactly as written (`{varName}`). This makes bugs visible at a glance instead of silently displaying blank text.

### Variables in Choice Text

Variables resolve identically in choice button text:

```
> Buy sword ({swordPrice}g) -> buy_sword [if gold 500]
> Trade {ownedItem} for {wantedItem} -> trade
```

### Multi-Resolver Pattern

Split concerns across multiple resolvers — one per system:

```lua
-- Player data resolver
engine:RegisterVariable(function(varName)
    local playerVars = {
        playerName = Players.LocalPlayer.Name,
        gold = PlayerData.gold,
        level = PlayerData.level,
    }
    return playerVars[varName]
end)

-- Quest data resolver
engine:RegisterVariable(function(varName)
    if varName == "questName" then return QuestManager:GetActiveName() end
    if varName == "questTarget" then return QuestManager:GetTarget() end
    return nil
end)
```

### Variable Pattern

The engine matches `{variableName}` using the pattern `{([%w_%.]+)}` — names can contain letters, numbers, underscores, and dots. Spaces inside braces are not matched.

---

## 10. Inline Text Control

Add dramatic pacing to dialogue without breaking up your text into separate nodes. Two inline tags control the typewriter animation mid-sentence: `[pause N]` and `[speed N]`.

### Tags

| Tag | Effect |
|---|---|
| `[pause N]` | Pauses the typewriter for N seconds at that point in the text |
| `[speed N]` | Changes typewriter speed to N seconds per character from this point forward |

Both tags are stripped from the displayed text — players only see the prose, never the markup.

### Pause Tag

Use `[pause N]` to hold the typewriter at a specific point before continuing:

```
# dramatic_reveal
The envelope contains...[pause 1.5] a blank sheet of paper.
```

```
# horror_moment
You reach for the handle.[pause 0.8] It's warm.[pause 1.2] It shouldn't be warm.
```

The number is in seconds and supports decimals. Players can click or tap to skip through pauses, the same way they skip the typewriter animation.

### Speed Tag

Use `[speed N]` to change the typewriter speed mid-text. N is seconds per character — smaller values are faster:

```
# villain_monologue
[speed 0.06]I have waited... a very long time for this moment.
[speed 0.01]AND NOW IT'S TIME TO MAKE MY MOVE!
```

Speed resets to the theme's `typewriterSpeed` default at the start of each new node. This means you never need to manually reset it — every node starts fresh.

### Combining Pause and Speed

Both tags can be combined freely for sophisticated pacing:

```
# dramatic_reveal
The door opens slowly...[pause 1] and behind it...[pause 2]
[speed 0.08]Nothing. Absolutely nothing.[pause 0.5]
[speed 0.01]JUST KIDDING! A DRAGON!
```

```
# scary_message
[speed 0.07]The message reads:[pause 0.5]
"[speed 0.12]D o   n o t   o p e n   t h e   d o o r ."[pause 2]
[speed 0.03]You look up. The door is already open.
```

### Auto-Advance Compatibility

Inline text control tags work on auto-advance nodes (`[auto N]`). The `autoAdvanceDelay` timer starts after the typewriter finishes (including all pauses), so the timing is always predictable.

---

## 11. API Reference

### `DialogueEngine`

Require it from `ReplicatedStorage.DialogueEngine.DialogueEngine`.

---

#### `DialogueEngine.new(themeOverrides?)`

Creates a new engine instance.

```lua
-- Default (Dark theme)
local engine = DialogueEngine.new()

-- With theme overrides
local engine = DialogueEngine.new({ typewriterSpeed = 0.05 })

-- With a preset
local Theme = require(ReplicatedStorage.DialogueEngine.Theme)
local engine = DialogueEngine.new(Theme.Presets.Fantasy)
```

**Parameters:**
- `themeOverrides` *(optional)*: Table of theme property overrides. See [Theming Guide](#4-theming-guide) for all properties.

**Returns:** engine instance

> **Singleton behavior:** Only one dialogue can be active at a time per client. Calling `DialogueEngine.new()` automatically closes any previously active dialogue instance. Create one engine for the whole game and reuse it across all NPCs — see [Can I run multiple dialogue engines at once?](#can-i-run-multiple-dialogue-engines-at-once) for the recommended pattern.

---

#### `engine:RegisterTree(treeId, dialogueData)`

Registers a dialogue tree so you can start it by ID.

```lua
engine:RegisterTree("village_elder", myTree)
```

**Parameters:**
- `treeId`: string — the ID used when calling `Start()`
- `dialogueData`: table — a dialogue tree (from `DialogueParser.Parse()` or a hand-written Lua table)

---

#### `engine:RegisterCondition(callback)`

Adds a function that evaluates conditions on choices.

```lua
engine:RegisterCondition(function(key, value)
    if key == "gold" then
        return PlayerData.gold >= value
    end
    return false
end)
```

**Parameters:**
- `callback`: `(key: string, value: any) -> boolean`
  - `key`: the condition name (e.g. `"gold"`, `"hasItem"`)
  - `value`: the expected value from the dialogue definition
  - Return `true` if the condition is met, `false` if not

You can call this multiple times to register multiple evaluators. All registered evaluators are checked; if any returns `true`, the condition passes.

---

#### `engine:RegisterVariable(resolver)`

Adds a function that supplies values for `{variableName}` placeholders in dialogue and choice text.

```lua
engine:RegisterVariable(function(varName)
    if varName == "playerName" then return Players.LocalPlayer.Name end
    if varName == "gold" then return PlayerData.gold end
    if varName == "questName" then return QuestManager:GetActiveName() end
    return nil  -- return nil to pass to the next resolver
end)
```

**Parameters:**
- `resolver`: `(varName: string) -> string | number | nil`
  - `varName`: the variable name from the dialogue (e.g. `"playerName"`, `"gold"`)
  - Return the value to display, or `nil` to defer to the next registered resolver

You can call this multiple times to register multiple resolvers. They are checked in registration order — the first non-nil return value is used. If all resolvers return nil, the placeholder stays as `{varName}` in the displayed text.

See [Section 9 — Variable Interpolation](#9-variable-interpolation) for full examples and patterns.

---

#### `engine:Start(treeId, npcModelOrCallbacks?, callbacks?)`

Starts a dialogue. Shows the UI and begins at the tree's start node.

```lua
-- With NPC model and callbacks
engine:Start("merchant", npcModel, {
    onNodeEnter = function(nodeId) end,
    onChoice = function(nodeId, choiceIndex) end,
    onEnd = function() end,
    theme = Theme.Presets.Fantasy,  -- optional per-conversation theme
})

-- Without NPC model (no portrait)
engine:Start("narrator", {
    onEnd = function() end,
})
```

**Parameters:**
- `treeId`: string — which registered tree to start
- `npcModelOrCallbacks` *(optional)*: either an NPC `Model` instance or a callbacks table
- `callbacks` *(optional)*: callbacks table (if first optional arg was a Model)

**Callbacks table fields:**
| Field | Type | Description |
|---|---|---|
| `onNodeEnter` | `(nodeId: string) -> ()` | Fires when each node is displayed |
| `onChoice` | `(nodeId: string, choiceIndex: number) -> ()` | Fires when a choice is selected |
| `onEnd` | `() -> ()` | Fires when dialogue ends |
| `theme` | table | Per-conversation theme overrides |

---

#### `engine:StartFromState(treeId, savedState, npcModelOrCallbacks?, callbacks?)`

Resumes a dialogue from a previously saved state.

```lua
engine:StartFromState("quest_giver", savedState, npcModel, {
    onEnd = function() end,
})
```

**Parameters:** Same as `Start()`, plus:
- `savedState`: the table returned by `SaveState()`

If the saved state is invalid or the node no longer exists, falls back to starting from the beginning.

---

#### `engine:Skip()`

Skips the current typewriter animation (reveals full text immediately).

> Note: Typewriter skip is also handled automatically by user input (Enter, Space, A button, click). This method is available if you need to trigger it programmatically.

---

#### `engine:Close()`

Closes the dialogue UI immediately, ending the current conversation.

```lua
engine:Close()
```

This also fires if the player presses Escape or the B button.

---

#### `engine:SetTheme(themeOverrides)`

Updates the theme at runtime. Useful for zone-based or event-based visual changes.

```lua
-- Enter haunted area
engine:SetTheme(Theme.Presets.Horror)

-- Leave haunted area
engine:SetTheme(Theme.Presets.Dark)
```

**Parameters:**
- `themeOverrides`: table of theme properties to apply (merged onto current theme)

---

#### `engine:SaveState(treeId?)`

Returns the current dialogue state as a serializable table.

```lua
local state = engine:SaveState("quest_giver")
-- Returns:
-- {
--     treeId = "quest_giver",
--     currentNodeId = "farewell",
--     visitedNodes = { greeting = true, farewell = true },
--     timestamp = 1234567890,
-- }
```

**Parameters:**
- `treeId` *(optional)*: which tree to save state for. Defaults to the currently active tree.

**Returns:** `SavedState` table or `nil` if nothing is active.

---

#### `engine:LoadState(treeId, savedState)`

Loads a saved state without starting the UI. Returns `true` if successful.

```lua
local ok = engine:LoadState("quest_giver", savedState)
if ok then
    print("State loaded successfully")
end
```

Validates that a saved state is valid for the given tree. Returns true if the state can be used with `StartFromState()`. Does not start the UI or modify engine state.

---

#### `engine:GetVisitedNodes(treeId)`

Returns the set of node IDs the player has visited in a given tree.

```lua
local visited = engine:GetVisitedNodes("main_quest_npc")
if visited["final_node"] then
    -- Player has completed this conversation
end
```

**Returns:** `{ [nodeId: string]: boolean }`

---

#### `engine:Destroy()`

Cleans up all engine resources. Call this when you're done with the engine (e.g., when the LocalScript is destroyed or the player leaves).

```lua
engine:Destroy()
```

---

### `DialogueParser`

Require it from `ReplicatedStorage.DialogueEngine.DialogueParser`.

---

#### `DialogueParser.Parse(source)`

Converts a text-format dialogue string into a dialogue tree table.

```lua
local tree = DialogueParser.Parse([[
=== my_tree
start: intro

# intro
Hello!
> Hi! -> bye

# bye [end]
Goodbye!
]])
```

**Parameters:**
- `source`: string — the full text-format dialogue source

**Returns:** `DialogueTree` table with `id`, `startNodeId`, and `nodes` fields.

---

### `Theme`

Require it from `ReplicatedStorage.DialogueEngine.Theme`.

---

#### `Theme.Presets`

Table of built-in preset theme overrides. Keys: `Dark`, `Fantasy`, `SciFi`, `Bubblegum`, `Horror`.

```lua
local Theme = require(ReplicatedStorage.DialogueEngine.Theme)
local engine = DialogueEngine.new(Theme.Presets.SciFi)
```

---

#### `Theme.Extend(presetName, overrides?)`

Merges a preset with optional overrides and returns the combined table.

```lua
local myTheme = Theme.Extend("Horror", {
    typewriterSpeed = 0.1,   -- even slower
    textSize = 16,
})
local engine = DialogueEngine.new(myTheme)
```

**Parameters:**
- `presetName`: string — name of the preset (`"Dark"`, `"Fantasy"`, etc.)
- `overrides` *(optional)*: table of additional overrides

**Returns:** theme table

---

#### `Theme.Merge(overrides?)`

Merges overrides onto the default Dark theme.

```lua
local myTheme = Theme.Merge({ backgroundColor = Color3.fromRGB(0, 10, 0) })
```

---

## 12. FAQ / Troubleshooting

### Nothing happens when I call `engine:Start()`

**Cause:** The tree ID wasn't registered, or `RegisterTree()` wasn't called before `Start()`.

**Fix:** Make sure you call `RegisterTree()` before `Start()`:
```lua
engine:RegisterTree("my_tree", myTree)  -- do this first
engine:Start("my_tree", npc)
```

Also check the output window for warnings — the engine prints `[DialogueEngine] Tree not found: <id>` if the tree ID doesn't exist.

---

### The dialogue box shows but text is empty

**Cause:** The `text` field on the node is empty or nil.

**Fix:** Make sure every node in your Lua table has a `text` field. In text format, make sure there's actual content between the `# node_name` line and the next `#` or `>` line.

---

### Choices don't appear

**Cause 1:** All choices have conditions that are failing.

**Fix:** Check your `RegisterCondition()` callback. Make sure it returns `true` (not just a truthy value) when the condition is met. Also make sure you called `RegisterCondition()` on the same engine instance you're calling `Start()` on.

**Cause 2:** The choices have `hideWhenUnavailable = true` and all conditions are failing.

**Fix:** This is working as designed — `[hide]` makes choices invisible when unavailable. Use `hideWhenUnavailable = false` (the default) if you want them greyed out instead.

---

### The portrait doesn't show

**Cause 1:** No NPC model was passed to `Start()`.

**Fix:** Pass the Model: `engine:Start("my_tree", workspace.MyNPC)`. If you don't have a model, the portrait area will simply be empty — that's fine.

**Cause 2:** The model doesn't have a `HumanoidRootPart` or `Head`.

**Fix:** The viewport portrait requires a standard humanoid model structure. Non-humanoid models may not display correctly in the viewport.

**Cause 3:** For custom `portraitImageId`, the image asset isn't approved or is the wrong asset type.

**Fix:** Make sure the asset is an Image (not a Decal or Texture) and is approved for use. You can test by placing an `ImageLabel` manually in Studio.

---

### Voice audio doesn't play

**Cause:** The `voiceSoundId` asset ID is wrong, the audio isn't approved, or the asset isn't owned by the game.

**Fix:** Verify the asset ID in Studio by creating a test `Sound` instance and setting `SoundId`. Make sure it plays in Studio before expecting it to work in the engine.

---

### The dialogue opens but immediately closes

**Cause:** The first node is an end node (`isEndNode = true` or `[end]` in text format) with no text.

**Fix:** Your start node should have content. End nodes are for the last line of a conversation path, not the first.

---

### Multiple dialogues seem to conflict

**Cause:** `DialogueEngine.new()` closes any previously running dialogue when called. If you call `new()` inside an NPC prompt callback, each NPC creates a new engine that closes the previous one.

**Fix:** Create **one engine** for the whole game, not one per NPC:

```lua
-- Do this ONCE at the top of your LocalScript
local engine = DialogueEngine.new()

-- Register all trees once
engine:RegisterTree("npc_1", tree1)
engine:RegisterTree("npc_2", tree2)

-- Start different trees when different NPCs are triggered
-- The engine handles switching automatically
```

---

### Conditions work in Studio but not in a published game

**Cause:** The condition callback uses server data that isn't available on the client.

**Fix:** Dialogue runs on the **client**. Conditions must use client-accessible data. Use RemoteEvents/RemoteFunctions to sync necessary data (player gold, inventory, etc.) to the client before dialogue starts.

---

### Text overflows the dialogue box on mobile

**Cause:** Long lines at the default `textSize` can overflow on smaller screens.

**Fix:** Use shorter dialogue lines, or adjust the theme's `textSize`, `dialogueBoxSize`, or `dialogueBoxPosition` for your target platform:

```lua
local engine = DialogueEngine.new({
    textSize = 16,
    dialogueBoxSize = UDim2.new(0.95, 0, 0, 200),
    dialogueBoxPosition = UDim2.new(0.025, 0, 1, -220),
})
```

---

### How do I trigger dialogue from a ProximityPrompt?

```lua
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Talk"
prompt.Parent = npc:FindFirstChild("Head")

prompt.Triggered:Connect(function(player)
    if player == game.Players.LocalPlayer then
        engine:Start("my_tree", npc)
    end
end)
```

---

### Can I run multiple dialogue engines at once?

**Short answer:** No. Only one dialogue engine instance is active at a time per client. Creating a new `DialogueEngine.new()` automatically closes the previous active instance.

If you need to sequence dialogues or handle complex multi-NPC scenarios, register all trees on a single engine and chain them using `onEnd` callbacks:

```lua
engine:Start("npc_part_1", npc, {
    onEnd = function()
        engine:Start("npc_part_2", npc)
    end,
})
```

---

## 13. Changelog

### V1.0.0

**New in V1.0:**

- **Variable interpolation** — `{variableName}` syntax in dialogue text and choice text, resolved at display time via `engine:RegisterVariable()`. Multiple resolvers supported; first non-nil value wins. Unresolved variables display as `{varName}` rather than blank.
- **Inline text control** — `[pause N]` and `[speed N]` tags for mid-sentence pacing control. Pauses are skippable by player input. Speed resets to theme default on each new node.
- **Simple text format** — write dialogue trees in plain text with `===`, `#`, `>`, `@` syntax. No Lua required for content.
- **Lua table format** — full programmatic tree definition for advanced use cases
- **5 built-in themes** — Dark, Fantasy, SciFi, Bubblegum, Horror
- **`Theme.Extend()`** — combine a preset with custom overrides
- **Per-conversation themes** — pass `theme` in callbacks to use a different look per NPC
- **Auto-viewport portrait** — NPC model auto-displayed in a ViewportFrame portrait
- **Custom portrait images** — per-node `portraitImageId` for character art
- **Per-node model override** — `npcModel` field for multi-character scenes
- **Condition system** — `RegisterCondition()` callbacks gate choices on game state
- **`hideWhenUnavailable`** — choices can be hidden instead of greyed out
- **Event hooks** — `onNodeEnter`, `onChoice`, `onEnd` callbacks
- **Typewriter effect** — character-by-character text reveal, rich-text safe
- **`autoAdvanceDelay`** — no-choice nodes can auto-advance after a delay
- **Keyboard controls** — 1–4 to select, arrow keys to navigate, Enter/Space to confirm, Escape to close
- **Gamepad support** — D-pad navigate, A confirm, B close
- **Voice/sound lines** — `voiceSoundId` per node with automatic cleanup
- **UI sound effects** — `openSoundId`, `closeSoundId`, `typewriterSoundId`, `choiceHoverSoundId`, `choiceSelectSoundId`
- **Save/Load state** — `SaveState()`, `StartFromState()`, `GetVisitedNodes()`
- **ProximityPrompt integration** — modern NPC interaction pattern (replaces ClickDetector)
- **`engine:Destroy()`** — full resource cleanup
- **`animationSpeed`** theme property — scale or disable all UI animations
- **`sfxVolume`** theme property — separate volume for UI sound effects

---

*Have a question not answered here? Check the [Roblox DevForum](https://devforum.roblox.com/) or open an issue on the project page.*
