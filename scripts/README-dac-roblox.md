# DAC Roblox Studio helpers (vehicles + camera)

These scripts support **agents and humans** when porting Drive A Car Simulator assets between two open Studio windows. **Luau cannot move instances across places**; use **clipboard** (or publish / Rojo) for the actual instance data.

## Scripts

| File | Purpose |
|------|---------|
| `roblox-studio-copy-paste.ps1` | Focus Studio, click **Explorer** (default), **Ctrl+C** / **Ctrl+V** between two PIDs. **Do not** use viewport center for copy — it selects whatever 3D object is under the cursor (e.g. a car) and copies that instead of your Explorer selection. |
| `roblox-studio-frame-selection.ps1` | Focus Studio, click **Explorer** (default), send **f** (frame selection). |
| `roblox-studio-capture-client.ps1` | PNG screenshot of the **client area**; paste into Cursor to pick **`-ExplorerClientX/Y`** coords. |
| `roblox-studio-copy-verify-loop.ps1` | Copy → **read clipboard** → retry (default 3) → paste. Uses `-Phase Copy` / `-Phase Paste` internally. |
| `verify-selection.luau` | MCP: **`Selection:Get()`** summary — use **before** copy to confirm the right instances are selected. |
| `roblox-dac-vehicle-grid.luau` | **SOURCE_PREP**: clone `CarModels` → `Workspace._DAC_VehicleGrid`, grid layout, **select folder**. **TARGET_ORGANIZE**: re-layout after paste. **FOCUS_CAMERA**: tween `CurrentCamera` if available. |
| `roblox-dac-pet-export.luau` | **SOURCE_PREP**: find pet `Model`s (`PetModels` / `ActivePets` in Workspace, ServerStorage, ReplicatedStorage + name heuristics), clone → `Workspace._DAC_PetExportGrid`, tight grid, **select folder**. **TARGET_ORGANIZE**: re-grid after paste. Then **copy-verify-loop -SkipExplorerClick** + MCP `Selection:Set(workspace)` on target. |
| `roblox-dac-egg-export.luau` | Same pattern for eggs: `EggModels` / `Eggs` folders + names containing `egg` + EggConfig ids → `Workspace._DAC_EggExportGrid`, **8 stud** grid (`GRID_SPACING`). |
| `roblox-dac-meta-grid.luau` | **After** the three grids exist on the new place: arranges `_DAC_EggExportGrid`, `_DAC_PetExportGrid`, `_DAC_VehicleGrid` into one **meta** layout (row along X/Z or 2×2). Uses `Model:TranslateBy`. Edit `META_SPACING` / `LAYOUT` / `ANCHOR` at top. Re-run if you run `TARGET_ORGANIZE` on any single grid again (that resets that grid’s world origin). |
| `roblox-dac-promote-templates.luau` | **After** copy/layout: moves models from Workspace `_DAC_*` folders into **`ReplicatedStorage.EggModels`**, **`ReplicatedStorage.PetModels`**, **`ServerStorage.CarModels`**, and ensures **`Workspace.ActivePets`**. If a model name already exists in the destination, the **incoming** copy is destroyed (no duplicate). Destroys empty `_DAC_*` folders. Client code should load pet templates from **ReplicatedStorage.PetModels** (see DAC `PetController`). |
| `roblox-dac-dedupe-models.luau` | One-time cleanup: removes suffixed duplicates (`name_2`, `name_3`, …) when **`name`** already exists in the same folder (typical after an old merge). Targets **PetModels**, **EggModels**, **CarModels** under RS/SS. |
| `focus-cursor.ps1` | After long automation, **foreground Cursor** so you can read the chat. |

## One-shot: all vehicles as one folder

1. **Old place** (source): In MCP `execute_luau`, run the contents of `roblox-dac-vehicle-grid.luau` with `STEP = "SOURCE_PREP"`.  
   - Expect: `Workspace._DAC_VehicleGrid` with every `Model` under `ServerStorage.CarModels` or `Workspace.CarModels`, **folder selected**.

2. **Clipboard**:  
   `.\roblox-studio-copy-paste.ps1 -SourcePid <OLD> -TargetPid <NEW>`

3. **New place** (target): Set `STEP = "TARGET_ORGANIZE"` and run once (fixes positions if paste shifted them).  
   - Then set `STEP = "FOCUS_CAMERA"` and run **or** use `roblox-studio-frame-selection.ps1 -ProcessId <NEW>`.

