"""Calibrate the pixel face and the open hood on the rigged version."""
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

def clamp(n):
    return max(.002,min(.998,n))
def vertex_map(o,fn):
    for v in o.data.vertices:
        v.co=Vector(fn(*(v.co/S)))*S
    o.data.update()
def uv_material():
    m=bpy.data.materials.new(N+"Pixel complexion")
    m.use_nodes=True
    nodes=m.node_tree.nodes
    tex=nodes.new("ShaderNodeTexImage")
    tex.image=bpy.data.images.load(str(out.parent/"tones/calibrated/face.png"),check_existing=False)
    tex.image.pack()
    tex.interpolation="Closest"
    tex.extension="EXTEND"
    uv=nodes.new("ShaderNodeUVMap")
    uv.uv_map="Scout Complexion UV"
    bs=nodes.get("Principled BSDF")
    bs.inputs["Roughness"].default_value=.91
    bs.inputs["Specular IOR Level"].default_value=.16
    m.node_tree.links.new(uv.outputs["UV"],tex.inputs["Vector"])
    m.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
    return m
face=scene.objects[P+"Face"]
material=uv_material()

def assign(o,col,row,x0,x1,z0,z1,front_only=False):
    mesh=o.data
    if front_only:
        mesh.materials.append(material)
        mi=len(mesh.materials)-1
    else:
        mesh.materials.clear()
        mesh.materials.append(material)
        mi=0
    uv=mesh.uv_layers.new(name="Scout Complexion UV")
    for f in mesh.polygons:
        if front_only and f.normal.y>-.56:
            continue
        f.material_index=mi
        for l in f.loop_indices:
            x,y,z=mesh.vertices[mesh.loops[l].vertex_index].co/S
            u=clamp((x-x0)/(x1-x0))
            v=clamp((z-z0)/(z1-z0))
            uv.data[l].uv=((u+col)/2,(v+row)/2)

assign(face,0,1,-52,52,394,464,True)
for s,sign in (("R",-1),("L",1)):
    eye=scene.objects[N+s+" eye white"]
    pupil=scene.objects[N+s+" eye pupil"]
    assign(eye,1,1,sign*27-11,sign*27+11,401.5,426)
    assign(pupil,0,0,sign*20.2-6.5,sign*20.2+6.5,402,426)
    brow=scene.objects[N+s+" pixel brow"]
    def brow_fit(x,y,z):
        f=clamp((abs(x)-11)/34)
        mid=431.7+max(0,abs(x)-23)*.13
        return x,y-.35*f,mid+(z-mid)*(1.2+.16*f)+.65*f
    vertex_map(brow,brow_fit)
mouth=scene.objects[N+"Mouth pixel"]
assign(mouth,1,0,-3,3,396,401)

# Bring the uneven center fringe down to the source landmark. The lower
# edges keep their existing shallow angular cuts and fitted UV islands.
center=scene.objects[N+"Forelock 3"]
vertex_map(center,lambda x,y,z:(x+5.2*clamp((x+8)/19)*clamp((472-z)/30),
                               y-.45*clamp((460-z)/24),
                               z-6.5*clamp((470-z)/30)))
side=scene.objects[N+"Forelock 4"]
vertex_map(side,lambda x,y,z:(x-1.75*clamp((33-x)/19),y,z-3.8*clamp((469-z)/31)))

# The drawing has a horizontal upper wrap in the front view. Tilt belongs
# to the lower fold and to the head's hero stance.
wrap=scene.objects[P+"Scarf wrap 1"]
vertex_map(wrap,lambda x,y,z:(x,y,z+.086*x*clamp((-y-38)/31)))
scene["Source-fit pass"]="Projected pixel complexion, forehead locks and square scarf edge"
keys={m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(scene,[(keys[v][0],v,keys[v][1]) for v in views],out)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

