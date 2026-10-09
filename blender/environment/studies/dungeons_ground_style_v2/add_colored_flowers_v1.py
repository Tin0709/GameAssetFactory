"""Add blue/red/yellow variants of the current white patch via live Blender MCP.

Run create(), render the white-colour baseline, then apply_colors() and review.
Existing source data and animations remain untouched. Never open/reload a blend.
"""

import importlib.util
import json
from pathlib import Path

import bpy
from mathutils import Vector


HERE = Path(__file__).resolve().parent
EVIDENCE = HERE / ".validation" / "colored_flowers_v1"
SOURCE_NAME = "ENV_WhiteFlowerPatch_1m_V1"
VARIANTS = {
    "Blue": {"x": 17, "petals": [(69, 105, 232), (113, 141, 238)], "centre": (66, 45, 151),
             "reference": "codex-clipboard-9ae6e1af-dc96-4f25-a6b8-b6e8a2f1c812.png"},
    "Red": {"x": 19, "petals": [(234, 47, 43), (189, 37, 40)], "centre": (153, 34, 26),
            "reference": "codex-clipboard-65d358e4-e2fc-40b2-9765-d3a58ff881c1.png"},
    "Yellow": {"x": 21, "petals": [(252, 233, 78), (251, 211, 56)], "centre": (238, 155, 37),
               "reference": "codex-clipboard-24cf944d-73be-46df-969c-1e1cd07e5c55.png"},
}


