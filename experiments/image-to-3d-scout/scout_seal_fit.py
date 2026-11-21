"""Tuck the cheek backing behind the scarf at the two exposed pixels."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render

s=bpy.context.scene
s.frame_set(1)
out=Path(sys.argv[-1]).resolve()
S=1.8/518
face=s.objects["Scout Canon | Face"]
for v in face.data.vertices:
    p=v.co/S
    if p.z<382.0:
        v.co.z=384.0*S
face.data.update()
s["Source-fit pass"]="Balanced colors with checked scarf and boot silhouettes"
keys={m.name.casefold():(m.frame,m.camera) for m in s.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(s,[(keys[v][0],v,keys[v][1]) for v in views],out)
s.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