4. **If `FOCUS_CAMERA` returns `NO_CAMERA`**: Studio’s edit viewport sometimes has no `workspace.CurrentCamera` in plugin context — rely on **frame-selection.ps1** (step 3).

## Moving to `ServerStorage.CarModels` (optional)

After the grid looks good under `Workspace._DAC_VehicleGrid`, you can parent the folder or individual models into `ServerStorage.CarModels` in Explorer (or add a small Luau that reparents — watch for duplicates).

## PIDs

```powershell
.\roblox-studio-copy-paste.ps1 -ListStudios
```

## Limits

- Clipboard automation is **fragile**; if paste fails, copy manually or paste one model at a time.
- **MeshId** cannot be rebuilt from code alone on the target place; clipboard carries instances.

## Copy → verify clipboard → retry (up to 3) → paste

`roblox-studio-copy-verify-loop.ps1` runs **Phase Copy** (`roblox-studio-copy-paste.ps1 -Phase Copy`), then **reads the Windows clipboard** (text formats + optional opaque/binary formats), and **retries** up to **3** times if verification fails. On success it runs **Phase Paste**.

**If you used MCP `Selection:Set` first:** use **`-SkipExplorerClick`**. Otherwise the script **clicks** the Explorer at your chosen coordinates — that **selects a row** (often **SpawnLocation** or a random **Model**) and **overwrites** your MCP selection before Ctrl+C. **`-SkipExplorerClick`** sets **`-ClickRegion None`**: only foreground + Ctrl+C / Ctrl+V, so **MCP’s selection is preserved**.

On the **target** place, select **Workspace** in Explorer (MCP `Selection:Set({ workspace })`) before paste if paste should land under Workspace — with **SkipExplorerClick** we do not click the target tree.

- **`-ExpectedClipboardSubstring`** — if Roblox puts a string on the clipboard, require it (e.g. part of an instance name). Often **empty** for instance copies.
- **`-AllowOpaqueClipboard`** (default) — if there is **no** plain text but **clipboard has formats**, treat as OK (typical for Roblox **instance** data).
- **`-DisallowOpaqueClipboard`** — stricter: require readable text (often **fails** for Roblox).

**Selection is still the source of truth:** before trusting the clipboard, run **`verify-selection.luau`** via MCP `execute_luau` — it prints what Studio has **selected** (names + class). That does **not** read the OS clipboard; it reads **`Selection:Get()`**.

**Explorer multi-select (select all you need, unselect the rest)** is **not** fully scripted here — use MCP `Selection:Set({...})` with the exact instances, or manual Ctrl/Shift+click. Future work could add **SendKeys** sequences per layout.

## Screenshot + “where is Explorer?” (Cursor / vision)

Heuristic clicks can still miss. **Capture** matches what you see:

1. `.\roblox-studio-capture-client.ps1 -ProcessId <PID>` → writes e.g. `%TEMP%\roblox-studio-client-<pid>.png`.
2. **Paste that PNG into Cursor** and ask: *“Give me client pixel (x,y) for a safe click in the Explorer tree (not the viewport).”*
3. Run copy with **explicit** coords (same coordinate system as the image — top-left of PNG = 0,0):

```powershell
.\roblox-studio-copy-paste.ps1 -SourcePid <OLD> -TargetPid <NEW> `
  -ExplorerClientX 42 -ExplorerClientY 310
```

**Note:** An automated script in this repo does **not** run vision on the PNG by itself; **you** (or the Cursor agent in chat with the image) supply the numbers.

## Troubleshooting

- **Wrong thing pasted / copy seems random** — Clicking the **center** of the window selects the **viewport**. The script uses **`-ClickRegion Explorer`**, which clicks a **small number of pixels from the left client edge** (not a % of full width — that was still hitting the 3D view on many layouts). Defaults: **`-ExplorerPixelsFromLeft 28`** and **`-ExplorerFracY 0.48`**. If Explorer is on the **right**: **`-ExplorerOnRight -ExplorerPixelsFromRight 140`**. Nudge **`-ExplorerPixelsFromLeft`** (e.g. `18`–`40`) until the click lands on the tree.
- **`_DAC_VehicleGrid` missing on the new place after the PowerShell paste** — Studio did not receive the clipboard. Do **manual** Ctrl+C with the folder selected in the **source** Studio, switch to **target** Studio, click **Workspace** in Explorer, Ctrl+V. Then run `TARGET_ORGANIZE`.
- **Camera script says `NO_CAMERA`** — Use `roblox-studio-frame-selection.ps1` (sends **f**) while the folder is selected.
