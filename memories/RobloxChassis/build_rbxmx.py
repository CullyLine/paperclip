#!/usr/bin/env python3
"""
build_rbxmx.py  —  Generate PolarisChassis.rbxmx from source Luau files.

Run:  python build_rbxmx.py

Output structure in the RBXMX:
  TestVehicle (Model)          → drag into Workspace
  ChassisClient (LocalScript)  → drag into StarterPlayer > StarterPlayerScripts
  ExternalTuner (ModuleScript) → drag into ServerScriptService (optional)

MESH SETUP: Upload car-body-final.glb and wheel-final.glb to Roblox
(via Asset Manager or MeshPart import), then update the asset IDs below.
"""
import math
import os

DIR = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(DIR, "src")
OUT = os.path.join(DIR, "PolarisChassis.rbxmx")

SX, SY, SZ = 0, 5, 0

MAT_SMOOTH_PLASTIC = 272
MAT_NEON = 288
MAT_METAL = 1088
SHAPE_BLOCK = 1
SHAPE_CYLINDER = 2

CAR_BODY_MESH_ID = "rbxassetid://0"
WHEEL_MESH_ID = "rbxassetid://0"

COLLISION_BOX = 0
COLLISION_HULL = 1
COLLISION_DEFAULT = 2


def read_file(rel_path):
    with open(os.path.join(SRC, rel_path), "r", encoding="utf-8") as f:
        return f.read()


def color_xml(r, g, b):
    return (f'<Color3 name="Color">'
            f'<R>{r/255:.6f}</R><G>{g/255:.6f}</G><B>{b/255:.6f}</B>'
            f'</Color3>')


def cframe_xml(x, y, z, rx=0, ry=0, rz=0):
    a, b, c = math.radians(rx), math.radians(ry), math.radians(rz)
    ca, sa = math.cos(a), math.sin(a)
    cb, sb = math.cos(b), math.sin(b)
    cc, sc = math.cos(c), math.sin(c)
    m = [
        cb*cc,             sa*sb*cc - ca*sc,  ca*sb*cc + sa*sc,
        cb*sc,             sa*sb*sc + ca*cc,  ca*sb*sc - sa*cc,
        -sb,               sa*cb,             ca*cb,
    ]
    rot = "".join(f"<R{i}{j}>{m[i*3+j]:.8f}</R{i}{j}>"
                  for i in range(3) for j in range(3))
    return (f'<CoordinateFrame name="CFrame">'
            f'<X>{x}</X><Y>{y}</Y><Z>{z}</Z>{rot}'
            f'</CoordinateFrame>')


def make_part(ref, name, size, pos, color, material=MAT_SMOOTH_PLASTIC,
              shape=SHAPE_BLOCK, anchored=True, can_collide=False,
              transparency=0.0, rx=0, ry=0, rz=0,
              custom_phys=None, children=""):
    sx, sy, sz = size
    cx, cy, cz = pos[0] + SX, pos[1] + SY, pos[2] + SZ
    cr, cg, cb = color

    phys = ""
    if custom_phys:
        d, fr, el, fw, ew = custom_phys
        phys = (f'<PhysicalProperties name="CustomPhysicalProperties">'
                f'<CustomPhysics>true</CustomPhysics>'
                f'<Density>{d}</Density><Friction>{fr}</Friction>'
                f'<Elasticity>{el}</Elasticity>'
                f'<FrictionWeight>{fw}</FrictionWeight>'
                f'<ElasticityWeight>{ew}</ElasticityWeight>'
                f'</PhysicalProperties>')

    return (
        f'<Item class="Part" referent="{ref}"><Properties>'
        f'<bool name="Anchored">{"true" if anchored else "false"}</bool>'
        f'<bool name="CanCollide">{"true" if can_collide else "false"}</bool>'
        f'{cframe_xml(cx, cy, cz, rx, ry, rz)}'
        f'{color_xml(cr, cg, cb)}'
        f'<token name="Material">{material}</token>'
        f'<string name="Name">{name}</string>'
        f'<token name="shape">{shape}</token>'
        f'<Vector3 name="size"><X>{sx}</X><Y>{sy}</Y><Z>{sz}</Z></Vector3>'
        f'<token name="TopSurface">0</token>'
        f'<token name="BottomSurface">0</token>'
        f'<float name="Transparency">{transparency}</float>'
        f'{phys}'
        f'</Properties>{children}</Item>'
    )


