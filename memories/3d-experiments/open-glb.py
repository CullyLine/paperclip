"""Open a GLB in Blender for visual inspection.

- Preserves user preferences (keybinds, themes)
- Defers import via timer (fixes Blender 5.x armature import crash)
- Sets viewport to Material Preview
- Switches to Pose Mode if armature is present
"""
import bpy
import sys

argv = sys.argv
if "--" in argv:
    argv = argv[argv.index("--") + 1:]
else:
    argv = []

if not argv:
    print("Usage: blender --python open-glb.py -- <file.glb>")
else:
    filepath = argv[0]

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    def _deferred_import():
        try:
            bpy.ops.import_scene.gltf(filepath=filepath)
            print(f"Imported: {filepath}")
        except Exception as e:
            print(f"Import error: {e}")
            return None

        # Set viewport to Material Preview
        for area in bpy.context.screen.areas:
            if area.type == 'VIEW_3D':
                for space in area.spaces:
                    if space.type == 'VIEW_3D':
                        space.shading.type = 'MATERIAL'

                # Frame the model
                for region in area.regions:
                    if region.type == 'WINDOW':
                        with bpy.context.temp_override(area=area, region=region):
                            bpy.ops.view3d.view_all()
                        break
                break

        # Switch to Pose Mode if there's an armature
        armature = None
        for obj in bpy.context.scene.objects:
            if obj.type == 'ARMATURE':
                armature = obj
                break

        if armature:
            bpy.ops.object.select_all(action='DESELECT')
            armature.select_set(True)
            bpy.context.view_layer.objects.active = armature

            # Make sure bones are visible
            armature.data.display_type = 'OCTAHEDRAL'
            armature.show_in_front = True

            bpy.ops.object.mode_set(mode='POSE')

            # Set active tool to Move (G shortcut equivalent)
            bpy.ops.wm.tool_set_by_id(name="builtin.move")

            print(f"Pose Mode: {armature.name} ({len(armature.data.bones)} bones) [Move tool active]")
        else:
            print("No armature found, staying in Object Mode")

        return None

    bpy.app.timers.register(_deferred_import, first_interval=0.1)
