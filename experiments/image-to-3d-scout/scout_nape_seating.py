"""Seat the broader nape against the hood and match the existing hero sweep."""
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from blender_review import render

S=1.8/518
P="Scout Canon | "
N="Scout Square | "
B="Scout Blocks | "
scene=bpy.context.scene
scene.frame_set(1)
out=Path(sys.argv[-1]).resolve()
amount=float(sys.argv[-2])

def clamp(v):
    return min(1,max(0,v))

upper=scene.objects[B+"Nape · Upper sheet and center lock"]
lower=scene.objects[B+"Nape · Lower sheet and center lock"]
for obj,top in ((upper,True),(lower,False)):
    # The rear silhouette is set in XZ. Moving the sheet toward the neck
    # trims the visible depth in profile while leaving the square ends in place.
    keys=obj.data.shape_keys.key_blocks
    for v in keys[0].data:
        x,y,z=v.co/S
        pull=clamp((405-z)/36) if top else (.65+.35*clamp((367-z)/43))
        v.co.y-=S*amount*pull
    for v in keys[1].data:
        x,y,z=v.co/S
        excursion=clamp((420-z)/60)*clamp((z-299)/33)
        v.co.x-=S*10*excursion*clamp((23-x)/80)
    obj.data.update()

# The body remains in its approved rest stance. The established hero
# shape keys alone fan these outer locks toward camera.
for index,name in enumerate((
    N+"R stepped nape wisp 1", N+"R stepped nape wisp 2",
    P+"R upper swept lock",P+"R middle swept lock",
    N+"R stepped nape wisp 3",P+"R under swept lock",
    N+"R stepped nape wisp 4",P+"R nape side fall",
)):
    obj=scene.objects[name]
    if not obj.data.shape_keys:
        obj.shape_key_add(name="Rest")
    keys=obj.data.shape_keys.key_blocks
    key=keys.get("3/4 loose locks")
    if key is None:
        key=obj.shape_key_add(name="3/4 loose locks")
        key.driver_add("value").driver.expression="1.0 if frame == 2 else 0.0"
    spread=(14,9,11,13,16,15,15,11)[index]
    for v in key.data:
        x,y,z=v.co/S
        fold=clamp((y-37)/42)*clamp((z-314)/24)
        v.co+=S*Vector((-spread*fold,3.4*fold,1.1*fold))
    obj.data.update()

scene["Source-fit pass"]="Fitted rectangular details · seated two-tier nape with hero sweep"
marks={m.name.casefold():m for m in scene.timeline_markers if m.camera}
render(scene,[(marks[v].frame,v,marks[v].camera) for v in ("front","hero","right","back","left")],out)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

