import bpy
import math
import os
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)

ASSET_ROOT = r"C:\Users\lineb\OneDrive\Desktop\Assets\LowPolyHumbleBundle\lowpolycompletecollectionpolyworks\Meshes"
RENDER_PATH = r"F:\CODE STUFF\Paperclip\village-render.png"

# ============================================================
# SCENE DATA — all placements defined here for easy iteration
# ============================================================

BUILDINGS = [
    {"asset": "Buildings/Building_Human_Town_Hall_Blue_01.fbx",
     "pos": (0, 10, 0), "rot": (0, 0, 0), "scale": 0.45},
    {"asset": "Buildings/Building_Human_Smith_Blue_01.fbx",
     "pos": (-12, 8, 0), "rot": (0, 0, 45), "scale": 0.45},
    {"asset": "Buildings/Building_Windmill_Tower_01.fbx",
     "pos": (14, 12, 0), "rot": (0, 0, -10), "scale": 0.45},
    {"asset": "Buildings/Building_Windmill_Blades_Sails_01.fbx",
     "pos": (14, 10.2, 5.8), "rot": (0, 0, -10), "scale": 0.45},
    {"asset": "Buildings/Building_Viking_01.fbx",
     "pos": (6, 18, 0), "rot": (0, 0, 170), "scale": 0.45},
]

VILLAGE_TREES = [
    {"asset": "Vegetation/Vegetation_Tree_Apple_01.fbx",
     "pos": (-6, 8, 0), "scale": 1.2},
    {"asset": "Vegetation/Vegetation_Tree_Cherry_Blossom_01.fbx",
     "pos": (7, 6, 0), "scale": 0.4},
]

VILLAGE_BUSHES = [
    {"asset": "Vegetation/Vegetation_Bush_Large_01.fbx", "pos": (-8, 5, 0)},
    {"asset": "Vegetation/Vegetation_Bush_Large_02.fbx", "pos": (4, 5, 0)},
    {"asset": "Vegetation/Vegetation_Bush_Large_03.fbx", "pos": (10, 6, 0)},
    {"asset": "Vegetation/Vegetation_Bush_Small_01.fbx", "pos": (-10, 12, 0)},
    {"asset": "Vegetation/Vegetation_Bush_Small_02.fbx", "pos": (10, 8, 0)},
]

VILLAGE_DETAIL = [
    {"asset": "Vegetation/Vegetation_Fern_01.fbx", "pos": (-6, -2, 0)},
    {"asset": "Vegetation/Vegetation_Fern_02.fbx", "pos": (8, 2, 0)},
    {"asset": "Vegetation/Vegetation_Fern_Large_01.fbx", "pos": (-10, 2, 0)},
    {"asset": "Vegetation/Vegetation_Flower_Daisy_01.fbx", "pos": (-3, 5, 0)},
    {"asset": "Vegetation/Vegetation_Flower_Tulip_01.fbx", "pos": (5, 4, 0)},
    {"asset": "Vegetation/Vegetation_Flower_Sunflower_01.fbx", "pos": (-7, 16.5, 0)},
    {"asset": "Vegetation/Vegetation_Flower_Sunflower_02.fbx", "pos": (-7.5, 17, 0)},
    {"asset": "Vegetation/Vegetation_Tree_Stump_01.fbx", "pos": (-8, 3, 0)},
    {"asset": "Vegetation/Vegetation_Tree_Stump_03.fbx", "pos": (14, -6, 0)},
    {"asset": "Vegetation/Vegetation_Tree_Trunk_Fallen_01.fbx",
     "pos": (-16, -6, 0), "rot": (0, 0, 25)},
    {"asset": "Vegetation/Vegetation_Mushroom_Red_01.fbx", "pos": (-7.5, 2.5, 0)},
    {"asset": "Vegetation/Vegetation_Mushroom_Blue_01.fbx", "pos": (-8.5, 3.5, 0)},
]

GRASS_POSITIONS = [(-3,3), (5,3), (8,-4), (-6,-5), (12,4), (-2,-8),
                   (15, 8), (-5, 14), (3, 16), (-12, -2)]

