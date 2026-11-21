"""Fit Scout's standing silhouette and hero pose while retaining the bone rig."""
from pathlib import Path
from math import radians
import sys
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render

P="Scout Canon | "
N="Scout Square | "
S=1.8/518
scene=bpy.context.scene
scene.frame_set(1)
rig=scene.objects[P+"Rig"]
collection=bpy.data.collections[P+"Character"]
out=Path(sys.argv[-2]).resolve()
version=int(sys.argv[-1])

def clamp(v):
    return max(0,min(1,v))

def remap(o,fn):
    m=o.data
    keys=m.shape_keys
    sets=[(key,key.data) for key in keys.key_blocks] if keys else [(None,m.vertices)]
    for key,points in sets:
        for v in points:
            x,y,z=v.co/S
            loc=fn(x,y,z,key.name if key else "")
            v.co=Vector(loc)*S
    m.update()

def driver_value(bone,channel,index,value):
    p=rig.pose.bones[bone]
    p.rotation_mode="XYZ"
    path=p.path_from_id(channel)
    curve=next((fc for fc in rig.animation_data.drivers if fc.data_path==path and fc.array_index==index),None)
    if not curve:
        curve=p.driver_add(channel,index)
    curve.driver.expression=f"{value:.9f} if frame == 2 else 0.0"

def yaw(bone,axis,deg):
    driver_value(bone,"rotation_euler",axis,radians(deg))

for sign,side in ((-1,"R"),(1,"L")):
    sleeve=scene.objects[P+side+" short sleeve"]
    yoke=scene.objects[P+side+" folded shoulder yoke"]
    def sleeve_fit(x,y,z,key):
        # A tighter joint at the shoulders and a nearly vertical cuff.
        k=clamp((z-294)/62)
        k2=clamp((abs(x)-54)/49)
        return x-sign*(3.2+5.3*k)*k2, y*(1-.075*k), z-3.1*k*k2
    def yoke_fit(x,y,z,key):
        k=clamp((abs(x)-46)/60)
        return x-sign*8.8*k, y*.94, z-7.0*k
    remap(sleeve,sleeve_fit)
    remap(yoke,yoke_fit)
    for o in scene.objects:
        if o.name.startswith(N+side+" ") and any(token in o.name for token in ("sleeve cross","cuff edge tape","cuff stitch","front cuff piping")):
            remap(o,sleeve_fit)
        if o.type=="MESH" and (o.name.startswith(P+side+" ") or o.name.startswith(N+side+" ")):
            if any(token in o.name.lower() for token in ("glove","finger","gauntlet","hand wrap","exposed fingers")):
                remap(o,lambda x,y,z,_:(x-sign*3.45*clamp((269-z)/72),y,z+1.7*clamp((218-z)/30)))

def drape_fit(x,y,z,key):
    lower=clamp((268-z)/121)
    outside=clamp((abs(x)-27)/57)
    front_delta=17.5*lower*clamp((y-23)/36)*(1-.28*outside)
    # Shoulder mantle is slightly narrower than the bottom portion.
    x=x*(1-.045*lower-.055*clamp((z-290)/60))
    if key=="Hero drape":
        # The sketch shows the loose lower edges lifted away from the trousers.
        # Move the key's sideward cloth while keeping the shoulders pinned.
        k=clamp((370-z)/174)
        return x-10.7*k, y+10.0*k-.32*front_delta, z+5.8*k
    return x,y-front_delta,z+6.1*lower*outside

for name in ("Long cloak with tapered supporting folds","R returning side fold",
             "L returning side fold","R wrapping skirt of cloak","L wrapping skirt of cloak",
             "Overlapping short mantle"):
    remap(scene.objects[P+name],drape_fit)

# The ankle panels and hips retain existing rig pivots. For the reference
# close-up only, the near arm hangs slightly outward and the far glove shows.
yaw("UpperArm.R",2,-7.5)
yaw("UpperArm.R",0,-8.0)
yaw("UpperArm.L",2,8.5)
yaw("UpperArm.L",0,0.0)
yaw("Leg.L",2,2.6)
yaw("Leg.R",2,-1.2)
driver_value("UpperArm.L","location",1,.014)
driver_value("UpperArm.R","location",1,-.014)
# Keep the head pitch and stance separate from the material-independent fit.
driver_value("Head","location",0,-.010)

# Only the hair that is free below or alongside the cap can sway. The root
# behind the stitched hood band follows the head bone rigidly.
for hair in [o for o in scene.objects if o.type=="MESH" and not o.hide_render and
             any(n in o.name for n in ("stepped nape wisp","swept lock","nape side fall","Nape lock"))]:
    if " L " in " "+hair.name or hair.name.endswith(("01","03","06")):
        continue
    if not hair.data.shape_keys:
        hair.shape_key_add(name="Rest hair")
    key=hair.shape_key_add(name="3/4 loose locks")
    for v,base in zip(key.data,hair.data.shape_keys.reference_key.data):
        x,y,z=base.co/S
        amount=clamp((y-25)/53)*clamp((8-x)/51)
        # The free tails are straighter and pull away from the neck in the hero pose.
        lift=(12 if version==1 else 19)*amount
        v.co=Vector((x-lift,y+6*amount,z+2.5*amount))*S
    key.driver_add("value").driver.expression="1.0 if frame == 2 else 0.0"

scene["Source-fit pass"]="Landmark fit / cape drape and stance"
keys={m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(scene,[(keys[v][0],v,keys[v][1]) for v in views],out)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

