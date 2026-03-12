# Thornwood Village — Dialogue Engine Template Place

A ready-to-play demo that showcases every feature of the Dialogue Engine through 7 NPCs in a small fantasy village.

## Quick Setup (3 minutes)

### Step 1: Insert the DialogueEngine Model

1. Open **Roblox Studio** and create a new **Baseplate** place
2. Delete the default Baseplate part from Workspace
3. Insert the **DialogueEngine** model into **ReplicatedStorage**:
   - **Option A:** Open the Toolbox (View → Toolbox), search "DialogueEngine", click to insert
   - **Option B:** Drag `DialogueEngine.rbxmx` into ReplicatedStorage

Your hierarchy should look like:
```
ReplicatedStorage/
  DialogueEngine/
    DialogueEngine (ModuleScript)
    DialogueParser (ModuleScript)
    DialogueRunner (ModuleScript)
    DialogueUI     (ModuleScript)
    Theme          (ModuleScript)
    Types          (ModuleScript)
    Demo/
      VerySimpleExampleDialog  (LocalScript, Disabled) — beginner basics
      MoreExampleDialog        (LocalScript, Disabled) — 4-NPC integration example
      TestDemoExampleDialog    (LocalScript, Disabled) — 7-NPC village dialogues
      TestDemoLevelHere        (Script, Disabled)      — builds the village
```

### Step 2: Build the Demo Village

The `TestDemoLevelHere` script is already inside the model under `Demo/`. Two ways to run it:

**Command Bar (quickest):**
1. Open `ReplicatedStorage > DialogueEngine > Demo > TestDemoLevelHere`
2. Select all the code and copy it
3. Open **View → Command Bar**, paste, and press **Enter** — the village builds instantly

**ServerScriptService (alternative):**
1. Drag `TestDemoLevelHere` from `Demo/` into **ServerScriptService**
2. Enable the script (uncheck Disabled in Properties)
3. **Play** once — the village builds itself
4. **Stop** — the village stays in Workspace
5. Delete or re-disable the script (it only runs once)

### Step 3: Add the Dialogue Script

1. Drag `TestDemoExampleDialog` from `ReplicatedStorage > DialogueEngine > Demo` into **StarterPlayer → StarterPlayerScripts**
2. Enable the script (uncheck Disabled in Properties)

Or copy-paste `TemplateSetup.local.luau` into a new LocalScript there.

### Step 4: Play!

Hit **Play** and walk around Thornwood Village. Approach any NPC and press **E** to talk.

> **Prefer to skip the setup?** Open the published demo place directly:
> https://www.roblox.com/games/TODO_PLACE_ID/DialogueEngine-Demo
> You get your own editable copy — modify anything you want.

## The NPCs

| NPC | Where to Find | What They Demonstrate |
|-----|--------------|----------------------|
| **Elder Maren** | Town Square bench | Basic branching, rich text, village lore, cross-NPC quest awareness |
| **Forge Master Brok** | Outside the forge | Shopping with gold conditions, flag-based purchases, `{playerName}` variables, `[call]` forge sounds |
| **Merchant Lira** | Market stall | `[hide]` for items you can't afford, multiple inventory flags, news/rumors |
| **Sage Thalindra** | Wizard Tower | `[pause]` and `[speed]` dramatic text, `[auto]` auto-advance intro, Fantasy theme, magic teaching |
| **Captain Aldric** | Village gate | Bounty board quests, cross-NPC quest chain (Pip rescue), short military responses |
| **Innkeeper Mira** | The Thorned Rose tavern | `[call]` heal action, Dark theme, food/room shop, village rumors |
| **Pip** | By the pond | `[auto]` crying scene, emotional pacing with `[pause]`, quest chain that links to Captain Aldric and Elder Maren |

## The Quest Chain

Try this sequence to see cross-NPC flags in action:

1. Talk to **Pip** by the pond — they're lost and scared
2. Talk to **Elder Maren** — she notices Pip is lost and sends you to the Captain
3. Talk to **Captain Aldric** — he dispatches a guard and sends you to find Pip
4. Talk to **Pip** again — walk them home
5. Talk to **Captain Aldric** — report Pip is safe, receive 300 gold reward
6. Talk to **Elder Maren** — she thanks you with 500 gold

## Features Demonstrated

Every engine capability is covered:

- [x] Basic dialogue with choices
- [x] Branching conversation paths
- [x] `[end]` nodes (conversation enders)
- [x] `[auto N]` auto-advance nodes (Sage intro, Pip crying)
- [x] `[if key value]` conditions on choices (gold checks, quest flags)
- [x] `[hide]` unavailable choices (Merchant shop)
- [x] `[set key value]` flag manipulation (purchases, quest state)
- [x] `[call actionName]` custom actions (forge sounds, healing, quest updates)
- [x] `{variableName}` text interpolation (`{playerName}`, `{gold}`)
- [x] `[pause N]` dramatic pauses (Sage, Pip)
- [x] `[speed N]` typewriter speed changes (Sage dramatic reveals)
- [x] Rich text (bold, italic, colored text across all NPCs)
- [x] Theme presets: Dark (Innkeeper), Fantasy (Elder, Sage), Bubblegum (Merchant, Pip), Default (Blacksmith, Guard)
- [x] Speaker names on every node
- [x] ViewportFrame portraits (NPC model rendered in UI)
- [x] Cross-NPC flag chains (Pip → Guard → Elder quest)

## File Reference

| File | Purpose |
|------|---------|
| `TestDemoLevelHere.server.luau` | Paste into Command Bar or ServerScriptService to build the village |
| `TemplateSetup.local.luau` | Main LocalScript with all dialogue trees, engine setup, NPC wiring |
| `README.md` | This file |
