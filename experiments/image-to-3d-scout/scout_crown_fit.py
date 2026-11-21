"""Final source-derived checks on the cube crown, rim and quiet cloth panels."""
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
N="Scout Square | "
P="Scout Canon | "
S=1.8/518
hood=next(o for o in s.objects if o.name.endswith("hood with returned lining"))
mesh=hood.data
uv=mesh.uv_layers["Scout Cloth UV"]
color=bpy.data.materials[N+"Painted hood weave"]
slot=mesh.materials.find(color.name)
assert slot>=0

# Stitch continuity from the crown onto the forehead, above the existing
# stepped rim. Keep the black sewn lining and ochre binding material slots.
for face in mesh.polygons:
    if max(i//44 for i in face.vertices)!=5 or face.normal.y>-.28 or face.center.z/S<483:
        continue
    face.material_index=slot
    for l in face.loop_indices:
        x,y,z=mesh.vertices[mesh.loops[l].vertex_index].co/S
        u=max(.004,min(.996,(x+88)/176))
        v=max(.004,min(.996,(z-478)/49))
        uv.data[l].uv=(u*.5,v*.5)

# One little irregular raised step on the brow has the higher square in the
# drawing. Relocate the two center cells together so no face is left floating.
for side,offset in (("R",3.0),("L",1.5)):
    tile=s.objects[N+side+" hood bound step 1"]
    for v in tile.data.vertices:
        x,y,z=v.co/S
        lift=offset*max(0,min(1,(z-469)/22))
        v.co=Vector((x,y+.9*lift,z+lift))*S
    tile.data.update()

# Quiet the highlighted strips above the ragged hem. Vary tile phase per visible
# fold while keeping the backing layer in its now-verified collision cage.
primary=s.objects[P+"Long cloak with tapered supporting folds"]
binding=primary.data.uv_layers.get("Scout Square UV")
assert binding
for face in primary.data.polygons:
    if face.material_index!=1 or face.normal.y<.15:
        continue
    # Existing material numbers distinguish dark backing and binding.
    # Keep the marked hem islands; shift their phase along the 16px tile.
    for lo in face.loop_indices:
        old=binding.data[lo].uv
        u=old.x*64
        v=old.y*64
        if not (16<=u<32 and 0<=v<16):
            continue
        z=primary.data.vertices[primary.data.loops[lo].vertex_index].co.z/S
        if z>153.5:
            # One upper wear square loses the bright yellow highlight.
            old.y=(max(1,min(14,v-3.5)))/64

s["Source-fit pass"]="Crown texture continuity and matched cube details"
keys={m.name.casefold():(m.frame,m.camera) for m in s.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(s,[(keys[v][0],v,keys[v][1]) for v in views],out)
s.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