PROPS = [
    {"asset": "Props General/Prop_Well_01.fbx", "pos": (5, 8, 0)},
    {"asset": "Props General/Prop_Barrel_Closed_01.fbx", "pos": (-14, 10, 0)},
    {"asset": "Props General/Prop_Barrel_Wine_01.fbx", "pos": (-14.5, 10.5, 0)},
    {"asset": "Props General/Prop_Crate_Closed_01.fbx", "pos": (-13.5, 11, 0)},
    {"asset": "Props General/Prop_Anvil_01.fbx", "pos": (-10, 10, 0)},
    {"asset": "Props General/Prop_Bag_Grain_01.fbx", "pos": (-13, 10.5, 0)},
    # Lantern posts just outside the fence ends, facing inward along the path
    {"asset": "Props General/Prop_Lantern_Post_01.fbx",
     "pos": (-3.2, 2.5, 0), "rot": (0, 0, 180)},
    {"asset": "Props General/Prop_Lantern_Post_01.fbx",
     "pos": (3.2, 2.5, 0), "rot": (0, 0, 0)},
    {"asset": "Props General/Prop_Farm_Plot_01.fbx", "pos": (-6, 16, 0)},
    {"asset": "Props General/Prop_Scarecrow_01.fbx", "pos": (-6, 17, 0)},
    {"asset": "Props General/Prop_Sign_Wooden_Blank_01.fbx",
     "pos": (-2, 0, 0), "rot": (0, 0, -20)},
    # Campfire: timber logs base + fire on top + rock ring
    {"asset": "Props General/Prop_Timber_Fire_01.fbx", "pos": (2, -8, 0)},
    {"asset": "Props General/Prop_Fire_Static_01.fbx", "pos": (2, -8, 0.3)},
    # Boat beached on the south shore of the pond, not floating in the middle
    {"asset": "Props General/Prop_Row_Boat_01.fbx",
     "pos": (-9, -5.5, 0), "rot": (0, 0, 10)},
    # Tent closer to campfire for a proper campsite
    {"asset": "Props General/Prop_Tent_01.fbx",
     "pos": (5, -10, 0), "rot": (0, 0, -30)},
    {"asset": "Props General/Prop_Bucket_01.fbx", "pos": (6, 9, 0)},
    {"asset": "Props General/Prop_Trough_Water_01.fbx", "pos": (-5, 15, 0)},
]

# Campfire rock ring
CAMPFIRE_ROCKS = [
    {"asset": "Rocks/Rock_Small_01.fbx", "pos": (1.2, -7.4, 0), "scale": 0.3},
    {"asset": "Rocks/Rock_Small_02.fbx", "pos": (2.8, -7.4, 0), "scale": 0.3},
    {"asset": "Rocks/Rock_Small_03.fbx", "pos": (1.2, -8.6, 0), "scale": 0.3},
    {"asset": "Rocks/Rock_Small_01.fbx", "pos": (2.8, -8.6, 0), "scale": 0.3},
    {"asset": "Rocks/Rock_Small_02.fbx", "pos": (1.0, -8.0, 0), "scale": 0.25},
    {"asset": "Rocks/Rock_Small_03.fbx", "pos": (3.0, -8.0, 0), "scale": 0.25},
]

# Fences with gap in the middle for the path entrance
FENCES = [
    {"pos": (x * 1.2, 3, 0)} for x in [-6, -5, -4, -3, 3, 4, 5, 6]
]

ROCKS = [
    {"asset": "Rocks/Rock_Medium_01.fbx", "pos": (-12, -4, 0), "rot": (0, 0, 20)},
    {"asset": "Rocks/Rock_Medium_02.fbx", "pos": (14, 2, 0), "rot": (0, 0, 55)},
    {"asset": "Rocks/Rock_Small_01.fbx", "pos": (-6, -6, 0)},
    {"asset": "Rocks/Rock_Small_02.fbx", "pos": (6, -6, 0)},
    {"asset": "Rocks/Rock_Small_03.fbx", "pos": (10, -3, 0)},
    {"asset": "Rocks/Rock_Boulder_01.fbx", "pos": (16, -2, 0), "scale": 0.5},
]

# ============================================================
# BARRIER RING — thick, impenetrable forest wall
# ============================================================
# Generated procedurally: 3-4 rows deep, staggered trees + bushes
# Only opening is the south path entrance

import random
_rng = random.Random(42)

