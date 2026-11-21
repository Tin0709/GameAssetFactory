"""Validate geometry and generate high-resolution proof from the fitted rig."""
from pathlib import Path
import sys
import bpy,json

p=Path(sys.argv[-2]).resolve()
report=Path(sys.argv[-1]).resolve()
scene=bpy.context.scene
assert scene["Source-fit pass"].startswith("Balanced colors")
names={m.name.casefold():m for m in scene.timeline_markers if m.camera}
assert set(names)=={"front","hero","right","back","left"}
rig=scene.objects["Scout Canon | Rig"]
assert len(rig.data.bones)==13
whole=[o for o in scene.objects if o.type=="MESH" and not o.hide_render]
assert all(o.parent==rig and o.parent_bone in rig.data.bones for o in whole)
assert not bpy.data.libraries
assert any(m.type=="NODES" and "Cape clearance" in m.name for m in scene.objects["Scout Canon | Long cloak with tapered supporting folds"].modifiers)
imgs={t.image for m in bpy.data.materials if m.users>0 and m.node_tree
      for t in m.node_tree.nodes if t.type=="TEX_IMAGE" and t.image}
assert imgs and all(i.packed_file and tuple(i.size)==(64,64) for i in imgs)
assert all(t.interpolation=="Closest" for m in bpy.data.materials if m.users>0 and m.node_tree for t in m.node_tree.nodes if t.type=="TEX_IMAGE" and t.image)
for obj in whole:
    assert all(len(face.vertices)>=3 and face.area>1e-10 for face in obj.data.polygons),obj.name
p.mkdir(exist_ok=True,parents=True)
scene.render.resolution_x=860
scene.render.resolution_y=1150
scene.cycles.samples=46
for view in ("front","hero","right","back","left"):
    mark=names[view]
    scene.frame_set(mark.frame)
    scene.camera=mark.camera
    scene.render.filepath=str(p/(view+".png"))
    bpy.ops.render.render(write_still=True)
report.write_text(json.dumps({"meshes":len(whole),"bones":len(rig.data.bones),
                              "packed_64px_atlases":sorted(i.name for i in imgs),
                              "views":sorted(names),"source_fit":scene["Source-fit pass"]},
                             ensure_ascii=False,indent=2),encoding="utf8")

