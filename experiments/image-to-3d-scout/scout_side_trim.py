"""Compare square side tresses against the existing swept locks."""
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from blender_review import render

S=1.8/518
P="Scout Canon | "
N="Scout Square | "
B="Scout Blocks | "
scene=bpy.context.scene
scene.frame_set(1)
rig=scene.objects[P+"Rig"]
collection=bpy.data.collections.new("Scout · Folded side locks")
bpy.data.collections[P+"Character"].children.link(collection)
out=Path(sys.argv[-1]).resolve()
strength=float(sys.argv[-2])
material=bpy.data.materials["Scout · Broad nape locks"]

def lock(side,sign,label,outline,axis,thickness):
    name=B+side+" side lock · "+label
    sections=len(outline)
    # Keep each silhouette riser vertical; across the cross section, tuck
    # the roots in beneath the side of the hood.
    coords=[]
    for surface in (-1,1):
        for y,z in outline:
            pull=min(1,max(0,(y-50)/56))
            x=axis + 2.9*pull+surface*thickness/2
            coords.append((sign*x,y,z))
    faces=[tuple(range(sections)),tuple(range(sections,sections*2))]
    faces.extend((i,(i+1)%sections,(i+1)%sections+sections,i+sections) for i in range(sections))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([S*Vector(p) for p in coords],[],faces)
    bm=bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    mesh.materials.append(material)
    obj=bpy.data.objects.new(name,mesh)
    collection.objects.link(obj)
    head=rig.data.bones["Head"]
    obj.parent=rig
    obj.parent_type="BONE"
    obj.parent_bone=head.name
    obj.matrix_parent_inverse=(head.matrix_local@Matrix.Translation((0,head.length,0))).inverted()
    uv=mesh.uv_layers.new(name="Scout Square UV")
    low=min(z for y,z in outline)
    for poly in mesh.polygons:
        cell=5 if abs(poly.normal.x)>.6 else 4
        for loop in poly.loop_indices:
            x,y,z=mesh.vertices[mesh.loops[loop].vertex_index].co/S
            u=1.6+(y-44)*.18
            v=1.8+(z-low)*.20
            uv.data[loop].uv=((cell%4*16+min(14.5,max(1,u)))/64,
                              (cell//4*16+min(14.5,v))/64)
    if sign<0:
        obj.shape_key_add(name="Rest")
        key=obj.shape_key_add(name="Hero · swept side locks")
        for vert in key.data:
            x,y,z=vert.co/S
            pull=max(0,min(1,(y-46)/36))
            vert.co+=S*Vector((-strength*pull,4*pull,1*pull))
        key.driver_add("value").driver.expression="1.0 if frame == 2 else 0.0"

    # Pull the exposed ends just below the rear seam in the neutral pose.
    # The existing hero stance leaves the ends loose above the collar.
    neutral = obj.data.shape_keys.reference_key.data if obj.data.shape_keys else obj.data.vertices
    for vertex in neutral:
        x,y,z = vertex.co/S
        fold = min(1,max(0,(y-58)/25))
        vertex.co.y-=S*7.25*fold
        vertex.co.x=sign*S*(axis+(abs(x)-axis)*.79)
    obj.data.update()

for side,sign in (("R",-1),("L",1)):
    for name in (P+side+" upper swept lock",N+side+" stepped nape wisp 1",N+side+" stepped nape wisp 2"):
        obj=scene.objects[name]
        obj.hide_render=True
        obj.hide_set(True)
    lock(side,sign,"upper",[(43,497),(57,497),(57,488),(66,488),(66,482),
                           (74,482),(74,475),(83,475),(83,467),(75,467),(75,460),
                           (67,460),(67,470),(57,470),(57,477),(50,477),(50,483),(43,483)],61,10)
    lock(side,sign,"middle",[(51,471),(64,471),(64,464),(74,464),(74,457),
                            (82,457),(82,449),(92,449),(92,441),(99,441),(99,433),
                            (91,433),(91,423),(79,423),(79,433),(72,433),(72,440),(64,440),
                            (64,447),(51,447)],57,13)

scene["Source-fit pass"]="Fitted rectangular details · broad nape and rebuilt side tresses"
marks={m.name.casefold():m for m in scene.timeline_markers if m.camera}
render(scene,[(marks[v].frame,v,marks[v].camera) for v in ("front","hero","right","back","left")],out)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)