def preservation():
    spec = importlib.util.spec_from_file_location("colored_flower_preservation", HERE / "flower_preservation.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def label(collection, name, body, x, y, size):
    curve = bpy.data.curves.new(name + "_Font", "FONT")
    curve.body = body
    curve.align_x = "CENTER"
    curve.size = size
    curve.materials.append(bpy.data.materials["Type_Cream"])
    obj = bpy.data.objects.new(name, curve)
    collection.objects.link(obj)
    obj.location = (x, y, .006)


def create():
    assert not bpy.app.background, "Edit the currently open foreground Blender session."
    assert Path(bpy.data.filepath).resolve() == (HERE / "dungeons_ground_style_v2.blend").resolve()
    assert bpy.context.mode == "OBJECT", "Preserve the current editing mode."
    assert "FLOWERS_Colored_1Block_V1" not in bpy.data.collections, "Do not overwrite existing variants."
    for kind in VARIANTS:
        assert f"ENV_{kind}FlowerPatch_1m_V1" not in bpy.data.objects
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    backup = EVIDENCE / "live_before_colored_flowers.blend"
    assert not backup.exists(), "Keep the previous live backup."
    audit = preservation()
    baseline = audit.snapshot()
    bpy.app.driver_namespace["colored_flowers_v1_baseline"] = baseline
    (EVIDENCE / "before_snapshot.json").write_text(json.dumps(baseline, indent=2), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(backup), copy=True)
    assert Path(bpy.data.filepath).resolve() == (HERE / "dungeons_ground_style_v2.blend").resolve()
    assert not audit.compare(baseline)

    scene = bpy.context.scene
    source = bpy.data.objects[SOURCE_NAME]
    assets = bpy.data.collections.new("FLOWERS_Colored_1Block_V1")
    review = bpy.data.collections.new("REVIEW_Flower_Color_Variants_V1")
    scene.collection.children.link(assets)
    scene.collection.children.link(review)
    review["purpose"] = "Same five-flower geometry, original materials and lighting; compare head colours."
    white = source.copy()
    white.name = "REVIEW_ColorFlower_White_Comparison"
    white.location = (15, 0, 1)
    white["display_only"] = True
    review.objects.link(white)
    for kind, spec in VARIANTS.items():
        obj = source.copy()
        obj.data = source.data.copy()
        obj.name = f"ENV_{kind}FlowerPatch_1m_V1"
        obj.data.name = obj.name + "_PlanarMesh"
        obj.location = (spec["x"], 0, 1)
        obj["authoring_status"] = f"{kind} flower variant V1; awaiting user art review"
        obj["source_flower"] = SOURCE_NAME
        obj["reference"] = spec["reference"] + "; sampled dominant petal colours; original white-flower geometry"
        obj.asset_mark()
        obj.asset_data.description = f"Five {kind.lower()} flowers, 1 x 1 m planting area; four upward petals per head."
        assets.objects.link(obj)
    for kind, x in (("White", 15), ("Blue", 17), ("Red", 19), ("Yellow", 21)):
        block = bpy.data.objects["ENV_GrassBlock_DI_V3"].copy()
        block.name = f"REVIEW_ColorFlower_{kind}_Platform"
        block.location = (x, 0, 0)
        block["display_only"] = True
        review.objects.link(block)
        label(review, f"REVIEW_ColorFlower_{kind}_Label", f"{kind.upper()} FLOWERS / 1m PATCH", x, -.87, .125)
        label(review, f"REVIEW_ColorFlower_{kind}_Size", "5 FLOWERS / 1 x 1 m", x, -1.15, .075)

    camera_data = bpy.data.cameras.new("CAM_Flower_Color_Variants_V1_Data")
    camera = bpy.data.objects.new("CAM_Flower_Color_Variants_V1", camera_data)
    review.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 8.8
    camera.location = (21.4, -10.5, 7.9)
    camera.rotation_euler = (Vector((18, 0, .66)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    for window in bpy.context.window_manager.windows:
        if window.scene == scene:
            for area in window.screen.areas:
                if area.type == "VIEW_3D":
                    space = area.spaces.active
                    space.use_local_camera = True
                    space.camera = camera
                    space.region_3d.view_perspective = "CAMERA"
                    space.region_3d.view_camera_zoom = 28
                    space.shading.type = "MATERIAL"
                    space.shading.use_scene_lights = True
                    space.shading.use_scene_world = True
                    space.overlay.show_overlays = False
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in assets.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["ENV_BlueFlowerPatch_1m_V1"]
    bpy.context.view_layer.update()
    assert not audit.compare(baseline)
    return {"backup": str(backup), "assets": [o.name for o in assets.objects], "camera": camera.name,
            "source_file": bpy.data.filepath, "stage": "white colour baseline"}


def recolor(mesh, spec):
    parts = mesh.attributes["flower_part"]
    colors = mesh.color_attributes["Color"]
    for poly in mesh.polygons:
        part = parts.data[poly.index].value
        if part not in (1, 2):
            continue
        # Keep the original two-tone petal assignment, recolouring copied data only.
        old = colors.data[poly.loop_start].color_srgb
        rgb = spec["centre"] if part == 2 else spec["petals"][int(old[0] < .93)]
        rgba = tuple(channel / 255 for channel in rgb) + (1,)
        for index in poly.loop_indices:
            colors.data[index].color_srgb = rgba
    mesh.update()


def apply_colors():
    audit = preservation()
    source = bpy.data.objects[SOURCE_NAME].data
    measurements = []
    for kind, spec in VARIANTS.items():
        obj = bpy.data.objects[f"ENV_{kind}FlowerPatch_1m_V1"]
        if not obj.get("head_colors_applied"):
            recolor(obj.data, spec)
            obj["head_colors_applied"] = True
        parts = obj.data.attributes["flower_part"]
        colors = obj.data.color_attributes["Color"]
        assert [list(v.co) for v in obj.data.vertices] == [list(v.co) for v in source.vertices]
        assert [list(p.vertices) for p in obj.data.polygons] == [list(p.vertices) for p in source.polygons]
        for original_uv, new_uv in zip(source.uv_layers, obj.data.uv_layers):
            assert [list(v.uv) for v in original_uv.data] == [list(v.uv) for v in new_uv.data]
        green_changes = 0
        for poly in obj.data.polygons:
            if parts.data[poly.index].value in (0, 3):
                for index in poly.loop_indices:
                    green_changes += tuple(colors.data[index].color) != tuple(source.color_attributes["Color"].data[index].color)
        assert green_changes == 0, "Stem/leaf colours must remain exact."
        coords = [v.co for v in obj.data.vertices]
        bounds = [[min(v[i] for v in coords), max(v[i] for v in coords)] for i in range(3)]
        assert all(-.5 <= v.x <= .5 and -.5 <= v.y <= .5 for v in coords)
        measurements.append({"name": obj.name, "flowers": 5, "triangles": sum(len(p.vertices) - 2 for p in obj.data.polygons),
                             "dimensions_m": list(obj.dimensions), "local_bounds_m": bounds,
                             "planting_footprint_m": list(obj["placement_footprint_m"]),
                             "stem_leaf_color_changes": green_changes, "palette_srgb": spec})

    # Independent copies extend the existing optional Blender wind study. Its saved
    # handler already discovers objects by this flag; do not register it or alter
    # any original posed preview/rest data during this colour-only task.
    wind_source = bpy.data.objects["REVIEW_WIND_ENV_WhiteFlowerPatch_1m_V1"]
    collection = bpy.data.collections.get("REVIEW_WIND_ColoredFlowers_V1")
    if collection is None:
        collection = bpy.data.collections.new("REVIEW_WIND_ColoredFlowers_V1")
        bpy.context.scene.collection.children.link(collection)
    for number, (kind, spec) in enumerate(VARIANTS.items()):
        if f"REVIEW_WIND_ENV_{kind}FlowerPatch_1m_V1" in bpy.data.objects:
            continue
        obj = wind_source.copy()
        obj.data = wind_source.data.copy()
        obj.name = f"REVIEW_WIND_ENV_{kind}FlowerPatch_1m_V1"
        obj.data.name = obj.name + "_IndependentMesh"
        obj.location = (23 + 2 * number, 6.2, 1)
        obj["source_flower"] = f"ENV_{kind}FlowerPatch_1m_V1"
        obj["authoring_status"] = f"{kind} flower Blender wind preview; awaiting user review"
        obj["reference"] = spec["reference"]
        recolor(obj.data, spec)
        collection.objects.link(obj)
    bpy.context.view_layer.update()
    changed = audit.compare(bpy.app.driver_namespace["colored_flowers_v1_baseline"])
    assert not changed, f"Existing data changed: {changed}"
    report = {"source_file": bpy.data.filepath, "live_session": True, "stage": "head colours applied",
              "measurements": measurements, "changed_originals": changed,
              "scene_camera": bpy.context.scene.camera.name, "frame": bpy.context.scene.frame_current}
    (EVIDENCE / "validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report
