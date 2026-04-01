# Blender Configuration Backup

Backed-up Blender user preferences and startup file. These contain custom keybinds,
themes, and workspace settings.

## Key Customizations

- **Right-click = WASD walk navigation** (all modes: Object, Edit, Pose, Armature)
- **Double right-click = context menu** (remapped from single right-click)
- **Navigation mode = Walk** (not Fly)

## Files

| File | Purpose |
|------|---------|
| `userpref.blend` | User preferences (keybinds, themes, input settings) |
| `startup.blend` | Default scene layout and workspace |
| `restore-blender-prefs.py` | Restore script for any Blender version |

## Restore

```bash
python restore-blender-prefs.py        # Blender 5.1 (default)
python restore-blender-prefs.py 5.2    # future versions
```

## Blender Location

Steam install: `F:\SteamLibrary\steamapps\common\Blender\blender.exe`

**Always use the Steam install** — it has the user's keybinds and preferences.
Do NOT use `F:\CODE STUFF\tools\blender-5.0.1-windows-x64\blender.exe` (standalone,
factory defaults only).

## Opening GLB Models

Use `memories/3d-experiments/open-glb.py`:

```bash
blender --python open-glb.py -- <file.glb>
```

This script:
- Preserves user preferences (no factory reset)
- Defers import via timer (fixes Blender 5.x armature crash)
- Sets viewport to Material Preview
- Switches to Pose Mode with Move tool active
- Auto-frames the model
