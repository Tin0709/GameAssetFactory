"""Check the edited candidate and render its five review angles in full size."""
from pathlib import Path
import json
import sys

import bmesh
import bpy

out, report = [Path(arg).resolve() for arg in sys.argv[-2:]]
scene = bpy.context.scene
assert scene["Source-fit pass"].startswith("Fitted rectangular details")
markers = {m.name.casefold(): m for m in scene.timeline_markers if m.camera}
assert set(markers) == {"front","hero","right","back","left"}
rig = scene.objects["Scout Canon | Rig"]
assert len(rig.data.bones) == 13
meshes = [o for o in scene.objects if o.type == "MESH" and not o.hide_render]
assert not bpy.data.libraries
assert all(o.parent == rig and o.parent_bone in rig.data.bones for o in meshes)
guard = scene.objects["Scout Canon | Long cloak with tapered supporting folds"]
assert any(m.type == "NODES" and "Cape clearance" in m.name for m in guard.modifiers)
nodes = {t for o in meshes for m in o.data.materials if m and m.node_tree
         for t in m.node_tree.nodes if t.type == "TEX_IMAGE" and t.image}
assert all(t.interpolation == "Closest" for t in nodes)
images = {t.image for t in nodes}
assert images and all(i.packed_file and tuple(i.size) == (64,64) for i in images)
new = []
for o in meshes:
    assert all(len(p.vertices) >= 3 and p.area > 1e-10 for p in o.data.polygons), o.name
    if o.name.startswith("Scout Blocks | "):
        mesh = bmesh.new()
        mesh.from_mesh(o.data)
        assert all(e.is_manifold and e.is_contiguous for e in mesh.edges), o.name
        assert mesh.calc_volume(signed=True) > 0, o.name
        mesh.free()
        new.append(o.name)
report.write_text(json.dumps({"rig_bones":len(rig.data.bones),"render_meshes":len(meshes),
                             "new_closed_meshes":new,"packed_64px_images":sorted(i.name for i in images)},
                             ensure_ascii=False,indent=2),encoding="utf-8")
out.mkdir(parents=True,exist_ok=True)
scene.render.resolution_x = 860
scene.render.resolution_y = 1150
scene.cycles.samples = 48
for view, mark in markers.items():
    scene.frame_set(mark.frame)
    scene.camera = mark.camera
    scene.render.filepath = str(out / f"{view}.png")
    bpy.ops.render.render(write_still=True)

