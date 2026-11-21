"""Refit overlaid cloth after a source-landmark comparison."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render

scene=bpy.context.scene
scene.frame_set(1)
S=1.8/518
P="Scout Canon | "
N="Scout Square | "
out=Path(sys.argv[-1]).resolve()

def clamp(v):
    return max(0,min(1,v))

def deform(obj, fn):
    k=obj.data.shape_keys
    lists=[(s.name,s.data) for s in k.key_blocks] if k else [("",obj.data.vertices)]
    for key,points in lists:
        for v in points:
            p=v.co/S
            v.co=S*Vector(fn(p.x,p.y,p.z,key))
    obj.data.update()

for sign,side in ((-1,"R"),(1,"L")):
    # The bare arm narrows only where the altered sleeve encloses it.
    arm=scene.objects[P+side+" Arm"]
    def enclosed_arm(x,y,z,n):
        upper=clamp((z-270)/53)
        return (x+(sign*80-x)*.45*upper,y*(1-.38*upper),z)
    deform(arm,enclosed_arm)

# Fold the hem into the resting silhouette. Weight the outer folds separately
# and preserve the volume along the garment's front and back faces.
outer_names=("Long cloak with tapered supporting folds","R wrapping skirt of cloak",
             "L wrapping skirt of cloak","R returning side fold","L returning side fold")
for name in outer_names:
    obj=scene.objects[P+name]
    body=obj.data.shape_keys
    def cloth(x,y,z,key):
        lower=clamp((252-z)/108)
        fold=clamp((y-24)/32)
        if key=="Hero drape":
            near=clamp((32-x)/105)
            end=clamp((218-z)/78)
            return x-4.5*near*end,y+4.7*near*end,z-11.6*near*end
        return x,y-8.3*fold*lower,z
    deform(obj,cloth)
    # Expand the dynamic clearance higher up the trousers and keep the
    # neutral profile unpadded. These offsets vanish when the legs are still.
    if name.startswith("Long cloak"):
        ground=body.reference_key
        for cut,sign in (("R",-1),("L",1)):
            key=body.key_blocks["Rear clearance "+cut]
            for target,base in zip(key.data,ground.data):
                x,y,z=base.co/S
                thigh=clamp((265-z)/95)
                side_mask=clamp(.36+sign*x/66)
                target.co.y=base.co.y+.33*thigh*side_mask
                target.co.z=base.co.z+.027*thigh*side_mask
        for d in body.animation_data.drivers:
            if "Rear clearance" in d.data_path:
                d.driver.expression="0 if frame == 2 else max(0, min(1, (-swing + 0.015) / 0.39))"

# Keep the scarf close to the bridge of the nose in profile. This also reduces
# the straight cuff-like tip under the chin.
for name in ("Scarf wrap 1","Scarf wrap 2","Scarf overlap"):
    deform(scene.objects[P+name],lambda x,y,z,_:(x,y+6.7*clamp((-y-40)/36),z+1.5*clamp((-y-40)/32)))

# Round only the thickness of the loose hair cards that project into a side
# view, retaining the little visible squared ends.
for side in ("R","L"):
    for no in (1,2,3):
        lock=scene.objects[N+f"{side} stepped nape wisp {no}"]
        def hair(x,y,z,key):
            outer=clamp((y-35)/57)
            rise=clamp((z-450)/30)
            ends=clamp((450-z)/55)
            return x,y+5.6*outer*rise-3.9*outer*ends,z
        deform(lock,hair)
scene["Source-fit pass"]="Standing cape profile, inset sleeves, and view-specific pose"
keys={m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(scene,[(keys[v][0],v,keys[v][1]) for v in views],out)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

