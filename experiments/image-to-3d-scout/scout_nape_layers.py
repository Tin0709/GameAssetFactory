"""Fit the Scout's two broad rear hair layers and the side locks from the turnaround."""
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render

P = "Scout Canon | "
N = "Scout Square | "
B = "Scout Blocks | "
S = 1.8/518
scene = bpy.context.scene
scene.frame_set(1)
rig = scene.objects[P+"Rig"]
collection = bpy.data.collections.new("Scout · Layered nape")
bpy.data.collections[P+"Character"].children.link(collection)
mode, folder = sys.argv[-2:]
out = Path(folder).resolve()

def hide(obj):
    obj.hide_render = True
    obj.hide_set(True)

def clamp(value):
    return max(0,min(1,value))

for obj in scene.objects:
    if obj.name.startswith(B+"Nape · "):
        hide(obj)

mat=bpy.data.materials[N+"64 by 64 materials"].copy()
mat.name="Scout · Broad nape locks"
nodes=mat.node_tree.nodes
tex=next(n for n in nodes if n.type=="TEX_IMAGE")
bsdf=next(n for n in nodes if n.type=="BSDF_PRINCIPLED")
paint=nodes.new("ShaderNodeMixRGB")
paint.name="Chestnut hair dye"
paint.blend_type="MULTIPLY"
paint.inputs[0].default_value=1
paint.inputs[2].default_value=(.87,.87,.85,1)
mat.node_tree.links.new(tex.outputs["Color"],paint.inputs[1])
mat.node_tree.links.new(paint.outputs[0],bsdf.inputs["Base Color"])

