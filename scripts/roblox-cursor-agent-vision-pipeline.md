# Cursor agent: screenshot → vision → click (no manual pixel hunting)

This is the **“you read the screenshot and click”** flow. The **human does not** type coordinates.

## What runs where

1. **Luau (MCP `execute_luau`)** — select what to copy, e.g. `Workspace._DAC_VehicleGrid`:
   ```lua
   game:GetService("Selection"):Set({ workspace:FindFirstChild("_DAC_VehicleGrid") })
   ```

2. **PowerShell** — capture **only** the Roblox Studio **client** (not whatever window is on top of it):
   ```powershell
   .\scripts\roblox-cursor-agent-explorer-click.ps1 -ProcessId <SOURCE_PID>
   ```
   Output: `scripts/.tmp/studio-client-latest.png` (gitignored).

3. **Cursor agent** — **`read_file`** on that PNG (vision). Pick a point **inside the Explorer tree** (not the 3D viewport). Convert to **fractions** of image width/height:
   - `ExplorerClientFracX = clickX / imageWidth`
   - `ExplorerClientFracY = clickY / imageHeight`  
   Same as **client** coords because the PNG is a 1:1 capture of the client.

4. **PowerShell** — copy/paste with those fractions (works for **different** source/target window sizes):
   ```powershell
   .\scripts\roblox-studio-copy-paste.ps1 -SourcePid <OLD> -TargetPid <NEW> `
     -ExplorerClientFracX 0.82 -ExplorerClientFracY 0.30
   ```
   Replace fractions with what vision returned.

## Why capture uses `PrintWindow`

`CopyFromScreen` grabs **whatever pixels are visible on the monitor** at that rectangle — if **Cursor** is on top of Studio, you get **Cursor**, not Studio. The capture script **foregrounds** Studio and uses **`PrintWindow`** (with fallback) so the PNG matches the **Studio client** for vision.

## One-shot prompt you can paste to the agent

> Run `roblox-cursor-agent-explorer-click.ps1` for PID \<source\>, **read** `scripts/.tmp/studio-client-latest.png`, choose a safe Explorer-tree click, compute **ExplorerClientFracX/Y**, ensure `_DAC_VehicleGrid` is selected via MCP, then run `roblox-studio-copy-paste.ps1` with those fractions and the correct source/target PIDs.