TREE_ASSETS = [
    "Vegetation/Vegetation_Tree_Pine_01.fbx",
    "Vegetation/Vegetation_Tree_Pine_02.fbx",
    "Vegetation/Vegetation_Tree_Pine_03.fbx",
    "Vegetation/Vegetation_Tree_Pine_04.fbx",
    "Vegetation/Vegetation_Tree_Pine_05.fbx",
    "Vegetation/Vegetation_Tree_Pine_06.fbx",
    "Vegetation/Vegetation_Tree_Pine_07.fbx",
    "Vegetation/Vegetation_Tree_Common_01.fbx",
    "Vegetation/Vegetation_Tree_Common_02.fbx",
    "Vegetation/Vegetation_Tree_Common_03.fbx",
    "Vegetation/Vegetation_Tree_Common_04.fbx",
    "Vegetation/Vegetation_Tree_Common_05.fbx",
]

BUSH_ASSETS = [
    "Vegetation/Vegetation_Bush_Large_01.fbx",
    "Vegetation/Vegetation_Bush_Large_02.fbx",
    "Vegetation/Vegetation_Bush_Large_03.fbx",
]

def _rand_tree():
    return _rng.choice(TREE_ASSETS)

def _rand_bush():
    return _rng.choice(BUSH_ASSETS)

def _jitter(v, amount=1.0):
    return v + _rng.uniform(-amount, amount)

