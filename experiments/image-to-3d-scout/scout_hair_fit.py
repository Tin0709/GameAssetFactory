"""Trace the Scout's overlapping nape locks from back, side and 3/4 landmarks."""
from pathlib import Path
import sys
import bmesh
import bpy
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import render

P="Scout Canon | "
N="Scout Square | "
S=1.8/518
scene=bpy.context.scene
scene.frame_set(1)
rig=scene.objects[P+"Rig"]
root=bpy.data.collections[P+"Character"]
OUT=Path(sys.argv[-1]).resolve()
collection=bpy.data.collections.new("Scout • Block-laid hair")
root.children.link(collection)

def hide(o):
    o.hide_render=True
    o.hide_set(True)

for o in scene.objects:
    if o.name.startswith(P+"Nape lock "):
        hide(o)
# The side flaps remain in place behind the temple. The nape section is
# reconstructed as two overlapped tiers with square ends matching the drawing.
mat=bpy.data.materials[N+"64 by 64 materials"]

def hair(label, levels, color, sweep=0.0):
    """Levels are (x, y, z, width, depth). One beveled rectangle per level."""
    vertices=[]
    for x,y,z,w,d in levels:
        a,b=w/2,d/2
        corner=min(1.3,a*.26,b*.31)
        contour=((-a+corner,-b),(a-corner,-b),(a,-b+corner),(a,b-corner),
                 (a-corner,b),(-a+corner,b),(-a,b-corner),(-a,-b+corner))
        vertices.extend(((x+dx)*S,(y+dy)*S,z*S) for dx,dy in contour)
    faces=[tuple(reversed(range(8)))]
    for i in range(len(levels)-1):
        for j in range(8):
            a=i*8+j
            b=i*8+(j+1)%8
            faces.append((a,b,b+8,a+8))
    last=(len(levels)-1)*8
    faces.append(tuple(range(last,last+8)))
    mesh=bpy.data.meshes.new("Scout Nape | "+label)
    mesh.from_pydata(vertices,[],faces)
    bm=bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    mesh.materials.append(mat)
    o=bpy.data.objects.new(mesh.name,mesh)
    collection.objects.link(o)
    joint=rig.data.bones["Head"]
    o.parent=rig
    o.parent_type="BONE"
    o.parent_bone=joint.name
    o.matrix_parent_inverse=(joint.matrix_local@Matrix.Translation((0,joint.length,0))).inverted()
    uv=mesh.uv_layers.new(name="Scout Square UV")
    idx={"hair":4,"hairline":5}[color]
    for face in mesh.polygons:
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co/S
            u=(p.x if abs(face.normal.y)>.4 else p.y-82)
            a=max(1,min(15,8+((u+2*len(label))%29-14)/2.45))
            b=max(1,min(15,1+(p.z-282)/10.3))
            uv.data[loop].uv=((idx%4*16+a)/64,(idx//4*16+b)/64)
    if sweep:
        o.shape_key_add(name="Rest")
        key=o.shape_key_add(name="Loose hair in hero stance")
        for v in key.data:
            x,y,z=v.co/S
            pull=max(0,min(1,(levels[0][2]-z+4)/48))
            v.co.x-=sweep*S*pull
            v.co.y+=2*S*pull
        key.driver_add("value").driver.expression="1.0 if frame == 2 else 0.0"

for sign,tag in ((-1,"R"),(1,"L")):
    hair(tag+" lower tier outside",[(sign*39,67,387,23,20),(sign*42,74,345,17,25),
         (sign*39,76,328,13,22),(sign*35,74,323,11,18)],"hairline",7 if sign<0 else 0)
    hair(tag+" lower tier inner",[(sign*26,73,375,23,20),(sign*28,82,339,24,23),
         (sign*24,84,318,18,24),(sign*20,79,312,13,19)],"hair",10 if sign<0 else 0)
hair("Lower middle lock",[(0,75,371,34,21),(0,86,330,32,24),(0,91,306,25,26),
     (-2,89,300,25,28),(-2,90,292,16,22),(-2,87,284,9,17)],"hairline",3)
for sign,tag in ((-1,"R"),(1,"L")):
    hair(tag+" upper tier outside",[(sign*39,78,436,22,21),(sign*42,84,414,22,24),
         (sign*39,88,392,21,26),(sign*34,89,382,16,20),(sign*33,85,377,13,18)],
         "hairline",6 if sign<0 else 0)
    hair(tag+" upper tier inner",[(sign*21,82,436,25,24),(sign*21,91,405,27,29),
         (sign*18,95,389,23,27),(sign*16,96,372,15,24),(sign*16,94,367,13,21)],
         "hair",7 if sign<0 else 0)
hair("Upper center lock",[(0,84,429,28,22),(0,94,409,27,29),(0,99,386,27,31),
     (-1,101,363,25,28),(-1,100,349,19,24),(-1,96,342,10,21)],"hairline",7)

# Accent the rear shape's little stepped hem by keeping the garment
# olive-shadowed just above it; the rest of the palette pass is maintained.
# Move the roots underneath the cap. The narrow loose step at the end should
# reach the rear view in z, leaving the side profile's depth nearly unchanged.
for o in collection.objects:
    volumes=([key.data for key in o.data.shape_keys.key_blocks]
             if o.data.shape_keys else [o.data.vertices])
    for i,points in enumerate(volumes):
        hero=i>0
        for v in points:
            x,y,z=v.co/S
            y-=max(0,min(1,(y-52)/60))*(15.0 if hero else 28.0)
            if z>412:
                y-=max(0,min(1,(z-412)/25))*9.0
            if hero and x<4:
                x-=max(0,min(1,(392-z)/72))*4.0
            v.co=Vector((x,y,z))*S
    o.data.update() 
scene["Source-fit pass"]="Traced square nape locks set into the hood"
keys={m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(scene,[(keys[v][0],v,keys[v][1]) for v in views],OUT)
scene.render.filepath="//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"Scout.blend"),compress=True,relative_remap=False)


