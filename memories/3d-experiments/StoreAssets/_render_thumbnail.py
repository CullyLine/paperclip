"""Blender headless: render side-by-side thumbnail of Tung Tung + Bat.

Usage:
  blender --background --python _render_thumbnail.py
"""
import bpy, os, math

out_dir = r"F:\CODE STUFF\Paperclip\memories\3d-experiments\StoreAssets"
char_path = os.path.join(out_dir, "StoreTungTung-tpose-FINAL.glb")
bat_path = os.path.join(out_dir, "StoreTungTung-club.glb")
thumb_path = os.path.join(out_dir, "StoreTungTung-thumbnail.png")

bpy.ops.wm.read_factory_settings(use_empty=True)

print("Importing character...", flush=True)
bpy.ops.import_scene.gltf(filepath=char_path)

char_objects = list(bpy.context.selected_objects)
char_meshes = [o for o in char_objects if o.type == 'MESH']
char_arms = [o for o in char_objects if o.type == 'ARMATURE']

char_min_x = float('inf')
char_max_x = float('-inf')
char_min_y = float('inf')
char_max_y = float('-inf')
char_min_z = float('inf')
char_max_z = float('-inf')

for obj in char_meshes:
    for v in obj.data.vertices:
        co = obj.matrix_world @ v.co
        char_min_x = min(char_min_x, co.x)
        char_max_x = max(char_max_x, co.x)
        char_min_y = min(char_min_y, co.y)
        char_max_y = max(char_max_y, co.y)
        char_min_z = min(char_min_z, co.z)
        char_max_z = max(char_max_z, co.z)

char_width = char_max_x - char_min_x
char_height = char_max_z - char_min_z
char_center_x = (char_min_x + char_max_x) / 2
char_center_z = (char_min_z + char_max_z) / 2

print(f"Character bounds: width={char_width:.3f}, height={char_height:.3f}", flush=True)

shift_x = -char_width * 0.25
for obj in char_objects:
    if not obj.parent:
        obj.location.x += shift_x

print("Importing bat...", flush=True)
bpy.ops.import_scene.gltf(filepath=bat_path)

bat_objects = [o for o in bpy.context.selected_objects]
bat_meshes = [o for o in bat_objects if o.type == 'MESH']

bat_min_z = float('inf')
bat_max_z = float('-inf')
bat_min_x = float('inf')
bat_max_x = float('-inf')
for obj in bat_meshes:
    for v in obj.data.vertices:
        co = obj.matrix_world @ v.co
        bat_min_z = min(bat_min_z, co.z)
        bat_max_z = max(bat_max_z, co.z)
        bat_min_x = min(bat_min_x, co.x)
        bat_max_x = max(bat_max_x, co.x)

bat_height = bat_max_z - bat_min_z
bat_width = bat_max_x - bat_min_x

scale_factor = (char_height * 0.7) / max(bat_height, 0.001)
bat_place_x = char_width * 0.35

for obj in bat_objects:
    if not obj.parent:
        obj.scale = (scale_factor, scale_factor, scale_factor)
        obj.location.x = bat_place_x
        obj.location.z = char_center_z * 0.3
        obj.rotation_euler = (0, math.radians(15), 0)

bpy.context.view_layer.update()
print(f"Bat scaled {scale_factor:.2f}x, placed at x={bat_place_x:.3f}", flush=True)

scene_center_x = (shift_x + bat_place_x) / 2
scene_center_z = char_center_z

cam = bpy.data.cameras.new("ThumbCam")
cam.type = 'PERSP'
cam.lens = 50
cam_obj = bpy.data.objects.new("ThumbCam", cam)
bpy.context.collection.objects.link(cam_obj)

cam_distance = max(char_height, char_width + bat_width * scale_factor) * 2.1
cam_obj.location = (scene_center_x, -cam_distance, scene_center_z)
cam_obj.rotation_euler = (math.radians(90), 0, 0)
bpy.context.scene.camera = cam_obj

bpy.context.scene.world = bpy.data.worlds.new("ThumbWorld")
bpy.context.scene.world.use_nodes = True
bg_node = bpy.context.scene.world.node_tree.nodes.get("Background")
if bg_node:
    bg_node.inputs['Color'].default_value = (0.25, 0.25, 0.28, 1.0)
    bg_node.inputs['Strength'].default_value = 1.0

def add_light(name, light_type, energy, location, size=0.5):
    light = bpy.data.lights.new(name, light_type)
    light.energy = energy
    if hasattr(light, 'shadow_soft_size'):
        light.shadow_soft_size = size
    obj = bpy.data.objects.new(name, light)
    obj.location = location
    bpy.context.collection.objects.link(obj)
    return obj

key = add_light("Key", 'AREA', 200, (scene_center_x + 1, -cam_distance * 0.5, scene_center_z + char_height * 0.8))
key.data.size = 2.0
key.rotation_euler = (math.radians(60), 0, math.radians(20))

fill = add_light("Fill", 'AREA', 80, (scene_center_x - 1.5, -cam_distance * 0.6, scene_center_z + char_height * 0.3))
fill.data.size = 3.0
fill.rotation_euler = (math.radians(70), 0, math.radians(-30))

rim = add_light("Rim", 'AREA', 120, (scene_center_x, cam_distance * 0.3, scene_center_z + char_height * 0.6))
rim.data.size = 2.0
rim.rotation_euler = (math.radians(110), 0, 0)

bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.device = 'CPU'
bpy.context.scene.cycles.samples = 128
bpy.context.scene.render.resolution_x = 1024
bpy.context.scene.render.resolution_y = 1024
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.film_transparent = False
bpy.context.scene.render.image_settings.file_format = 'PNG'
bpy.context.scene.render.filepath = thumb_path

print("Rendering thumbnail...", flush=True)
bpy.ops.render.render(write_still=True)

size_kb = os.path.getsize(thumb_path) // 1024
print(f"Saved: {thumb_path} ({size_kb} KB)", flush=True)
