"""Match the hero stance's loose hair and wrist placement without editing rest form."""
from pathlib import Path
import sys
import bpy
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render
s=bpy.context.scene
s.frame_set(1)
out=Path(sys.argv[-1]).resolve()
N="Scout Square | "
P="Scout Canon | "
S=1.8/518
rig=s.objects[P+"Rig"]
strength=float(sys.argv[-2])

for name in ("R stepped nape wisp 1","R stepped nape wisp 2","R stepped nape wisp 3",
             "R stepped nape wisp 4"):
    o=s.objects[N+name]
    if not o.data.shape_keys:
        o.shape_key_add(name="Rest")
    keys=o.data.shape_keys
    key=keys.key_blocks.get("3/4 loose locks")
    if key is None:
        key=o.shape_key_add(name="3/4 loose locks")
        key.driver_add("value").driver.expression="1.0 if frame == 2 else 0.0"
    depth=[p.co.y for p in keys.reference_key.data]
    miny,maxy=min(depth),max(depth)
    for i,(v,base) in enumerate(zip(key.data,keys.reference_key.data)):
        x,y,z=base.co/S
        a=max(0,min(1,(base.co.y-miny)/max(.008,(maxy-miny))))
        height=max(0,min(1,(z-362)/100))
        factor=.28+height*.72
        if i>=len(key.data)//2:
            factor*=.57
        v.co.x-=strength*S*a*factor
        v.co.y+=S*3.4*a
mod=next(x for x in rig.animation_data.drivers if 'UpperArm.L' in x.data_path and x.data_path.endswith("location") and x.array_index==1)
mod.driver.expression="0.034 if frame == 2 else 0.0"
s["Source-fit pass"]="Pose-specific hair sweep and far cuff alignment"
keys={m.name.casefold():(m.frame,m.camera) for m in s.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(s,[(keys[v][0],v,keys[v][1]) for v in views],out)
s.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

