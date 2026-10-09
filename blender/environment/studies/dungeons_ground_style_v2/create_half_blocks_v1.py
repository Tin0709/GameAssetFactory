"""Add three 1 m x 1 m x 0.5 m slabs to the live Blender asset session.

Run through the live Blender MCP connection, never by opening/replacing a file.
The original V3 meshes, materials, images, animation and camera are preserved.
"""

import importlib.util
import json
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


STUDY = Path(__file__).resolve().parent
EVIDENCE = STUDY / ".validation" / "half_blocks_v1"
SOURCE = STUDY / "dungeons_ground_style_v2.blend"
SPECS = (
    ("Grass", 7.0, "GRASS / HALF BLOCK"),
    ("Dirt", 9.0, "DIRT / HALF BLOCK"),
    ("Stone", 11.0, "STONE / HALF BLOCK"),
)


def label(collection, name, body, x, y, size):
    curve = bpy.data.curves.new(name + "_Font", "FONT")
    curve.body = body
    curve.align_x = "CENTER"
    curve.size = size
    curve.materials.append(bpy.data.materials["Type_Cream"])
    obj = bpy.data.objects.new(name, curve)
    collection.objects.link(obj)
    obj.location = (x, y, 0.006)
    return obj


def main():
    if Path(bpy.data.filepath).resolve() != SOURCE.resolve():
        raise RuntimeError("Connect to the existing dungeons_ground_style_v2 session first.")
    if bpy.context.mode != "OBJECT":
        raise RuntimeError("Leave the current editing mode unchanged; run from Object Mode.")
    for kind, _, _ in SPECS:
        source = bpy.data.objects.get(f"ENV_{kind}Block_DI_V3")
        if not source or source.type != "MESH":
            raise RuntimeError(f"Missing original {kind} block.")
        if bpy.data.objects.get(f"ENV_{kind}Slab_DI_V3"):
            raise RuntimeError("Slabs already exist; do not overwrite reviewed assets.")
    if bpy.data.collections.get("HALF_BLOCKS_DI_V3_V1"):
        raise RuntimeError("The slab collection already exists; inspect before editing.")

    EVIDENCE.mkdir(parents=True, exist_ok=True)
    spec = importlib.util.spec_from_file_location("half_block_preservation", STUDY / "flower_preservation.py")
    preservation = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(preservation)
    baseline = preservation.snapshot()
    (EVIDENCE / "before_snapshot.json").write_text(json.dumps(baseline, indent=2), encoding="utf-8")

    # This copy captures unsaved user work without loading a different file.
    backup = EVIDENCE / "live_before_half_blocks.blend"
    if backup.exists():
        raise RuntimeError("A live backup already exists; preserve it before another run.")
    bpy.ops.wm.save_as_mainfile(filepath=str(backup), copy=True)
    assert Path(bpy.data.filepath).resolve() == SOURCE.resolve()
    backup_changes = preservation.compare(baseline)
    if backup_changes:
        raise RuntimeError(f"Save-copy changed existing data: {backup_changes}")

    scene = bpy.context.scene
    assets = bpy.data.collections.new("HALF_BLOCKS_DI_V3_V1")
    review = bpy.data.collections.new("REVIEW_HalfBlocks_DI_V3_V1")
    scene.collection.children.link(assets)
    scene.collection.children.link(review)
    slabs = []
    for kind, x, title in SPECS:
        source = bpy.data.objects[f"ENV_{kind}Block_DI_V3"]
        obj = source.copy()
        obj.data = source.data.copy()
        obj.name = f"ENV_{kind}Slab_DI_V3"
        obj.data.name = obj.name + "_Mesh"
        assets.objects.link(obj)
        for vertex in obj.data.vertices:
            vertex.co.z *= 0.5
        # Full square top/bottom; half a tile on each vertical side.
        # Grass sides use the upper half to retain the original cap thickness.
        uv = obj.data.uv_layers.active.data
        for poly in obj.data.polygons:
            if abs(poly.normal.z) < 0.9:
                for index in poly.loop_indices:
                    uv[index].uv.y = 0.5 * uv[index].uv.y + (0.5 if kind == "Grass" else 0.0)
        obj.data.update()
        obj.location = (x, -3.8, 0.0)
        obj["source_block"] = source.name
        obj["block_size_m"] = [1.0, 1.0, 0.5]
        obj["side_texture_pixels_per_m"] = 32
        obj["integration_status"] = "Blender review only"
        obj.asset_mark()
        obj.asset_data.description = f"V3 {kind.lower()} half block, 1 x 1 x 0.5 m; original texture density."
        slabs.append(obj)
        label(review, f"REVIEW_{kind}Slab_Label", title, x, -4.62, 0.14)
        label(review, f"REVIEW_{kind}Slab_Dimensions", "1 x 1 x 0.5 m", x, -4.9, 0.1)

    camera_data = bpy.data.cameras.new("CAM_HalfBlocks_DI_V3_V1_Data")
    camera = bpy.data.objects.new("CAM_HalfBlocks_DI_V3_V1", camera_data)
    review.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 9.0
    camera.location = (13.6, -13.0, 10.0)
    target = Vector((9.0, -2.0, 0.2))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    # A local viewport camera shows the new row without changing the scene camera.
    for window in bpy.context.window_manager.windows:
        if window.scene == scene:
            for area in window.screen.areas:
                if area.type == "VIEW_3D":
                    space = area.spaces.active
                    space.use_local_camera = True
                    space.camera = camera
                    space.region_3d.view_perspective = "CAMERA"
                    space.region_3d.view_camera_zoom = 0
                    space.shading.type = "MATERIAL"
                    space.shading.use_scene_lights = True
                    space.shading.use_scene_world = True
                    space.overlay.show_overlays = False

    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in slabs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = slabs[0]
    bpy.context.view_layer.update()

    measurements = []
    for obj in slabs:
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        measurements.append({"object": obj.name, "dimensions_m": list(obj.dimensions),
                             "scale": list(obj.scale), "volume_m3": mesh.calc_volume(signed=True),
                             "closed_manifold": all(edge.is_manifold for edge in mesh.edges),
                             "triangles": sum(len(poly.vertices) - 2 for poly in obj.data.polygons),
                             "materials": [material.name for material in obj.data.materials]})
        mesh.free()
        assert all(abs(a - b) < 1e-6 for a, b in zip(obj.dimensions, (1, 1, .5)))
        assert measurements[-1]["closed_manifold"]
        assert abs(measurements[-1]["volume_m3"] - .5) < 1e-6
        assert obj.data is not bpy.data.objects[obj["source_block"]].data
    changed_originals = preservation.compare(baseline)
    if changed_originals:
        raise RuntimeError(f"Existing asset data changed: {changed_originals}")
    report = {"source": str(SOURCE), "backup": str(backup), "live_session": True,
              "measurements": measurements, "changed_originals": changed_originals,
              "review_camera": camera.name, "scene_camera": scene.camera.name,
              "frame": scene.frame_current}
    (EVIDENCE / "validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    bpy.app.driver_namespace["half_blocks_v1_baseline"] = baseline
    return report


result = main()
