"""Balance source-matched near-view lighting and boot thickness."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render
scene=bpy.context.scene
scene.frame_set(1)
out=Path(sys.argv[-1]).resolve()
P="Scout Canon | "
N="Scout Square | "
S=1.8/518
amount=float(sys.argv[-2])

lights={
    "Warm key":((-2.20,-2.75,3.92),(0,0,1.05),316,(1,.83,.703),1.71),
    "Front fill":((2.00,-3.50,1.67),(0,0,1.16),94,(1,.881,.805),2.73),
    "Hair rim":((-1.62,2.06,3.13),(0,0,1.20),259,(1,.77,.635),1.28),
    "Rear fill":((1.94,2.54,2.37),(0,0,1.10),69,(1,.937,.876),2.19)
}
for name,(pos,aim,power,color,size) in lights.items():
    o=scene.objects[P+name]
    o.location=pos
    o.rotation_euler=(Vector(aim)-o.location).to_track_quat("-Z","Y").to_euler()
    o.data.energy=power
    o.data.color=color
    o.data.size=size

def deform(ob,fn):
    for v in ob.data.vertices:
        v.co=Vector(fn(*(v.co/S)))*S
    ob.data.update()

# Keep the sole and the hinge on the same axis. Expand just the raised
# front vamp, column and cuffs in the region visible in the side orthos.
tags=("boot shaft","boot collar","instep strap mass"," toe","toe front step","toe polished lip",
      "ankle front strap","broad instep buckle","outer ankle metal","lower ankle side")
for o in scene.objects:
    if o.type!="MESH" or o.hide_render or not any(tag in o.name for tag in tags):
        continue
    def vamp(x,y,z):
        front=max(0,min(1,(-y-22)/16))
        upper=max(0,min(1,(z-18)/25))
        return x,y-amount*front*upper,z
    deform(o,vamp)

scene["Source-fit pass"]="Balanced colors with raised square boot vamps"
keys={m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(scene,[(keys[v][0],v,keys[v][1]) for v in views],out)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

