"""Dump ALL right-mouse and walk/fly entries from default keyconfig."""
import bpy

kc = bpy.context.window_manager.keyconfigs.default

for km in kc.keymaps:
    for kmi in km.keymap_items:
        if not kmi.active:
            continue
        if kmi.type == 'RIGHTMOUSE':
            print(f"[{km.name}] {kmi.idname} | type={kmi.type} value={kmi.value} "
                  f"ctrl={kmi.ctrl} shift={kmi.shift} alt={kmi.alt} "
                  f"key_modifier={kmi.key_modifier}")
        if 'walk' in kmi.idname.lower() or 'fly' in kmi.idname.lower():
            print(f"[{km.name}] {kmi.idname} | type={kmi.type} value={kmi.value} "
                  f"ctrl={kmi.ctrl} shift={kmi.shift} alt={kmi.alt} "
                  f"key_modifier={kmi.key_modifier}")
