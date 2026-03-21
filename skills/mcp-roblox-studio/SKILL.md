---
name: mcp-roblox-studio
description: >-
  Manipulate Roblox Studio via MCP tools. Use when you need to inspect, create,
  modify, or delete instances in Studio, read or write script sources, execute
  Luau code, run playtests, capture screenshots, or interact with the Creator
  Store. Covers the full tool catalog, instance path conventions, concurrency
  rules, and common workflows.
---

# MCP Roblox Studio Manipulation

Control Roblox Studio programmatically through the robloxstudio-mcp server. Each Cursor session automatically spawns its own MCP server process via stdio. The Studio plugin auto-discovers and connects to each process independently (supports up to 5 simultaneous connections on ports 58741-58745).

## Connection

The Board operator runs a robloxstudio-mcp server on **port 58741**. All agents share this server. The Studio plugin connects to it and executes commands inside Roblox Studio.

### How to Call Tools

Every tool is available as a POST endpoint on `http://localhost:58741/mcp/<tool_name>`.

Use `Invoke-RestMethod` in PowerShell (via the Shell tool):

```powershell
# No arguments
Invoke-RestMethod -Uri "http://localhost:58741/mcp/get_place_info" -Method POST -ContentType "application/json" -Body "{}"

# With arguments
Invoke-RestMethod -Uri "http://localhost:58741/mcp/execute_luau" -Method POST -ContentType "application/json" -Body '{"code":"return game.Workspace:GetChildren()"}'

# With complex arguments (use a variable to avoid escaping issues)
$body = @{ instancePath = "Workspace"; propertyName = "Name" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:58741/mcp/get_instance_properties" -Method POST -ContentType "application/json" -Body $body
```

The response is JSON with a `content` array. Each entry has `type` (usually `"text"`) and `text` (the result, often JSON-encoded).

### Health Check

Before calling tools, verify the MCP server is up and Studio is connected:

```powershell
Invoke-RestMethod -Uri "http://localhost:58741/health" -Method GET
```

Look for `"pluginConnected": true`. If false, the Studio plugin hasn't connected yet -- wait and retry. If the health check itself fails, the Board's MCP server is not running. Report this on your Paperclip issue and move on to non-Studio work.

## Instance Paths

All tools that reference instances use **dot-notation paths** rooted at the service level:

```
Workspace.Worlds.1.Start.Part
ReplicatedStorage.PetModels.cat_orange
ServerStorage.CarModels.sedan_blue
StarterGui.DACMain.Panels.Inventory
Players.Player1.Character.Humanoid
```

## Tool Catalog

### Inspection / Read

| Tool | Purpose | Key Args |
|------|---------|----------|
| `get_place_info` | Place name, game ID, place ID | (none) |
| `get_services` | List all Roblox services | (none) |
| `get_instance_children` | Children and their class types | `instancePath` |
| `get_instance_properties` | All properties of an instance | `instancePath` |
| `search_objects` | Find instances by name/class | `query`, `className`, `searchPath` |
| `search_by_property` | Find instances by property value | `propertyName`, `propertyValue`, `searchPath` |
| `get_class_info` | Class hierarchy and properties | `className` |
| `get_file_tree` | Full hierarchy tree | `rootPath`, `maxDepth` |
| `get_project_structure` | Service-level overview | (none) |
| `get_selection` | Currently selected instances | (none) |
| `search_files` | Search file/instance names | `query` |

### Scripts

| Tool | Purpose | Key Args |
|------|---------|----------|
| `get_script_source` | Read script source (supports line ranges) | `instancePath`, `startLine?`, `endLine?` |
| `set_script_source` | Replace entire script source | `instancePath`, `source` |
| `edit_script_lines` | Replace specific line range | `instancePath`, `startLine`, `endLine`, `newContent` |
| `insert_script_lines` | Insert lines at position | `instancePath`, `afterLine`, `content` |
| `delete_script_lines` | Delete line range | `instancePath`, `startLine`, `endLine` |
| `grep_scripts` | Search across all scripts | `pattern`, `searchPath?` |

### Creation / Modification

| Tool | Purpose | Key Args |
|------|---------|----------|
| `create_object` | Create an instance | `className`, `parent`, `name?`, `properties?` |
| `mass_create_objects` | Create multiple instances | `objects[]` |
| `mass_create_objects_with_properties` | Batch create with props | `objects[]` |
| `delete_object` | Delete an instance | `instancePath` |
| `smart_duplicate` | Duplicate with offset | `instancePath`, `offset?` |
| `mass_duplicate` | Duplicate multiple | `instancePaths[]` |
| `set_property` | Set a single property | `instancePath`, `propertyName`, `propertyValue` |
| `mass_set_property` | Set property on many | `paths[]`, `propertyName`, `propertyValue` |
| `mass_get_property` | Get property from many | `paths[]`, `propertyName` |
| `set_calculated_property` | Set via expression | `instancePath`, `propertyName`, `expression` |
| `set_relative_property` | Set relative to current | `instancePath`, `propertyName`, `offset` |

### Attributes & Tags

| Tool | Purpose | Key Args |
|------|---------|----------|
| `get_attribute` / `get_attributes` | Read attributes | `instancePath`, `attributeName?` |
| `set_attribute` | Set attribute | `instancePath`, `attributeName`, `value` |
| `delete_attribute` | Delete attribute | `instancePath`, `attributeName` |
| `get_tags` / `add_tag` / `remove_tag` | Manage CollectionService tags | `instancePath`, `tag` |
| `get_tagged` | Find all instances with tag | `tag` |

