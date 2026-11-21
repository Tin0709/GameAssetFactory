"""Audit the saved render scene against the approved rest rig."""
from pathlib import Path
import json
import sys

import bmesh
import bpy

show=Path(sys.argv[-1])
scene=bpy.context.scene
collection=bpy.data.collections["THE FORAGER"]
rig=scene.objects["The Forager | 13-bone rig"]
assert scene.camera.name=="Hero" and not bpy.data.libraries
assert len(rig.data.bones)==13
assert not any("backpack" in o.name.casefold() or "bedroll" in o.name.casefold() for o in collection.all_objects)
wanted={"Front","Hero","Right","Back","Left"}
assert {m.name for m in scene.timeline_markers if m.camera}==wanted
meshes=[o for o in collection.all_objects if o.type=="MESH"]
assert len(meshes)>100
assert all(o.parent==rig and o.parent_type=="BONE" and o.parent_bone in rig.data.bones for o in meshes)
for x in ("Hood · open cloth shell","Cape · continuous stepped back"):
    assert x in scene.objects

maps=set()
for o in meshes:
    bm=bmesh.new()
    bm.from_mesh(o.data)
    assert all(f.calc_area()>1e-10 for f in bm.faces),o.name
    assert all(e.is_manifold or e.is_boundary for e in bm.edges),o.name
    if o.name.startswith("Hood · open"):
        assert any(e.is_boundary for e in bm.edges)
    else:
        assert all(e.is_manifold for e in bm.edges),o.name
    bm.free()
    for m in o.data.materials:
        images=[n for n in m.node_tree.nodes if n.type=="TEX_IMAGE"]
        assert images,m.name
        for node in images:
            assert tuple(node.image.size)==(64,64) and node.image.packed_file
            assert node.interpolation=="Closest"
            maps.add(node.image.name)

for m in scene.timeline_markers:
    scene.frame_set(m.frame)
    assert all(o.hide_render==(m.name!="Hero") for o in bpy.data.collections["Hero props · Lantern and travel staff"].objects)
scene.frame_set(2)

with bpy.data.libraries.load(str(show),link=False) as (src,dst):
    dst.objects=["Showcase_Player_Rig"]
approved=dst.objects[0].data
for b in rig.data.bones:
    a=approved.bones[b.name]
    assert (a.parent.name if a.parent else None)==(b.parent.name if b.parent else None)
    assert max(abs(x) for row in a.matrix_local-b.matrix_local for x in row)<1e-7

summary={"meshes":len(meshes),"packed_64px_maps":len(maps),"bones":len(rig.data.bones),
         "rest_rig_matches":True,"review_angles":sorted(wanted),"has_backpack_or_bedroll":False}
print(json.dumps(summary,ensure_ascii=False))
(Path(bpy.data.filepath).parent/"verification.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding="utf8")

