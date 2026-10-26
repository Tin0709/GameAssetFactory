"""Headless Blender geometry contracts; run with --background --factory-startup."""
import importlib.util
import json
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parent


def run():
    source = ROOT / "geometry.py"
    assert source.exists(), "Authored geometry builder has not been implemented"
    spec = importlib.util.spec_from_file_location("sabre_geometry", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    result = module.build(bpy.context.scene, ROOT / ".validation" / "geometry_test")
    assert {"rig", "body", "face", "sabre", "atlas", "materials"} <= result.keys()
    rig = result["rig"]
    expected = {"Root", "Hips", "Body", "Head", "Arm.L", "Arm.R", "Leg.L", "Leg.R", "Hand.R", "Hand.L", "Weapon"}
    assert set(rig.data.bones.keys()) == expected, "Only declared authored bones are exported"
    for bone in rig.data.bones:
        assert (bone.tail_local - bone.head_local).normalized().dot((0, 1, 0)) > .999999
        assert sum(abs(bone.matrix_local.to_3x3()[r][c] - float(r == c)) for r in range(3) for c in range(3)) < .00001
    assert rig.data.bones["Weapon"].parent.name == "Hand.R"
    assert rig.data.bones["Hand.R"].parent.name == "Arm.R"
    assert all(p.rotation_mode == "XYZ" for p in rig.pose.bones)
    assert result["atlas"].size[:] == (128, 128)
    body, face, sabre = result["body"], result["face"], result["sabre"]
    for obj in (body, face, sabre):
        assert obj.parent == rig
        assert len([m for m in obj.modifiers if m.type == "ARMATURE" and m.object == rig]) == 1
        assert len(obj.data.uv_layers) == 1
        assert all(len(v.groups) == 1 and abs(v.groups[0].weight - 1) < .000001 for v in obj.data.vertices), "Rigid one-bone skinning"
    assert abs(min(v.co.z for v in body.data.vertices)) < .000001
    assert abs(max(v.co.z for v in body.data.vertices) - 2.003) < .000001
    keys = face.data.shape_keys.key_blocks
    assert set(keys.keys()) == {"Basis", "Focused", "Blink"}
    for name in ("Focused", "Blink"):
        assert keys[name].value == 0.0, "Fresh character starts in neutral Basis: " + name
        assert max((a.co - b.co).length for a, b in zip(keys[name].data, keys["Basis"].data)) > .01, name + " visibly changes face"
    # Both eyebrow quads have horizontal upper/lower edges in the neutral face.
    brows = 0
    for polygon in face.data.polygons:
        coords = [keys["Basis"].data[i].co for i in polygon.vertices]
        if all(abs(v.y + .260) < .000001 for v in coords) and min(v.z for v in coords) > 1.76:
            brows += 1
            assert abs(coords[0].z - coords[1].z) < .000001
            assert abs(coords[2].z - coords[3].z) < .000001
    assert brows == 2, "Neutral eyebrow assertion covers both visible brows"
    assert all(face.vertex_groups[v.groups[0].group].name == "Head" for v in face.data.vertices)
    assert all(sabre.vertex_groups[v.groups[0].group].name == "Weapon" for v in sabre.data.vertices)
    wrist = rig.data.bones["Weapon"].head_local
    coords = [v.co - wrist for v in sabre.data.vertices]
    bounds = [[min(v[i] for v in coords), max(v[i] for v in coords)] for i in range(3)]
    for actual, target in zip([b[1] - b[0] for b in bounds], [.530, .063, 1.768]):
        assert abs(actual - target) < .00001, (bounds, actual, target)
    assert not bpy.data.actions, "Geometry builder must not author animation Actions"
    report = {"passed": True, "body_vertices": len(body.data.vertices), "face_vertices": len(face.data.vertices), "sabre_vertices": len(sabre.data.vertices), "sabre_local_bounds": bounds, "metrics": result.get("metrics", {})}
    print("SABRE_GEOMETRY_TEST " + json.dumps(report))
    if "--render" in sys.argv:
        render_preview(result)


def render_preview(result):
    """Optional isolated geometry view; no authoring scene or Actions are saved."""
    from mathutils import Vector
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1100
    scene.render.resolution_percentage = 100
    scene.world.color = (.11, .13, .15)
    scene.view_settings.view_transform = "AgX"
    result["sabre"].hide_render = True
    camera_data = bpy.data.cameras.new("GeometryTestCamera")
    camera = bpy.data.objects.new("GeometryTestCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (3.2, -7.5, 3.6)
    camera.rotation_euler = (Vector((0, 0, 1.04)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.45
    scene.camera = camera
    for name, position, power, size in [("Key", (3, -4, 6), 600, 4), ("Fill", (-4, -2, 3), 240, 3), ("Rim", (1, 3, 4), 400, 3)]:
        light_data = bpy.data.lights.new("GeometryTest" + name, "AREA")
        light_data.energy = power
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new("GeometryTest" + name, light_data)
        scene.collection.objects.link(light)
        light.location = position
        light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(ROOT / ".validation" / "geometry_test" / "refined_character_neutral.png")
    bpy.ops.render.render(write_still=True)
    result["body"].hide_render = True
    result["face"].hide_render = True
    result["sabre"].hide_render = False
    result["rig"].pose.bones["Weapon"].rotation_euler.x = 0
    camera.location = (-.3435, -7.5, .206)
    camera.rotation_euler = (Vector((-.3435, 0, .206)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = 2.1
    scene.render.resolution_x = 650
    scene.render.resolution_y = 1000
    scene.render.filepath = str(ROOT / ".validation" / "geometry_test" / "refined_sabre.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    try:
        run()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