### Code Execution

| Tool | Purpose | Key Args |
|------|---------|----------|
| `execute_luau` | Run Luau in plugin context | `code` |

`execute_luau` runs in the **plugin context** (not game context). Use `print()`/`warn()` for output. The return value is captured. Has full access to all services, instances, and APIs available to plugins.

### Playtesting

| Tool | Purpose | Key Args |
|------|---------|----------|
| `start_playtest` | Start a play session | `mode` (`"play"` or `"run"`) |
| `stop_playtest` | Stop the active playtest | (none) |
| `get_playtest_output` | Read playtest console output | `afterLine?` |

### Visual

| Tool | Purpose | Key Args |
|------|---------|----------|
| `capture_screenshot` | Screenshot the viewport (PNG) | (none) |

Requires EditableImage API enabled in Game Settings. Only works in Edit mode.

### Building

| Tool | Purpose | Key Args |
|------|---------|----------|
| `create_build` | Create a build group | `name`, `parts[]` |
| `get_build` / `generate_build` | Get/generate build | `name` |
| `export_build` / `import_build` | Export/import builds | `name`, `data` |
| `import_scene` | Import a scene description | `scene` |
| `list_library` | List available build library | (none) |
| `search_materials` | Search material options | `query` |

### Creator Store / Assets

| Tool | Purpose | Key Args |
|------|---------|----------|
| `search_assets` | Search marketplace | `assetType`, `query` |
| `get_asset_details` | Asset metadata | `assetId` |
| `get_asset_thumbnail` | Asset thumbnail (base64 PNG) | `assetId` |
| `insert_asset` | Insert asset into Studio | `assetId`, `parentPath?` |
| `preview_asset` | Preview without inserting | `assetId` |

Requires `ROBLOX_OPEN_CLOUD_API_KEY` environment variable.

### Undo/Redo

| Tool | Purpose |
|------|---------|
| `undo` | Undo last action |
| `redo` | Redo last undone action |

## Common Workflows

### Inspect the instance tree

```powershell
Invoke-RestMethod -Uri "http://localhost:58741/mcp/get_instance_children" -Method POST -ContentType "application/json" -Body '{"instancePath":"Workspace"}'
Invoke-RestMethod -Uri "http://localhost:58741/mcp/get_instance_children" -Method POST -ContentType "application/json" -Body '{"instancePath":"ReplicatedStorage"}'
```

### Read and modify a script

```powershell
Invoke-RestMethod -Uri "http://localhost:58741/mcp/get_script_source" -Method POST -ContentType "application/json" -Body '{"instancePath":"ServerScriptService.MainServer"}'

$body = @{ instancePath = "ServerScriptService.MainServer"; startLine = 10; endLine = 15; newContent = "-- replaced" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:58741/mcp/edit_script_lines" -Method POST -ContentType "application/json" -Body $body
```

### Create a Part with properties

```powershell
$body = @{
    className = "Part"
    parent = "Workspace"
    name = "MyPart"
    properties = @{ Size = @(4, 1, 4); Position = @(0, 10, 0); Anchored = $true; BrickColor = "Bright blue" }
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri "http://localhost:58741/mcp/create_object" -Method POST -ContentType "application/json" -Body $body
```

### Run a Luau query

```powershell
$body = @{ code = 'local count = 0; for _, v in game:GetDescendants() do if v:IsA("Part") then count += 1 end end; return "Parts: " .. count' } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:58741/mcp/execute_luau" -Method POST -ContentType "application/json" -Body $body
```

### Playtest cycle

```powershell
Invoke-RestMethod -Uri "http://localhost:58741/mcp/start_playtest" -Method POST -ContentType "application/json" -Body '{"mode":"play"}'
Start-Sleep -Seconds 5
Invoke-RestMethod -Uri "http://localhost:58741/mcp/get_playtest_output" -Method POST -ContentType "application/json" -Body '{}'
Invoke-RestMethod -Uri "http://localhost:58741/mcp/stop_playtest" -Method POST -ContentType "application/json" -Body '{}'
```

## Concurrency Rules

All agents share one MCP server (port 58741). Follow these rules:

1. **One playtest at a time.** Only one playtest can run in Studio. Check `get_playtest_output` before starting. If output is flowing, someone else is testing.
2. **No simultaneous edits to the same instance.** Last write wins. Coordinate via Paperclip task assignments.
3. **Screenshot only in Edit mode.** Stop any active playtest before capturing.
4. **Coordinate through Paperclip.** Use the task system to divide Studio work areas. Comment on your issue when you start/finish Studio modifications so other agents know.

## Verification

To confirm MCP access is working, run these in order:

```powershell
# 1. Health check — should show pluginConnected: true
Invoke-RestMethod -Uri "http://localhost:58741/health" -Method GET

# 2. Place info — should return place name and game ID
Invoke-RestMethod -Uri "http://localhost:58741/mcp/get_place_info" -Method POST -ContentType "application/json" -Body "{}"

# 3. Services — should return the list of Roblox services
Invoke-RestMethod -Uri "http://localhost:58741/mcp/get_services" -Method POST -ContentType "application/json" -Body "{}"

# 4. Luau execution — should return "Hello from MCP"
Invoke-RestMethod -Uri "http://localhost:58741/mcp/execute_luau" -Method POST -ContentType "application/json" -Body '{"code":"return \"Hello from MCP\""}'
```

If the health check fails, the Board's MCP server is not running. Report on your Paperclip issue and move on to non-Studio work.