def _make_wall_segment(x_center, y_start, y_end, y_step, depth_offsets, horizontal):
    """Generate a thick wall of trees along one axis."""
    items = []
    y = y_start
    while y <= y_end:
        for dx in depth_offsets:
            jx = _jitter(dx, 0.8)
            jy = _jitter(0, 0.6)
            s = _rng.uniform(1.6, 2.4)
            r = _rng.uniform(-40, 40)
            if horizontal:
                items.append({"asset": _rand_tree(),
                    "pos": (x_center + jx, y + jy, 0), "scale": s, "rot": (0, 0, r)})
            else:
                items.append({"asset": _rand_tree(),
                    "pos": (y + jy, x_center + jx, 0), "scale": s, "rot": (0, 0, r)})
        # Bushes between trees to fill low gaps
        if _rng.random() > 0.3:
            bx = _jitter(depth_offsets[len(depth_offsets)//2], 1.5)
            if horizontal:
                items.append({"asset": _rand_bush(),
                    "pos": (x_center + bx, y + _rng.uniform(-1, 1), 0),
                    "scale": _rng.uniform(1.2, 2.0)})
            else:
                items.append({"asset": _rand_bush(),
                    "pos": (y + _rng.uniform(-1, 1), x_center + bx, 0),
                    "scale": _rng.uniform(1.2, 2.0)})
        y += y_step
    return items

# West wall: 4 rows deep, X = -20 to -32
BARRIER_WEST = _make_wall_segment(
    x_center=-26, y_start=-14, y_end=28, y_step=3.5,
    depth_offsets=[-4, -1.5, 1.5, 4], horizontal=True)

# East wall: 4 rows deep, X = 20 to 32
BARRIER_EAST = _make_wall_segment(
    x_center=26, y_start=-14, y_end=28, y_step=3.5,
    depth_offsets=[-4, -1.5, 1.5, 4], horizontal=True)

# North wall: 4 rows deep, Y = 24 to 36
BARRIER_NORTH = _make_wall_segment(
    x_center=30, y_start=-26, y_end=26, y_step=3.5,
    depth_offsets=[-4, -1.5, 1.5, 4], horizontal=False)

# North hills behind the tree wall
BARRIER_HILLS = [
    {"asset": "Terrain/Terrain_Hill_Round_Grass_01.fbx",
     "pos": (-12, 36, -2), "scale": 0.6},
    {"asset": "Terrain/Terrain_Hill_Round_Grass_02.fbx",
     "pos": (12, 38, -2), "scale": 0.55},
    {"asset": "Terrain/Terrain_Hill_Round_Grass_03.fbx",
     "pos": (0, 40, -3), "scale": 0.7},
    {"asset": "Terrain/Terrain_Mound_Grass_01.fbx",
     "pos": (-24, 34, -1), "scale": 0.5},
    {"asset": "Terrain/Terrain_Mound_Grass_02.fbx",
     "pos": (26, 34, -1), "scale": 0.5},
]

# South wall: thick on both sides but leaving a ~6-unit gap for the path entrance
BARRIER_SOUTH_WEST = []
BARRIER_SOUTH_EAST = []

# Dense left side of entrance (X = -6 to -30)
for row_y in [-14, -17, -20, -23]:
    x = -8
    while x >= -30:
        s = _rng.uniform(1.6, 2.2)
        r = _rng.uniform(-35, 35)
        BARRIER_SOUTH_WEST.append({"asset": _rand_tree(),
            "pos": (_jitter(x, 0.8), _jitter(row_y, 0.6), 0),
            "scale": s, "rot": (0, 0, r)})
        if _rng.random() > 0.4:
            BARRIER_SOUTH_WEST.append({"asset": _rand_bush(),
                "pos": (_jitter(x + 1.5, 0.5), _jitter(row_y, 0.5), 0),
                "scale": _rng.uniform(1.2, 1.8)})
        x -= _rng.uniform(3.0, 4.5)

# Dense right side of entrance (X = 6 to 30)
for row_y in [-14, -17, -20, -23]:
    x = 8
    while x <= 30:
        s = _rng.uniform(1.6, 2.2)
        r = _rng.uniform(-35, 35)
        BARRIER_SOUTH_EAST.append({"asset": _rand_tree(),
            "pos": (_jitter(x, 0.8), _jitter(row_y, 0.6), 0),
            "scale": s, "rot": (0, 0, r)})
        if _rng.random() > 0.4:
            BARRIER_SOUTH_EAST.append({"asset": _rand_bush(),
                "pos": (_jitter(x + 1.5, 0.5), _jitter(row_y, 0.5), 0),
                "scale": _rng.uniform(1.2, 1.8)})
        x += _rng.uniform(3.0, 4.5)

# Rocks flanking the entrance
BARRIER_ENTRANCE_ROCKS = [
    {"asset": "Rocks/Rock_Large_01.fbx",
     "pos": (-6, -13, 0), "scale": 0.3, "rot": (0, 0, 20)},
    {"asset": "Rocks/Rock_Large_02.fbx",
     "pos": (6, -13, 0), "scale": 0.25, "rot": (0, 0, -30)},
    {"asset": "Rocks/Rock_Medium_01.fbx",
     "pos": (-5, -15, 0), "scale": 0.8, "rot": (0, 0, 45)},
    {"asset": "Rocks/Rock_Medium_02.fbx",
     "pos": (5, -15, 0), "scale": 0.8, "rot": (0, 0, -45)},
]

ALL_BARRIER = (BARRIER_WEST + BARRIER_EAST + BARRIER_NORTH +
               BARRIER_HILLS + BARRIER_SOUTH_WEST + BARRIER_SOUTH_EAST +
               BARRIER_ENTRANCE_ROCKS)

# ============================================================
# COMPOSE FUNCTION
# ============================================================

def place(filepath, loc=(0,0,0), rot=(0,0,0), scale=(1,1,1)):
    full_path = os.path.join(ASSET_ROOT, filepath) if not os.path.isabs(filepath) else filepath
    bpy.ops.import_scene.fbx(filepath=full_path, global_scale=1.0)
    for obj in bpy.context.selected_objects:
        obj.location = loc
        obj.rotation_euler = (
            obj.rotation_euler.x + math.radians(rot[0]),
            obj.rotation_euler.y + math.radians(rot[1]),
            obj.rotation_euler.z + math.radians(rot[2]),
        )
        obj.scale = (obj.scale.x * scale[0], obj.scale.y * scale[1], obj.scale.z * scale[2])

def place_item(item):
    s = item.get("scale", 1.0)
    scale = (s, s, s) if isinstance(s, (int, float)) else s
    place(
        item["asset"],
        loc=item.get("pos", (0,0,0)),
        rot=item.get("rot", (0,0,0)),
        scale=scale,
    )

def make_material(name, color, roughness=0.8):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def compose():
    # Ground
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 4, -0.05))
    ground = bpy.context.active_object
    ground.name = "Ground"
    ground.data.materials.append(make_material("GroundMat", (0.3, 0.5, 0.2, 1.0), 0.9))

    # Dirt path
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 4, -0.02))
    path = bpy.context.active_object
    path.name = "Path"
    path.scale = (1, 4, 1)
    path.data.materials.append(make_material("PathMat", (0.4, 0.28, 0.15, 1.0), 1.0))

    # Pond
    bpy.ops.mesh.primitive_circle_add(vertices=32, radius=4, fill_type='NGON', location=(-8, -2, -0.03))
    pond = bpy.context.active_object
    pond.name = "Pond"
    pond.scale = (1.3, 0.8, 1)
    pond.data.materials.append(make_material("WaterMat", (0.15, 0.3, 0.5, 1.0), 0.05))

    # Bridge spanning the east edge of the pond, connecting village to pond area
    place("Bridges/Prop_Bridge_Stone_01.fbx", loc=(-4, -2, 0.1), rot=(0, 0, 90), scale=(0.35, 0.2, 0.2))

    # Buildings
    for item in BUILDINGS:
        place_item(item)

    # Village trees
    for item in VILLAGE_TREES:
        place_item(item)

    # Village bushes
    for item in VILLAGE_BUSHES:
        place_item(item)

    # Village detail (ferns, flowers, stumps, mushrooms)
    for item in VILLAGE_DETAIL:
        place_item(item)

    # Grass clumps
    for gx, gy in GRASS_POSITIONS:
        place("Vegetation/Vegetation_Grass_3D_Clump_01.fbx", loc=(gx, gy, 0))

    # Props
    for item in PROPS:
        place_item(item)

    # Fences
    for fence in FENCES:
        place("Fences/Prop_Fence_Wooden_Small_01.fbx", loc=fence["pos"])

    # Rocks
    for item in ROCKS:
        place_item(item)

    # Campfire rock ring
    for item in CAMPFIRE_ROCKS:
        place_item(item)

    # Barrier ring
    for item in ALL_BARRIER:
        place_item(item)

    print("Scene composed.")

