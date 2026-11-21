"""Apply calibrated packed textures on the isolated Scout project."""
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
textures=out.parent/"tones/calibrated"
S=1.8/518
P="Scout Canon | "
N="Scout Square | "
materials={
    "hood":N+"Painted hood weave",
    "older_hood":"Scout Hood Study | Selected hood material 64x64",
    "outer":"Scout Outerwear | Olive cloth",
    "trim":N+"64 by 64 materials",
    "body":"MAT-Scout Tailoring nearest",
}
def load(name,m):
    tex=next(n for n in m.node_tree.nodes if n.type=="TEX_IMAGE")
    im=bpy.data.images.load(str(textures/(name+".png")),check_existing=False)
    im.name=f"Scout • Calibrated {name} 64x64"
    im.pack()
    tex.image=im
    tex.interpolation="Closest"
for name,label in materials.items():
    load(name,bpy.data.materials[label])
trim=bpy.data.materials[materials["trim"]]
boot=trim.copy()
boot.name=N+"Boot leather 64 by 64"
load("boot",boot)
for o in scene.objects:
    if o.type!="MESH":
        continue
    if any(word in o.name.lower() for word in (
        "boot shaft","outsole","boot collar"," toe"," ankle","step buckle","instep","sole stitched","gaiter")):
        for slot in o.material_slots:
            if slot.material==trim:
                slot.material=boot
skin=bpy.data.materials[P+"skin"]
skin=skin.copy()
skin.name=N+"Warm face skin"
o=scene.objects[P+"Face"]
o.data.materials[0]=skin
bs=skin.node_tree.nodes.get("Principled BSDF")
base=bs.inputs["Base Color"].default_value
base[0]=min(1,base[0]*1.24)
base[1]=min(1,base[1]*1.095)
base[2]=min(1,base[2]*1.035)
# Preserve the packed cloth, use actual stepped front profile for the eyebrows.
for side,sign in (("R",-1),("L",1)):
    white=scene.objects[N+side+" eye white"]
    for v in white.data.vertices:
        x,y,z=v.co/S
        x=sign*(27+(abs(x)-27)*.90)
        z=414+(z-414)*.94
        v.co=Vector((x,y,z))*S
    brow=scene.objects[N+side+" pixel brow"]
    for v in brow.data.vertices:
        x,y,z=v.co/S
        mid=431.7+max(0,abs(x)-23)*.13
        v.co=Vector((x,y,mid+(z-mid)*.72))*S
mouth=scene.objects[N+"Mouth pixel"]
for v in mouth.data.vertices:
    x,y,z=v.co/S
    v.co=Vector((x*.79,y,398.6+(z-398.6)*.72))*S
for name in ("front","hero","right","back","left"):
    assert scene.timeline_markers.get(name.title())
scene["Source-fit pass"]="Measured value and hue calibration"
keys={m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(scene,[(keys[v][0],v,keys[v][1]) for v in views],out)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

