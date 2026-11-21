"""Calibrate the studio pools, retaining the locked five review cameras."""
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
p="Scout Canon | "
lights={
    "Warm key":((-1.70,-3.18,3.70),(0,0,1.03),342,(1,.84,.73),1.48),
    "Front fill":((2.05,-3.51,1.64),(0,0,1.17),105,(1,.881,.796),2.70),
    "Hair rim":((-1.62,2.06,3.13),(0,0,1.20),243,(1,.77,.635),1.21),
    "Rear fill":((1.94,2.54,2.37),(0,0,1.10),59,(1,.937,.876),2.19)
}
for name,(pos,aim,power,color,size) in lights.items():
    o=s.objects[p+name]
    o.location=pos
    o.rotation_euler=(Vector(aim)-o.location).to_track_quat("-Z","Y").to_euler()
    o.data.energy=power
    o.data.color=color
    o.data.size=size
s["Source-fit pass"]="Measured studio calibration and stable cape fit"
keys={m.name.casefold():(m.frame,m.camera) for m in s.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(s,[(keys[v][0],v,keys[v][1]) for v in views],out)
s.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

