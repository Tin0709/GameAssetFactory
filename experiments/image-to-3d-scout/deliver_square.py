"""High-resolution detail proof and structural verification for the isolated Scout."""
import bpy
import json, sys
from pathlib import Path

out=Path(sys.argv[-1]).resolve()
scene=bpy.context.scene
out.mkdir(parents=True,exist_ok=True)
assert scene["Review pass"]==6
names={m.name.casefold():m for m in scene.timeline_markers if m.camera}
assert set(names)=={"front","hero","right","back","left"}
meshes=[o for o in scene.objects if o.type=="MESH" and not o.hide_render]
rig=scene.objects["Scout Canon | Rig"]
assert len(rig.data.bones)==13
assert all(o.parent==rig and o.parent_bone in rig.data.bones for o in meshes)
assert sum(o.name.startswith("Scout Square | ") for o in meshes)>=60
images={i.name:list(i.size) for i in bpy.data.images if i.packed_file}
assert len(images)==5 and all(s==[64,64] for s in images.values())
assert not bpy.data.libraries
for obj in meshes:
    assert all(len(p.vertices)>=3 and p.area>1e-10 for p in obj.data.polygons),obj.name
scene.render.resolution_x=860
scene.render.resolution_y=1150
scene.cycles.samples=42
for view in ("front","hero","back","right"):
    marker=names[view]
    scene.frame_set(marker.frame)
    scene.camera=marker.camera
    scene.render.filepath=str(out/(view+".png"))
    bpy.ops.render.render(write_still=True)
report={"review_passes":scene["Review pass"],"visible_meshes":len(meshes),
        "groups":sum(o.name.startswith("Scout Square | ") for o in meshes),
        "packed_images":images,"bones":len(rig.data.bones),"cameras":sorted(names)}
(out/"structure.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf8")
print(json.dumps(report))