def make_mesh_part(ref, name, mesh_id, size, pos, color,
                   material=MAT_SMOOTH_PLASTIC, anchored=True,
                   can_collide=False, transparency=0.0,
                   rx=0, ry=0, rz=0,
                   collision_fidelity=COLLISION_BOX,
                   custom_phys=None, children=""):
    sx, sy, sz = size
    cx, cy, cz = pos[0] + SX, pos[1] + SY, pos[2] + SZ
    cr, cg, cb = color

    phys = ""
    if custom_phys:
        d, fr, el, fw, ew = custom_phys
        phys = (f'<PhysicalProperties name="CustomPhysicalProperties">'
                f'<CustomPhysics>true</CustomPhysics>'
                f'<Density>{d}</Density><Friction>{fr}</Friction>'
                f'<Elasticity>{el}</Elasticity>'
                f'<FrictionWeight>{fw}</FrictionWeight>'
                f'<ElasticityWeight>{ew}</ElasticityWeight>'
                f'</PhysicalProperties>')

    return (
        f'<Item class="MeshPart" referent="{ref}"><Properties>'
        f'<bool name="Anchored">{"true" if anchored else "false"}</bool>'
        f'<bool name="CanCollide">{"true" if can_collide else "false"}</bool>'
        f'{cframe_xml(cx, cy, cz, rx, ry, rz)}'
        f'{color_xml(cr, cg, cb)}'
        f'<Content name="MeshId"><url>{mesh_id}</url></Content>'
        f'<token name="Material">{material}</token>'
        f'<string name="Name">{name}</string>'
        f'<Vector3 name="size"><X>{sx}</X><Y>{sy}</Y><Z>{sz}</Z></Vector3>'
        f'<token name="TopSurface">0</token>'
        f'<token name="BottomSurface">0</token>'
        f'<float name="Transparency">{transparency}</float>'
        f'<token name="CollisionFidelity">{collision_fidelity}</token>'
        f'<token name="RenderFidelity">2</token>'
        f'{phys}'
        f'</Properties>{children}</Item>'
    )


def make_seat(ref, name, size, pos, color, material=MAT_SMOOTH_PLASTIC,
              anchored=True, can_collide=False, rx=0, ry=0, rz=0, children=""):
    sx, sy, sz = size
    cx, cy, cz = pos[0] + SX, pos[1] + SY, pos[2] + SZ
    cr, cg, cb = color
    return (
        f'<Item class="Seat" referent="{ref}"><Properties>'
        f'<bool name="Anchored">{"true" if anchored else "false"}</bool>'
        f'<bool name="CanCollide">{"true" if can_collide else "false"}</bool>'
        f'{cframe_xml(cx, cy, cz, rx, ry, rz)}'
        f'{color_xml(cr, cg, cb)}'
        f'<token name="Material">{material}</token>'
        f'<string name="Name">{name}</string>'
        f'<Vector3 name="size"><X>{sx}</X><Y>{sy}</Y><Z>{sz}</Z></Vector3>'
        f'<token name="TopSurface">0</token>'
        f'<token name="BottomSurface">0</token>'
        f'</Properties>{children}</Item>'
    )


def make_model(ref, name, primary_ref, children):
    pr = primary_ref if primary_ref else "null"
    return (
        f'<Item class="Model" referent="{ref}"><Properties>'
        f'<string name="Name">{name}</string>'
        f'<Ref name="PrimaryPart">{pr}</Ref>'
        f'</Properties>{children}</Item>'
    )