def setup_lighting():
    sun = bpy.data.lights.new("Sun", 'SUN')
    sun.energy = 5
    sun.color = (1.0, 0.93, 0.78)
    sun_obj = bpy.data.objects.new("Sun", sun)
    bpy.context.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))

    fill = bpy.data.lights.new("Fill", 'SUN')
    fill.energy = 1.5
    fill.color = (0.7, 0.8, 1.0)
    fill_obj = bpy.data.objects.new("Fill", fill)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(35), math.radians(-25), math.radians(140))

    world = bpy.data.worlds.new("Sky")
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    nodes.clear()
    bg = nodes.new('ShaderNodeBackground')
    bg.inputs['Color'].default_value = (0.4, 0.6, 0.92, 1.0)
    bg.inputs['Strength'].default_value = 1.5
    out = nodes.new('ShaderNodeOutputWorld')
    links.new(bg.outputs['Background'], out.inputs['Surface'])
    bpy.context.scene.world = world

def setup_camera():
    cam = bpy.data.cameras.new("Camera")
    cam.lens = 28
    cam_obj = bpy.data.objects.new("Camera", cam)
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj
    return cam_obj

def aim_camera(cam_obj, pos, look_at):
    cam_obj.location = Vector(pos)
    direction = Vector(look_at) - Vector(pos)
    cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

CAMERA_ANGLES = {
    "SE": {"pos": (34, -26, 22), "look_at": (0, 6, 2)},
    "SW": {"pos": (-34, -26, 22), "look_at": (0, 6, 2)},
    "NE": {"pos": (34, 36, 22), "look_at": (0, 6, 2)},
    "NW": {"pos": (-34, 36, 22), "look_at": (0, 6, 2)},
}

def setup_render():
    bpy.context.scene.render.engine = 'BLENDER_EEVEE'
    bpy.context.scene.render.resolution_x = 1920
    bpy.context.scene.render.resolution_y = 1080
    bpy.context.scene.render.resolution_percentage = 100
    bpy.context.scene.render.image_settings.file_format = 'PNG'

def render_all_angles(cam_obj, base_path=None):
    if base_path is None:
        base_path = RENDER_PATH.replace(".png", "")
    setup_render()
    for name, angle in CAMERA_ANGLES.items():
        aim_camera(cam_obj, angle["pos"], angle["look_at"])
        filepath = f"{base_path}-{name}.png"
        bpy.context.scene.render.filepath = filepath
        bpy.ops.render.render(write_still=True)
        print(f"Render saved: {filepath}")

def render_single(cam_obj, filepath=RENDER_PATH):
    setup_render()
    aim_camera(cam_obj, CAMERA_ANGLES["SE"]["pos"], CAMERA_ANGLES["SE"]["look_at"])
    bpy.context.scene.render.filepath = filepath
    bpy.ops.render.render(write_still=True)
    print(f"Render saved to {filepath}")

# ============================================================
# RUN
# ============================================================
compose()
setup_lighting()
cam = setup_camera()
render_all_angles(cam)

# Save .blend for manual review
blend_path = r"F:\CODE STUFF\Paperclip\village-scene.blend"
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"Saved .blend to {blend_path}")
