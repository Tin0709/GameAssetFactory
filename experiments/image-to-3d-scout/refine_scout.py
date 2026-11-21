"""Apply a 64-pixel material pass and garment repairs on the independent Scout rig."""
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from blender_review import append_scene, render
import fit_cape

SOURCE=Path(sys.argv[-3]).resolve()
OUT=Path(sys.argv[-2]).resolve()
PASS=int(sys.argv[-1])
OUT.mkdir(parents=True,exist_ok=True)
S=1.8/518
P="Scout Canon | "
scene=append_scene(SOURCE,"Scout - Canonical Silhouette")
rig=scene.objects[P+"Rig"]
root=scene.collection.children[P+"Character"]
group=bpy.data.collections.new("COL-Scout tailoring")
root.children.link(group)
samples={
 "olive":("504930","575035","625737","675b3e","41402d"),
 "darkcloth":("393529","46402b","504833","584c30","312b20"),
 "scarf":("353628","40402c","4c4931","514e32","302e24"),
 "scarf2":("42442f","4c4a32","535037","5a5338","353725"),
 "undertunic":("b7805e","c09a80","cdaa8f","d3b094","ad775b"),
 "skin":("cb8c6f","da9b7a","e2a580","e6ad89","bf7d60"),
 "cream":("be9a87","cda894","d2b19e","d9b9a4","ad8573"),
 "trouser":("342c2f","3c3336","46393b","4a3b3b","30272b"),
 "leather":("56382b","604031","6c4433","764832","4c3228"),
 "pouch":("663e2b","75462e","885436","945b3b","583526"),
 "boot":("5c392c","67402d","774832","81523b","503329"),
 "sole":("3d2d26","49332a","50392d","533b30","362722"),
 "glove":("402e2d","4d3332","543832","614036","352727"),
 "hair":("372526","412829","4d2e2b","58342e","2e2021"),
 "locks":("462b2b","553033","633a37","703e39","372427"),
 "locklight":("4f3030","5c3433","6b3d36","76463d","3e2729"),
}
layouts=[
 ["00111210","01122210","01211110","01112221","22111100","21100110","01110011","10011104"],
 ["11221001","11211210","00112210","00121111","01111122","20011111","22111001","22211001"],
 ["01122001","01122111","01211100","12221110","11122211","00112111","10111101","00011110"],
 ["21211111","01111101","01110101","10112210","11122221","00122211","00111222","01111004"],
]
def srgb(h):
    rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return [v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
atlas=bpy.data.images.new("Scout • Tailoring atlas 64x64",width=64,height=64,alpha=False)
atlas.colorspace_settings.name='sRGB'
rgba=[1.0]*(64*64*4)
for idx,(name,palette) in enumerate(samples.items()):
    colors=[[int(c[i:i+2],16)/255 for i in (0,2,4)] for c in palette]
    pattern=layouts[idx%len(layouts)]
    for row in range(16):
        for col in range(16):
            px=(idx%4)*16+col
            py=(idx//4)*16+row
            index=(py*64+px)*4
            rgba[index:index+3]=colors[int(pattern[row//2][col//2])]
atlas.pixels.foreach_set(rgba)
atlas.pack()
textured=bpy.data.materials.new("MAT-Scout Tailoring nearest")
textured.diffuse_color=(.17,.12,.08,1)
textured.use_nodes=True
nodes=textured.node_tree.nodes
bs=nodes.get("Principled BSDF")
bs.inputs["Roughness"].default_value=.87
bs.inputs["Specular IOR Level"].default_value=.24
uv=nodes.new("ShaderNodeUVMap")
uv.uv_map="Scout Tailoring UV"
tex=nodes.new("ShaderNodeTexImage")
tex.image=atlas
tex.interpolation="Closest"
tex.extension="EXTEND"
textured.node_tree.links.new(uv.outputs["UV"],tex.inputs["Vector"])
textured.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])

def use_atlas(o,color,scale=7.5):
    mesh=o.data
    index=list(samples).index(color)
    layer=mesh.uv_layers.new(name="Scout Tailoring UV")
    coords=[v.co/S for v in mesh.vertices]
    mesh.materials.clear()
    mesh.materials.append(textured)
    for face in mesh.polygons:
        face.material_index=0
        dominant=max(range(3),key=lambda i:abs(face.normal[i]))
        axes={0:(1,2),1:(0,2),2:(0,1)}[dominant]
        # Island offsets anchored within a material cell. Texels stay flat.
        for loop in face.loop_indices:
            v=coords[mesh.loops[loop].vertex_index]
            u=0.12+(v[axes[0]]/scale+10)%15.76
            w=0.12+(v[axes[1]]/scale+7)%15.76
            # Avoid wrapping a UV island across a tile boundary.
            c0=sum(coords[i][axes[0]] for i in face.vertices)/len(face.vertices)
            c1=sum(coords[i][axes[1]] for i in face.vertices)/len(face.vertices)
            u=max(.15,min(15.85, ((c0/scale+10)%11)+2+(v[axes[0]]-c0)/scale))
            w=max(.15,min(15.85, ((c1/scale+7)%11)+2+(v[axes[1]]-c1)/scale))
            layer.data[loop].uv=((index%4*16+u)/64,(index//4*16+w)/64)

# Append the exact packed hood/outerwear UV materials by name if unavailable as scene dependencies.
source_materials={
 "hood":"Scout Hood Study | Selected hood material 64x64",
 "outer":"Scout Outerwear | Olive cloth",
}
with bpy.data.libraries.load(str(SOURCE)) as (source,destination):
    destination.materials=[name for name in source_materials.values() if name not in bpy.data.materials]
for o in root.all_objects:
    if o.type!="MESH":
        continue
    name=o.name.removeprefix(P)
    m=o.data.materials[0].name.removeprefix(P)
    if o.data.uv_layers:
        o.data.materials.clear()
        o.data.materials.append(bpy.data.materials[source_materials["hood" if "·" in name else "outer"]])
        for face in o.data.polygons:
            face.material_index=0
    elif m in samples and not (m=="skin" and name=="Face"):
        use_atlas(o,m,8.5 if "cloak" in name.lower() else 5.9)

def piece(name,points,faces,bone,color):
    mesh=bpy.data.meshes.new("GEO-"+name)
    mesh.from_pydata([tuple(v*S for v in p) for p in points],[],faces)
    bm=bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj=bpy.data.objects.new(mesh.name,mesh)
    group.objects.link(obj)
    bind=rig.data.bones[bone]
    obj.parent=rig
    obj.parent_type="BONE"
    obj.parent_bone=bone
    obj.matrix_parent_inverse=(bind.matrix_local @ Matrix.Translation((0,bind.length,0))).inverted()
    if color in samples:
        use_atlas(obj,color,5)
    else:
        mesh.materials.append(bpy.data.materials[P+color])
    return obj

def block(name,x,y,z,w,d,h,bone,material):
    a,b,c=(w/2,d/2,h/2)
    vs=[(x+i*a,y+j*b,z+k*c) for i,j,k in ((-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1))]
    f=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return piece(name,vs,f,bone,material)
def clasp(label,x,y,z,bone,direction):
    for k,(xx,zz,w,h) in enumerate(((-5,0,2.6,13),(5,0,2.6,13),(0,5,9,2.7),(0,-5,9,2.7),(0,-.2,6,2))):
        block(f"{label} clasp {k}",x+xx,y+direction*(.65 if k==4 else 0),z+zz,w,2.8,h,bone,"iron")
for sign,side in ((-1,"R"),(1,"L")):
    leg="Leg."+side
    arm="UpperArm."+side
    marks=((-1,0),(0,0),(1,0),(0,1),(1,-1)) if side=="R" else ((-1,0),(0,0),(1,0),(0,1),(-1,-1))
    for k,(x,z) in enumerate(marks):
        block(f"{side} trouser worn edge {k}",sign*42+x*8,-34.9,169+8*z-(3 if side=="L" else 0),8.04,1.6,8.04,leg,"skin")
    block(side+" pouch flap",sign*55,-56.0,250,29,5,16,"Hips","pouch")
    block(side+" pouch tab",sign*55,-60,240,5.5,5,14,"Hips","leather")
    block(side+" pouch rivet",sign*55,-63,243,4.5,2.5,4.5,"Hips","iron")
    clasp(side+" boot strap",sign*45,-37,57,leg,-1)
    block(side+" gaiter buckle",sign*59,-39,85,12,4,17,leg,"iron")
    for i in range(2):
        block(f"{side} finger tab {i}",sign*(99+i*8),-28.2,194+(2 if i else 0),6.1,2,9,arm,"skin")
clasp("Back center",0,73,245,"Hips",1)
block("Back center pouch flap",0,70,254,42,5,18,"Hips","pouch")
block("Back side pouch flap",44,62,250,25,4,11,"Hips","pouch")
block("Back side pouch rivet",44,65,248,4,2.8,5,"Hips","iron")
for i in range(8):
    t=(i+.5)/8
    x=-37+72*t
    z=264+88*t
    o=block("Cross strap stitching %02d"%i,x,-53.8,z,11,4,8,"Chest","pouch" if i%3 else "leather")
    angle=Matrix.Rotation(.69,3,"Y")
    pivot=Vector((x,-53.8,z))*S
    for v in o.data.vertices:
        v.co=pivot+angle@(v.co-pivot)
if PASS>=2:
    # The referent hood is olive at the temple, with the golden facing
    # tracing the face opening farther down and rounding into the dark return.
    panel=scene.objects[P+"Rear folded hood panel"]
    for v in panel.data.vertices:
        x,y,z=v.co/S
        if z>466:
            v.co.y-=S*11*(z-466)/47
            v.co.z-=S*5.5*(z-466)/47
    for n in ("R","L"):
        trouser=scene.objects[P+n+" trouser"]
        for v in trouser.data.vertices:
            if v.co.z/S <130:
                v.co.z-=S*2
    # Remove pure-white fill from shadowed broad cloth and give warm rims the emphasis.
    for o in scene.objects:
        if o.type=="LIGHT" and "Front fill" in o.name:
            o.data.energy*=.89
        if o.type=="LIGHT" and "Hair rim" in o.name:
            o.data.energy*=.91
    for o in [scene.objects[P+"Brow R"],scene.objects[P+"Brow L"]]:
        for v in o.data.vertices:
            v.co.z+=S*1.5
if PASS>=3:
    fit_cape.add(rig,scene,S)
    # Wrong-color tips came from the outer locks projecting through the side gusset.
    for o in list(scene.objects):
        if any(word in o.name for word in ("upper swept lock","middle swept lock","under swept lock")):
            for v in o.data.vertices:
                x,y,z=v.co/S
                v.co.x*=.92 if z>418 else .99
                if z>415:
                    v.co.y-=S*7.0
    names=("hood","outer")
    for name in names:
        material=bpy.data.materials[source_materials[name]]
        nodes=material.node_tree.nodes
        texture=next(n for n in nodes if n.type=="TEX_IMAGE")
        node=nodes.new("ShaderNodeMixRGB")
        node.blend_type="MULTIPLY"
        node.inputs[0].default_value=1
        node.inputs[2].default_value=(.81,.855,.82,1) if name=="hood" else (.94,.94,.88,1)
        material.node_tree.links.new(texture.outputs["Color"],node.inputs[1])
        material.node_tree.links.new(node.outputs[0],nodes.get("Principled BSDF").inputs["Base Color"])
    scene.objects[P+"Scarf wrap 1"].data.materials[0]=bpy.data.materials.get("MAT-Scout Tailoring nearest", textured)
table={m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views=("front","hero","right","back","left")
render(scene,[(table[v][0],v,table[v][1]) for v in views],OUT)
scene.name="Scout · Pixel tailoring PoC"
scene["Source"]="Canonical Scout trial with rigid copied Showcase bones and pixel tailoring"
scene["Reproduction"]="Mechanical rig candidate for the isolated workflow trial."
scene.render.filepath="//scout-review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"Scout pixel tailoring.blend"),compress=True)