def hair_layer(label,columns,rise,rear,hero_sweep):
    """Build a closed strip with squared steps, rounded in depth across the head."""
    slices=sorted({z for _,_,lo,hi in columns for z in (lo,hi)} | set(rise))
    cells={(i,j) for i,(_,_,lo,hi) in enumerate(columns) for j,z in enumerate(slices[:-1])
           if z>=lo and slices[j+1]<=hi}
    edges=[columns[0][0]]+[hi for _,hi,_,_ in columns]
    points, lookup, faces, tints = [], {}, [], []

    def ind(i,j,back):
        key=(i,j,back)
        if key not in lookup:
            x,z=edges[i],slices[j]
            y=rear(x,z) - (0 if back else 16)
            lookup[key]=len(points)
            points.append((x,y,z))
        return lookup[key]

    def quad(corners,tint):
        faces.append(tuple(ind(*p) for p in corners))
        tints.append(tint)

    for i,j in sorted(cells):
        outline=((i,j),(i+1,j),(i+1,j+1),(i,j+1))
        tint=5 if i not in (0,len(columns)-1) else 4
        quad([(*p,False) for p in outline],4)
        quad([(*p,True) for p in reversed(outline)],tint)
        for k,(dx,dz) in enumerate(((0,-1),(1,0),(0,1),(-1,0))):
            if (i+dx,j+dz) in cells:
                continue
            a,b=outline[k],outline[(k+1)%4]
            quad([(*b,False),(*a,False),(*a,True),(*b,True)],4)

    name=B+"Nape · "+label
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([Vector(p)*S for p in points],[],faces)
    mesh.update()
    mesh.materials.append(mat)
    obj=bpy.data.objects.new(name,mesh)
    collection.objects.link(obj)
    head=rig.data.bones["Head"]
    obj.parent=rig
    obj.parent_type="BONE"
    obj.parent_bone=head.name
    obj.matrix_parent_inverse=(head.matrix_local @ Matrix.Translation((0,head.length,0))).inverted()
    uv=mesh.uv_layers.new(name="Scout Square UV")
    z0=min(z for x,y,z in points)
    for face in mesh.polygons:
        cell=tints[face.index]
        for loop in face.loop_indices:
            x,y,z=points[mesh.loops[loop].vertex_index]
            u=clamp((x+49)/98)*12+1.5
            v=clamp((z-z0)/112)*12+1.25
            uv.data[loop].uv=((cell%4*16+u)/64,(cell//4*16+v)/64)
    obj.shape_key_add(name="Rest")
    loose=obj.shape_key_add(name="Loose nape layers in hero stance")
    for v in loose.data:
        x,y,z=v.co/S
        weight=clamp((430-z)/77)
        v.co.x-=S*hero_sweep*weight*(.6+.4*clamp((45-x)/90))
        v.co.y+=S*2.4*weight
    loose.driver_add("value").driver.expression="1.0 if frame == 2 else 0.0"

def upper_depth(x,z):
    edge=abs(x)
    bend=clamp((433-z)/26)
    overlap=4.5*clamp((392-z)/34)
    return 89 + 12.4*bend - .16*edge + overlap*(1-.55*clamp(edge/47))

def lower_depth(x,z):
    edge=abs(x)
    fall=clamp((367-z)/57)
    return 84 + 11.5*fall - .14*edge

hair_layer("Upper sheet and center lock",[
    (-46,-34,373,433),(-34,-19,368,439),(-19,-13,357,441),
    (-13,-8,348,441),(-8,9,342,441),(9,15,351,441),(15,22,363,438),
    (22,35,369,437),(35,46,377,435)
],(387,405,417,427),upper_depth,11)

hair_layer("Lower sheet and center lock",[
    (-43,-32,325,376),(-32,-21,316,384),(-21,-14,326,386),
    (-14,-8,294,383),(-8,6,283,381),(6,13,295,381),(13,19,312,383),
    (19,31,322,383),(31,43,329,383)
],(309,339,352,371),lower_depth,13)

# Flatten the side peaks of the rear opening so its center sits below the
# outside attachment points, with the same drop as the source back drawing.
back=scene.objects[P+"Rear folded hood panel"]
for vertex,z in ((38,427),(39,430),(40,418),(41,430),(42,427)):
    back.data.vertices[vertex].co.z=z*S
back.data.update()

for sign,side in ((-1,"R"),(1,"L")):
    # Keep the hanging side locks in profile. Tuck the edges hidden by the
    # upper sheet inward to eliminate small competing clumps in the rear view.
    tags = [P+side+" "+s for s in ("middle swept lock","under swept lock","nape side fall")]
    tags += [N+f"{side} stepped nape wisp {i}" for i in (3,4)]
    for name in tags:
        obj=scene.objects[name]
        shape=obj.data.shape_keys
        variants= [k.data for k in shape.key_blocks] if shape else [obj.data.vertices]
        for j,points in enumerate(variants):
            for v in points:
                x,y,z=v.co/S
                amount=clamp((y-58)/24)*clamp((448-z)/28)
                if j>0:
                    amount*=.53
                v.co.x-=sign*S*13.0*amount
                v.co.y-=S*8.5*amount
        obj.data.update()

if mode=="profiles":
    # Make room on the sides for the red locks above the collar. Preserve
    # the rear-view perimeter and the square front crown as the side wall recedes.
    ortho=[back,scene.objects[P+"Hood gusset R"],scene.objects[P+"Hood gusset L"],
           next(o for o in scene.objects if o.name.endswith("hood with returned lining"))]
    for obj in ortho:
        for v in obj.data.vertices:
            x,y,z=v.co/S
            lift=clamp((z-408)/40)*clamp((511-z)/21)
            v.co.y-=S*7.8*clamp((y-38)/48)*lift
        obj.data.update()
    for sign,side in ((-1,"R"),(1,"L")):
        names=[P+side+" upper swept lock",P+side+" middle swept lock"]
        names += [N+f"{side} stepped nape wisp {i}" for i in (1,2,3)]
        for index,name in enumerate(names):
            obj=scene.objects[name]
            shape=obj.data.shape_keys
            targets=[k.data for k in shape.key_blocks] if shape else [obj.data.vertices]
            for j,points in enumerate(targets):
                for vertex in points:
                    x,y,z=vertex.co/S
                    band=clamp((z-380)/40)*clamp((510-z)/27)
                    fall=clamp((y-36)/40)
                    distance=((18 if index in (0,2) else 11)*band*fall)
                    vertex.co.y+=S*distance
                    if j>0 and sign<0:
                        vertex.co.x-=S*5.4*band*fall
            obj.data.update()

scene["Source-fit pass"]="Fitted rectangular details · two broad nape layers"
keys={m.name.casefold():m for m in scene.timeline_markers if m.camera}
render(scene,[(keys[v].frame,v,keys[v].camera) for v in ("front","hero","right","back","left")],out)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

