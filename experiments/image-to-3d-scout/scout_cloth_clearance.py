"""Resolve cloak contact against the posed trousers with local geometry nodes."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render

scene=bpy.context.scene
scene.frame_set(1)
P="Scout Canon | "
N="Scout Square | "
OUT=Path(sys.argv[-1]).resolve()
S=1.8/518
pants=[scene.objects[P+s+" trouser"] for s in ("R","L")]
cloak=scene.objects[P+"Long cloak with tapered supporting folds"]
variant=int(sys.argv[-2])
for link in cloak.data.shape_keys.animation_data.drivers:
    if "Rear clearance" in link.data_path:
        link.driver.expression="0.0"

# Keep each local point directly above the leg's rear envelope. Extra x/z
# samples create clearance one small tile beyond the trousers' edges.
def install(obj):
    mesh=obj.data
    wall=mesh.attributes.new("Scout cloth depth above lining","FLOAT","POINT")
    half=len(mesh.vertices)//2
    for i in range(half):
        wall.data[i].value=max(0,mesh.vertices[i].co.y-mesh.vertices[i+half].co.y)
        wall.data[i+half].value=0
    tree=bpy.data.node_groups.new("Scout · Cape over posed trousers", "GeometryNodeTree")
    tree.interface.new_socket(name="Geometry",in_out="INPUT",socket_type="NodeSocketGeometry")
    tree.interface.new_socket(name="Geometry",in_out="OUTPUT",socket_type="NodeSocketGeometry")
    nodes=tree.nodes
    def node(kind,label,x,y):
        n=nodes.new(kind)
        n.label=label
        n.location=(x,y)
        return n
    def bind(output,inp):
        tree.links.new(output,inp)

    input=node("NodeGroupInput","Folded cloth",-1200,400)
    output=node("NodeGroupOutput","Cleared garment",1240,400)
    position=node("GeometryNodeInputPosition","Cloth vertex",-1190,130)
    local=node("ShaderNodeSeparateXYZ","Current cloth depth",-430,510)
    bind(position.outputs["Position"],local.inputs["Vector"])
    thickness=node("GeometryNodeInputNamedAttribute","Keep the two cloth faces apart",-660,550)
    thickness.data_type="FLOAT"
    thickness.inputs["Name"].default_value="Scout cloth depth above lining"
    inner_depth=node("ShaderNodeMath","Depth of inner lining",-220,505)
    inner_depth.operation="SUBTRACT"
    bind(local.outputs["Y"],inner_depth.inputs[0])
    bind(thickness.outputs["Attribute"],inner_depth.inputs[1])
    models=node("GeometryNodeJoinGeometry","Two posed trouser volumes",-940,-105)
    for j,pant in enumerate(pants):
        source=node("GeometryNodeObjectInfo",pant.name,-1180,-110-j*220)
        source.transform_space="RELATIVE"
        source.inputs["Object"].default_value=pant
        source.inputs["As Instance"].default_value=False
        bind(source.outputs["Geometry"],models.inputs["Geometry"])
    # Limit the deformation to the lower cloth next to the pants.
    distance=[0, -.021, .021]
    if variant>=2:
        distance=[0,-.023,.023,-.042,.042,0,0]
    margins=[]
    for i,offset in enumerate(distance):
        y=-50-410*i
        origin=node("ShaderNodeVectorMath","Back-to-front origin",-690,y+60)
        origin.operation="ADD"
        origin.inputs[1].default_value=(offset,.82,.026 if i in (1,4,5) else -.026 if i in (2,3,6) else 0.0)
        bind(position.outputs["Position"],origin.inputs[0])
        ray=node("GeometryNodeRaycast","Rear trouser face",-440,y)
        ray.inputs["Ray Direction"].default_value=(0,-1,0)
        ray.inputs["Ray Length"].default_value=1.23
        bind(models.outputs["Geometry"],ray.inputs["Target Geometry"])
        bind(origin.outputs["Vector"],ray.inputs["Source Position"])
        separate=node("ShaderNodeSeparateXYZ","Projected rear face",-200,y+80)
        bind(ray.outputs["Hit Position"],separate.inputs["Vector"])
        gap=node("ShaderNodeMath","Cloth thickness and margin",-20,y+75)
        gap.operation="ADD"
        gap.inputs[1].default_value=.018+(0.006 if variant>=2 else 0.0)
        bind(separate.outputs["Y"],gap.inputs[0])
        sub=node("ShaderNodeMath","Distance behind leg",170,y+70)
        sub.operation="SUBTRACT"
        bind(gap.outputs[0],sub.inputs[0])
        bind(inner_depth.outputs[0],sub.inputs[1])
        switch=node("GeometryNodeSwitch","Only act on a trouser hit",355,y+80)
        switch.input_type="FLOAT"
        bind(ray.outputs["Is Hit"],switch.inputs["Switch"])
        switch.inputs["False"].default_value=0.0
        bind(sub.outputs[0],switch.inputs["True"])
        margins.append(switch.outputs[0])
    amount=0.0
    for i,socket in enumerate(margins):
        limit=node("ShaderNodeMath","Keep outside both legs",555+95*i,270-135*i)
        limit.operation="MAXIMUM"
        bind(socket,limit.inputs[0])
        if i==0:
            limit.inputs[1].default_value=0.0
        else:
            bind(amount,limit.inputs[1])
        amount=limit.outputs[0]
    vector=node("ShaderNodeCombineXYZ","Release only toward back",850,480)
    bind(amount,vector.inputs["Y"])
    place=node("GeometryNodeSetPosition","Slide the cloth around the posed leg",1060,390)
    bind(input.outputs["Geometry"],place.inputs["Geometry"])
    bind(vector.outputs[0],place.inputs["Offset"])
    bind(place.outputs["Geometry"],output.inputs["Geometry"])
    # Linear subdivision retains the flat polygons, the sharp hem, and its UVs.
    sub=obj.modifiers.new("Linear subdivisions for fold clearance","SUBSURF")
    sub.subdivision_type="SIMPLE"
    sub.levels=2
    sub.render_levels=2
    guard=obj.modifiers.new("Cape clearance around the thighs","NODES")
    guard.node_group=tree

install(cloak)
# The crown stays olive from the rear. Pull back the just-visible roots
# beneath the gusset in the rest pose, while retaining the loose ends.
for side in ("R","L"):
    for version in (1,2):
        lock=scene.objects[N+f"{side} stepped nape wisp {version}"]
        mesh=lock.data
        keys=mesh.shape_keys
        point_lists=([key.data for key in keys.key_blocks] if keys else [mesh.vertices])
        for points in point_lists:
            for v in points:
                x,y,z=v.co/S
                t=max(0,min(1,(z-448)/35))
                v.co.y-=S*6.3*t
        mesh.update()
scene["Source-fit pass"]="Contour-matched cape with pose-driven cloth clearance"
keys={m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(scene,[(keys[v][0],v,keys[v][1]) for v in views],OUT)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"Scout.blend"),compress=True,relative_remap=False)


