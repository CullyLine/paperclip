# Dialogue Designer — Installation Guide

A visual node-graph editor for the DialogueEngine system, built as a Roblox Studio plugin.

## Option A: One-File Install (Recommended)

1. Locate the file `DialogueDesigner.rbxmx` in this folder
2. Open your Roblox Studio Plugins folder:
   - In Studio: `View > Plugins Folder` (this opens the folder in Explorer/Finder)
   - Or navigate manually: `%localappdata%\Roblox\Plugins` (Windows) / `~/Documents/Roblox/Plugins` (Mac)
3. **Drag `DialogueDesigner.rbxmx` into that folder**
4. Restart Roblox Studio
5. The "Dialogue Designer" button appears in the **Plugins** tab — click it to open

That's it. One file, done.

> **Rebuilding**: If you edit the `.lua` source files, regenerate the `.rbxmx` by running `node build-rbxmx.cjs` in this folder.

## Option B: Manual Setup (No External Tools)

1. Open **Roblox Studio**
2. In the Explorer, open your Plugins folder (`View > Plugins Folder`)
3. Create a **Folder** named `DialogueDesigner`
4. Inside it, create the following hierarchy (all items are siblings):

```
DialogueDesigner (Folder)
├── Plugin (Script)                   ← paste Plugin.server.lua contents here
├── DesignerTheme (ModuleScript)      ← paste DesignerTheme.lua
├── AppState (ModuleScript)           ← paste AppState.lua
├── Serializer (ModuleScript)         ← paste Serializer.lua
├── NodeWidget (ModuleScript)         ← paste NodeWidget.lua
├── ConnectionRenderer (ModuleScript) ← paste ConnectionRenderer.lua
├── Canvas (ModuleScript)             ← paste Canvas.lua
├── PropertyPanel (ModuleScript)      ← paste PropertyPanel.lua
└── Toolbar (ModuleScript)            ← paste Toolbar.lua
```

5. **Important**: The `Plugin` item must be a **Script** (not ModuleScript). All others are **ModuleScripts**. Everything must be inside the same folder — not nested inside each other.
6. ModuleScript names must match exactly (no `.lua` extension, case-sensitive)
7. Save the plugin — it will appear in the **Plugins** tab as "Dialogue Engine"

## Option B: Rojo (Recommended for Developers)

If you use [Rojo](https://rojo.space/) for file syncing:

1. Copy this `Designer` folder into your project
2. The `.server.lua` extension marks the entry point as a Script
3. All `.lua` files become ModuleScripts automatically
4. Sync with `rojo serve` and the plugin appears in Studio

Create a `default.project.json` in this folder if needed:

```json
{
  "name": "DialogueDesigner",
  "tree": {
    "$path": "."
  }
}
```

## How to Use

1. Click the **"Dialogue Designer"** button in the Plugins toolbar
2. The designer dock opens with a canvas, property panel, and toolbar

### Creating Nodes
- **Right-click** on the canvas → "Add Node" or "Add End Node"
- Click a node to **select** it and edit its properties in the right panel
- **Drag** node headers to reposition them

### Connecting Nodes
- Click a **blue dot** (choice output, bottom of a node)
- Then click the **green dot** (input, top of another node) to connect them
- Connections appear as lines — white for normal, yellow for conditional, cyan for actions

### Editing Properties
- Select a node → edit its ID, speaker, text, choices, conditions, and actions
- Add choices with the **"+ Add Choice"** button
- Set conditions with the `if [key] [value]` fields
- Add actions with `[set key value]` or `[call actionName]` via the action editor
- Toggle **End Node** to mark conversation-ending nodes
- Click **"Set as Start Node"** to change the entry point

### Import / Export
- **Import**: Paste existing dialogue text (same format as `DialogueParser.Parse`)
- **Export**: Copy the generated text to use in your game scripts
- **Save**: Creates a ModuleScript in `ReplicatedStorage.DialogueEngine.Trees`

### Node Colors
- **Green header** = Start node
- **Red header** = End node
- **Gray header** = Normal node
- **Blue border** = Selected

### Keyboard Shortcuts
- **Ctrl+Z** / **Ctrl+Y** — Undo / Redo (via toolbar buttons)

## Round-Trip Support

Exported text includes `-- pos: nodeName x y` comments that preserve your canvas layout.
You can export, hand-edit the text, and re-import without losing node positions.

## Requirements

- Roblox Studio (any recent version)
- The DialogueEngine module in ReplicatedStorage (for the Save feature)