def make_weld(ref, name, part0_ref, part1_ref):
    return (
        f'<Item class="WeldConstraint" referent="{ref}"><Properties>'
        f'<string name="Name">{name}</string>'
        f'<Ref name="Part0">{part0_ref}</Ref>'
        f'<Ref name="Part1">{part1_ref}</Ref>'
        f'</Properties></Item>'
    )


def make_script(ref, name, cls, source, children=""):
    safe = source.replace("]]>", "]]]]><![CDATA[>")
    return (
        f'<Item class="{cls}" referent="{ref}"><Properties>'
        f'<string name="Name">{name}</string>'
        f'<ProtectedString name="Source"><![CDATA[{safe}]]></ProtectedString>'
        f'</Properties>{children}</Item>'
    )


def make_config(ref, name):
    return (
        f'<Item class="Configuration" referent="{ref}"><Properties>'
        f'<string name="Name">{name}</string>'
        f'</Properties></Item>'
    )


def main():
    chassis_config_src     = read_file("Shared/ChassisConfig.luau")
    drivetrain_src         = read_file("Shared/Drivetrain.luau")
    live_values_sync_src   = read_file("Shared/LiveValuesSync.luau")
    chassis_physics_src    = read_file("Shared/ChassisPhysics.luau")
    chassis_controller_src = read_file("Server/ChassisController.server.luau")
    external_tuner_src     = read_file("Server/ExternalTuner.server.luau")
    chassis_client_src     = read_file("Client/ChassisClient.client.luau")
    driver_hud_src         = read_file("Client/DriverHUD.luau")

    R = {}
    _c = [0]
    def rid(tag):
        _c[0] += 1
        R[tag] = f"RBX{_c[0]:08X}"
        return R[tag]

    rid("vehicle"); rid("body"); rid("carbody")
    rid("center_of_mass")
    rid("wheels")
    for w in ("wfl","wfr","wrl","wrr"): rid(w)
    rid("seat"); rid("seat_weld"); rid("seat_prompt")
    rid("cfg_ms"); rid("lvs_ms"); rid("dt_ms"); rid("cp_ms"); rid("ctrl_s")
    rid("client_ls"); rid("hud_ms"); rid("ext_tuner")

    # ── Body ──
    # Use regular Part until real mesh assets are uploaded (rbxassetid://0 has no mass).
    # Once CAR_BODY_MESH_ID is set to a real asset, switch back to make_mesh_part.
    if CAR_BODY_MESH_ID != "rbxassetid://0":
        carbody = make_mesh_part(R["carbody"], "CarBody", CAR_BODY_MESH_ID,
                                 (9, 3.5, 18), (0, 0, 0), (30, 35, 45),
                                 custom_phys=(3, 0.3, 0, 1, 1),
                                 collision_fidelity=COLLISION_BOX)
    else:
        carbody = make_part(R["carbody"], "CarBody", (9, 3.5, 18),
                            (0, 0, 0), (30, 35, 45),
                            custom_phys=(3, 0.3, 0, 1, 1))
    body_parts = "".join([
        carbody,
        make_part(R["center_of_mass"], "CenterOfMass", (1, 1, 1),
                  (0, -0.5, 0), (128, 128, 128), transparency=1.0),
    ])
    body_model = make_model(R["body"], "Body", R["carbody"], body_parts)

    # ── Wheels (MeshParts, no hub children) ──
    wheel_specs = [
        ("WheelFL", "wfl", (-4.5, -0.5,  6.75)),
        ("WheelFR", "wfr", ( 4.5, -0.5,  6.75)),
        ("WheelRL", "wrl", (-4.5, -0.5, -6.75)),
        ("WheelRR", "wrr", ( 4.5, -0.5, -6.75)),
    ]
    wheels_xml = ""
    for wname, wk, off in wheel_specs:
        if WHEEL_MESH_ID != "rbxassetid://0":
            wheel = make_mesh_part(R[wk], wname, WHEEL_MESH_ID,
                                   (1.5, 4, 4), off, (25, 25, 30),
                                   collision_fidelity=COLLISION_BOX)
        else:
            wheel = make_part(R[wk], wname, (1.5, 4, 4), off, (25, 25, 30),
                              shape=SHAPE_CYLINDER)
        wheels_xml += wheel
    wheels_model = make_model(R["wheels"], "Wheels", None, wheels_xml)

    # ── Seat ──
    seat_weld = make_weld(R["seat_weld"], "SeatWeld", R["carbody"], R["seat"])
    proximity_prompt = (
        f'<Item class="ProximityPrompt" referent="{R["seat_prompt"]}"><Properties>'
        f'<string name="ActionText">Drive</string>'
        f'<string name="ObjectText">Vehicle</string>'
        f'<float name="MaxActivationDistance">10</float>'
        f'<float name="HoldDuration">0</float>'
        f'<string name="Name">ProximityPrompt</string>'
        f'</Properties></Item>'
    )
    seat = make_seat(R["seat"], "DriverSeat", (2.5, 0.5, 2.5), (-1.8, 0.7, 0),
                     (20, 20, 25),
                     children=seat_weld + proximity_prompt)

    # ── Scripts inside vehicle ──
    cfg  = make_script(R["cfg_ms"],  "ChassisConfig",    "ModuleScript", chassis_config_src)
    lvs  = make_script(R["lvs_ms"],  "LiveValuesSync",    "ModuleScript", live_values_sync_src)
    dt   = make_script(R["dt_ms"],   "Drivetrain",        "ModuleScript", drivetrain_src)
    cp   = make_script(R["cp_ms"],   "ChassisPhysics",    "ModuleScript", chassis_physics_src)
    ctrl = make_script(R["ctrl_s"],  "ChassisController", "Script",       chassis_controller_src)

    vehicle = make_model(R["vehicle"], "TestVehicle", R["carbody"],
                         body_model + wheels_model + seat + cfg + lvs + dt + cp + ctrl)

    # ── Client script (StarterPlayerScripts) ──
    hud    = make_script(R["hud_ms"],    "DriverHUD",    "ModuleScript", driver_hud_src)
    client = make_script(R["client_ls"], "ChassisClient", "LocalScript",
                         chassis_client_src, children=hud)

    # ── External tuner (optional, ServerScriptService) ──
    ext = make_script(R["ext_tuner"], "ExternalTuner", "ModuleScript", external_tuner_src)

    # ── Assemble ──
    rbxmx = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" '
        'version="4">\n'
        '<Meta name="ExplicitAutoJoints">false</Meta>\n'
        '<External>null</External>\n'
        '<External>nil</External>\n'
        f'{vehicle}\n'
        f'{client}\n'
        f'{ext}\n'
        '</roblox>\n'
    )

    with open(OUT, "w", encoding="utf-8") as f:
        f.write(rbxmx)

    sz = os.path.getsize(OUT)
    print(f"Generated: {OUT}")
    print(f"Size: {sz:,} bytes")
    print()
    print("Import into Roblox Studio:")
    print("  1. Right-click Workspace > Insert from File > PolarisChassis.rbxmx")
    print("  2. Move 'TestVehicle' into Workspace")
    print("  3. Move 'ChassisClient' into StarterPlayer > StarterPlayerScripts")
    print("  4. (Optional) Move 'ExternalTuner' into ServerScriptService")
    print()
    print("MESH SETUP:")
    print("  1. Upload models/car-body-final.glb and models/wheel-final.glb to Roblox")
    print("  2. Update CAR_BODY_MESH_ID and WHEEL_MESH_ID in this script")
    print("  3. Update CAR_BODY_MESH_ID and WHEEL_MESH_ID in VehicleBuilder.server.luau")
    print("  4. Rebuild with: python build_rbxmx.py")


if __name__ == "__main__":
    main()
