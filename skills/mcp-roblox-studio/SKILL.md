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

**Preferred:** Use Cursor's built-in `CallMcpTool` with `server: "user-robloxstudio-mcp"`.

**Fallback (via Shell):** Every tool is also available as a POST endpoint on `http://localhost:58741/mcp/<tool_name>`. Use Python (never PowerShell):

```python
import urllib.request, json

def mcp_call(tool, args=None):
    data = json.dumps(args or {}).encode()
    req = urllib.request.Request(
        f"http://localhost:58741/mcp/{tool}",
        data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    return json.loads(urllib.request.urlopen(req).read())

# No arguments
print(mcp_call("get_place_info"))

# With arguments
print(mcp_call("execute_luau", {"code": "return game.Workspace:GetChildren()"}))

# Complex arguments
print(mcp_call("get_instance_properties", {"instancePath": "Workspace", "propertyName": "Name"}))
```

The response is JSON with a `content` array. Each entry has `type` (usually `"text"`) and `text` (the result, often JSON-encoded).

### Health Check

Before calling tools, verify the MCP server is up and Studio is connected:

```python
import urllib.request, json
resp = json.loads(urllib.request.urlopen("http://localhost:58741/health").read())
print(resp)
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

```python
print(mcp_call("get_instance_children", {"instancePath": "Workspace"}))
print(mcp_call("get_instance_children", {"instancePath": "ReplicatedStorage"}))
```

### Read and modify a script

```python
print(mcp_call("get_script_source", {"instancePath": "ServerScriptService.MainServer"}))

mcp_call("edit_script_lines", {
    "instancePath": "ServerScriptService.MainServer",
    "startLine": 10, "endLine": 15, "newContent": "-- replaced"
})
```

### Create a Part with properties

```python
mcp_call("create_object", {
    "className": "Part",
    "parent": "Workspace",
    "name": "MyPart",
    "properties": {"Size": [4, 1, 4], "Position": [0, 10, 0], "Anchored": True, "BrickColor": "Bright blue"}
})
```

### Run a Luau query

```python
code = 'local count = 0; for _, v in game:GetDescendants() do if v:IsA("Part") then count += 1 end end; return "Parts: " .. count'
print(mcp_call("execute_luau", {"code": code}))
```

### Playtest cycle

```python
import time
mcp_call("start_playtest", {"mode": "play"})
time.sleep(5)
print(mcp_call("get_playtest_output"))
mcp_call("stop_playtest")
```

## Concurrency Rules

All agents share one MCP server (port 58741). Follow these rules:

1. **One playtest at a time.** Only one playtest can run in Studio. Check `get_playtest_output` before starting. If output is flowing, someone else is testing.
2. **No simultaneous edits to the same instance.** Last write wins. Coordinate via Paperclip task assignments.
3. **Screenshot only in Edit mode.** Stop any active playtest before capturing.
4. **Coordinate through Paperclip.** Use the task system to divide Studio work areas. Comment on your issue when you start/finish Studio modifications so other agents know.

## Verification

To confirm MCP access is working, run these in order:

```python
import urllib.request, json

def mcp_call(tool, args=None):
    data = json.dumps(args or {}).encode()
    req = urllib.request.Request(
        f"http://localhost:58741/mcp/{tool}",
        data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    return json.loads(urllib.request.urlopen(req).read())

# 1. Health check — should show pluginConnected: true
print(json.loads(urllib.request.urlopen("http://localhost:58741/health").read()))

# 2. Place info
print(mcp_call("get_place_info"))

# 3. Services
print(mcp_call("get_services"))

# 4. Luau execution — should return "Hello from MCP"
print(mcp_call("execute_luau", {"code": 'return "Hello from MCP"'}))
```

If the health check fails, the Board's MCP server is not running. Report on your Paperclip issue and move on to non-Studio work.
