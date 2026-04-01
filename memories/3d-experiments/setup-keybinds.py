"""Fix Pose Mode right-click to match Object Mode and Edit Mode:
- Single right-click = WASD walk navigation (from shared 3D View keymap)
- Double right-click = context menu

Also changes Armature edit mode to double-click context menu for consistency.

Run once: blender --python setup-keybinds.py
Then close Blender (it saves prefs automatically).
"""
import bpy

def _setup():
    kc = bpy.context.window_manager.keyconfigs.user

    fixed = []

    for km in kc.keymaps:
        # Pose mode: change context menu from single to double right-click
        if km.name == 'Pose':
            for kmi in km.keymap_items:
                if (kmi.idname == 'wm.call_menu' and
                    kmi.type == 'RIGHTMOUSE' and
                    kmi.value == 'PRESS'):
                    kmi.value = 'DOUBLE_CLICK'
                    fixed.append(f"Pose: context menu → DOUBLE_CLICK")

        # Armature edit mode: same fix
        if km.name == 'Armature':
            for kmi in km.keymap_items:
                if (kmi.idname == 'wm.call_menu' and
                    kmi.type == 'RIGHTMOUSE' and
                    kmi.value == 'PRESS'):
                    kmi.value = 'DOUBLE_CLICK'
                    fixed.append(f"Armature: context menu → DOUBLE_CLICK")

    if fixed:
        for f in fixed:
            print(f"  [FIXED] {f}")
        bpy.ops.wm.save_userpref()
        print("\nPreferences saved! Right-click WASD now works in Pose and Armature modes.")
    else:
        print("Nothing to fix — keybinds already correct.")

    print("\nYou can close this Blender window.")
    return None

bpy.app.timers.register(_setup, first_interval=0.5)
