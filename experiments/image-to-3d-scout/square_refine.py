"""Three reviewable refinements to the isolated, rigged Scout copy."""
from pathlib import Path
import math
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from blender_review import render

OUT = Path(sys.argv[-2]).resolve()
PASS = int(sys.argv[-1])
SCALE = 1.8 / 518
PREFIX = "Scout Canon | "
NAMESPACE = "Scout Square | "
scene = bpy.context.scene
scene.frame_set(1)
rig = scene.objects[PREFIX + "Rig"]
character = scene.collection.children[PREFIX + "Character"]
collection = bpy.data.collections.get(NAMESPACE + "Fitted details")
if collection is None:
    collection = bpy.data.collections.new(NAMESPACE + "Fitted details")
    character.children.link(collection)

PALETTES = {
    "ochre": ["926330", "ab783a", "c2924e", "d1a15c", "a16d38"],
    "binding": ["6e532e", "82683a", "957745", "a48b51", "634d31"],
    "olive": ["383a28", "45452f", "585437", "666041", "383327"],
    "scarf": ["353825", "40432d", "4b4b30", "57543a", "333226"],
    "hair": ["322223", "3c2726", "492e2a", "563731", "59342d"],
    "hairline": ["3e2829", "4c2f30", "653d39", "73433d", "3c2629"],
    "skin": ["c58463", "e29f75", "efad85", "f4b78e", "cb8967"],
    "mark": ["b98059", "d09364", "e1a272", "e9ae7d", "c58962"],
    "leather": ["4d2d23", "60392a", "774b33", "8e5b3b", "5a3628"],
    "edge": ["36241e", "4a2b24", "5c382a", "6b4330", "402821"],
    "metal": ["62504a", "9b8173", "bfa395", "d3b8a7", "8b7165"],
    "wrap": ["967360", "b99886", "d7b6a1", "e0c1ac", "ad8875"],
    "coal": ["2c2428", "3b2e30", "493638", "503f3e", "35272b"],
    "shade": ["2e2b20", "363124", "40392b", "49402e", "302a20"],
    "eye": ["241a19", "2a1d1c", "31201f", "3c2725", "251c1b"],
    "white": ["b58b7c", "d5b3a2", "eed5bf", "f3dec8", "c7a390"],
}
TILES = (
    ("11122221","11223221","01122210","11122110","11001221","11212211","12211200","11111000"),
    ("11122110","12222100","12112111","11122111","01112211","01112100","11122001","11001100"),
    ("11221101","11221111","11122110","11122210","00112211","11111111","00221100","00111000"),
)

def paint_material():
    name = NAMESPACE + "64 by 64 materials"
    result = bpy.data.materials.get(name)
    if result:
        return result
    image = bpy.data.images.new(NAMESPACE + "Tailored atlas", width=64, height=64)
    pixels = [1.0] * (64 * 64 * 4)
    for index, (name, colors) in enumerate(PALETTES.items()):
        colors = [[int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)] for c in colors]
        design = TILES[index % len(TILES)]
        for y in range(16):
            for x in range(16):
                px = (index % 4) * 16 + x
                py = (index // 4) * 16 + y
                address = (py * 64 + px) * 4
                pixels[address:address + 3] = colors[int(design[y // 2][x // 2])]
    image.pixels.foreach_set(pixels)
    image.pack()
    result = bpy.data.materials.new(NAMESPACE + "64 by 64 materials")
    result.use_nodes = True
    nodes = result.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    principled.inputs["Roughness"].default_value = .87
    principled.inputs["Specular IOR Level"].default_value = .21
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    tex.extension = "EXTEND"
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = "Scout Square UV"
    result.node_tree.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    result.node_tree.links.new(tex.outputs["Color"], principled.inputs["Base Color"])
    return result

MATERIAL = paint_material()

def ob(name):
    return scene.objects[PREFIX + name]

def paint(obj, color):
    mesh = obj.data
    obj.data.materials.clear()
    obj.data.materials.append(MATERIAL)
    uv = mesh.uv_layers.get("Scout Square UV") or mesh.uv_layers.new(name="Scout Square UV")
    index = list(PALETTES).index(color)
    for face in mesh.polygons:
        face.material_index = 0
        dominant = max(range(3), key=lambda i: abs(face.normal[i]))
        axis_a, axis_b = ((1, 2), (0, 2), (0, 1))[dominant]
        center = face.center / SCALE
        for loop in face.loop_indices:
            point = mesh.vertices[mesh.loops[loop].vertex_index].co / SCALE
            u = max(1.0, min(15.0, 4 + (center[axis_a] * .077 % 8) + (point[axis_a] - center[axis_a]) / 7.8))
            v = max(1.0, min(15.0, 4 + (center[axis_b] * .064 % 8) + (point[axis_b] - center[axis_b]) / 7.8))
            uv.data[loop].uv = ((index % 4 * 16 + u) / 64, (index // 4 * 16 + v) / 64)

def nudge(obj, transform):
    mesh = obj.data
    target = mesh.shape_keys.key_blocks if mesh.shape_keys else (mesh,)
    for block in target:
        points = block.data if mesh.shape_keys else block.vertices
        for point in points:
            point.co = Vector(transform(*(point.co / SCALE))) * SCALE
    mesh.update()

def bind_mesh(name, vertices, faces, bone, color):
    object_name = NAMESPACE + name
    assert object_name not in bpy.data.objects, object_name
    mesh = bpy.data.meshes.new(object_name)
    mesh.from_pydata([tuple(c * SCALE for c in p) for p in vertices], [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(object_name, mesh)
    collection.objects.link(obj)
    joint = rig.data.bones[bone]
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_parent_inverse = (joint.matrix_local @ Matrix.Translation((0, joint.length, 0))).inverted()
    paint(obj, color)
    return obj

def slab(name, outline, depth, bone, color):
    count = len(outline)
    vertices = list(outline) + [(x, y + depth, z) for x, y, z in outline]
    faces = [tuple(reversed(range(count))), tuple(range(count, 2 * count))]
    faces.extend((i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count))
    return bind_mesh(name, vertices, faces, bone, color)

def box(name, center, size, bone, color, tilt=(0, 0, 0)):
    a, b, c = [v * .5 for v in size]
    rotate = Euler(tuple(math.radians(v) for v in tilt)).to_matrix()
    vertices = [Vector(center) + rotate @ Vector(p) for p in
                ((-a, -b, -c), (a, -b, -c), (a, b, -c), (-a, b, -c),
                 (-a, -b, c), (a, -b, c), (a, b, c), (-a, b, c))]
    return bind_mesh(name, vertices, [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
                                     (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], bone, color)

def select_hidden(obj):
    obj.hide_render = True
    obj.hide_set(True)

def edit_head():
    hood = next(o for o in scene.objects if o.name.endswith("hood with returned lining"))
    # In the exterior rings the upper edges are short chamfers while the crown
    # stays flat. The interior rings and existing UVs retain their original fit.
    for vert in hood.data.vertices:
        ring, column = divmod(vert.index, 44)
        neighbor = min(column, 44 - column)
        if ring > 4 or neighbor > 11:
            continue
        x, y, z = vert.co / SCALE
        if neighbor <= 6:
            z += (1.1 if ring != 0 else 3.5)
            if neighbor == 6:
                x *= 1.035
        elif neighbor == 7:
            x *= 1.025
            z += 3.8
        elif neighbor == 8:
            x *= 1.026
            z += 2.1
        elif neighbor <= 10:
            x *= 1.012
        vert.co = Vector((x, y, z)) * SCALE
    hood.data.update()
    nudge(ob("Rear folded hood panel"), lambda x,y,z:(x,y-2.0*max(0,(z-390)/116),z+2.4*max(0,(z-440)/68)))
    hood_material = hood.data.materials[0]
    tone = next(n for n in hood_material.node_tree.nodes if n.type == "MIX_RGB")
    tone.inputs[2].default_value = (.67, .72, .59, 1)
    for name in ("Forelock","Brow R","Brow L","Eye R","Eye L","Iris R","Iris L","Mouth guide"):
        select_hidden(ob(name))
    # Four overlapping, individually cut locks, visible inside the lined hood.
    for i, (outline, y) in enumerate((
        ([(-47,469),(-31,470),(-31,455),(-35,455),(-35,438),(-47,438)],-56.3),
        ([(-35,470),(-11,472),(-11,458),(-16,458),(-16,444),(-21,444),(-21,435),(-38,439)],-59.0),
        ([(-15,470),(12,472),(12,461),(6,461),(6,446),(1,446),(1,440),(-17,443)],-58.6),
        ([(12,471),(46,470),(46,438),(31,439),(31,449),(23,449),(23,461),(12,461)],-56.5),
    )):
        slab(f"Forelock {i+1}",[(x,y+.06*x,z) for x,z in outline],8.0,"Head","hair")
    # Simple Minecraft expression. Warm sclera sits on the outside of each eye.
    for sign, side in ((-1,"R"),(1,"L")):
        box(side+" eye white", (sign*27,-51.4,413), (23,1.5,24), "Head","white")
        box(side+" eye pupil", (sign*20.2,-52.3,414), (12.8,1.0,24), "Head","eye")
        slab(side+" pixel brow", [(sign*x,-55.1,z) for x,z in
             [(9,427),(9,433),(23,435),(35,438),(45,436),(45,431),(32,433),(21,430)]],3.2,"Head","hair")
    box("Mouth pixel",(.2,-51.8,398.6),(5.4,1.6,2.4),"Head","hairline")
    # Raise selected gold cloth cells along the upper opening. Place their
    # surface on the actual hood so the steps follow its side silhouettes.
    def gold_patch(label,corners, palette="ochre"):
        nodes=[]
        for x,z in corners:
            hit, location, _, _ = hood.ray_cast(Vector((x*SCALE,-1,z*SCALE)),Vector((0,1,0)))
            if not hit:
                return
            nodes.append((x,location.y/SCALE-1.0,z))
        slab(label,nodes,4.2,"Head",palette)
    for sign,side in ((-1,"R"),(1,"L")):
        for index,(a,b,z0,z1) in enumerate(((0,9,467,493),(9,21,466,484),(21,40,465,479),
             (40,51,460,476),(50,59,449,472),(54,64,437,457),(62,68,425,443),
             (67,74,411,432),(72,80,398,420),(77,84,389,406))):
            gold_patch(f"{side} hood bound step {index+1}",[(sign*a,z0),(sign*b,z0),(sign*b,z1),(sign*a,z1)],
                       "ochre" if index<6 else "binding")
    scarf=ob("Scarf wrap 1")
    def scarf_fold(x,y,z):
        if y<-58:
            z -= max(0,1-abs(x)/60)*2.2 + x*.045
            y -= 2
        return x,y,z
    nudge(scarf,scarf_fold)
    # Let the stepped streams read in profile and hero without thickening all the back hair.
    for side in ("R","L"):
        for name in ("middle swept lock","under swept lock","nape side fall"):
            lock=ob(side+" "+name)
            nudge(lock,lambda x,y,z:(x+(1 if x>0 else -1)*1.8,y+5.5*max(0,(y-48)/43),z))

def edit_outfit():
    def stitched_panel(name, sx):
        # The coat opening binds around the edge of the light shirt.
        for j,(low,high,x,y,w) in enumerate(((322,345,26.4,-46,6.5),
                                           (303,323,27.4,-46.5,6.4),
                                           (282,305,28.8,-47,6.4),
                                           (260,284,30.3,-47.6,6.5),
                                           (241,261,31.8,-47.1,6.4),
                                           (218,240,33.1,-46,6.2))):
            box(f"{name} placket binding {j}",(sx*x,y,(low+high)/2),(w,2.8,high-low),
                "Chest","binding" if j%3 else "ochre",(0,sx*4.2,0))
        for j,(x,y,z) in enumerate(((29.9,-49.0,324.5),(30.8,-49.4,300),(31.5,-49.8,273.5),
                                    (33.5,-49.0,251.5))):
            box(f"{name} bound seam stitch {j}",(sx*x,y,z),(3.8,1.7,4.9),"Chest","olive")
    def trim_sleeve(side, sign):
        sleeve=ob(side+" short sleeve")
        # Increase the planar cloth face at the lower corners without changing
        # the shoulder joint or the distance to the forearm.
        for v in sleeve.data.vertices:
            x,y,z=v.co/SCALE
            vi=v.index%8
            if 0<=v.index//8<4:
                if vi in (0,1,4,5):
                    x+= (1.8 if vi in (1,4) else -1.8) * (1 if sign<0 else 1)
                else:
                    y+=math.copysign(2.3,y)
            v.co=Vector((x,y,z))*SCALE
        sleeve.data.update()
        # The main patch sits on the outward plane and follows the sleeve.
        def badge(label, y0, y1, z0, z1, color):
            vertices=[]
            for y,z in ((y0,z0),(y1,z0),(y1,z1),(y0,z1)):
                hit,q,_,_=sleeve.ray_cast(Vector((sign*1.0,y*SCALE,z*SCALE)),Vector((-sign,0,0)))
                if not hit:
                    return
                vertices.append((q.x/SCALE+sign*.85,y,z))
            copy=[(x-sign*3.6,y,z) for x,y,z in vertices]
            bind_mesh(label,vertices+copy,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],
                      "UpperArm."+side,color)
        for j,(a,b,c,d) in enumerate(((-12.5,12.5,318.0,326.4),(-4.8,4.0,309.2,318.0),(-4.8,4.0,326.4,335.3))):
            badge(side+f" sleeve cross {j}",a,b,c,d,"mark")
        badge(side+" cuff edge tape",-22,22,285,290,"binding")
        for j,y in enumerate((-16,-7,8,17)):
            badge(side+f" cuff stitch {j}",y,y+2.1,289,292,"edge")
        # A narrow seam on the camera-facing cuff, matched to the actor's arm lean.
        for j,(x,z) in enumerate(((65,294),(76,291),(87,288),(98,286))):
            hit,q,_,_=sleeve.ray_cast(Vector((sign*x*SCALE,-1,z*SCALE)),Vector((0,1,0)))
            if hit:
                box(side+f" front cuff piping {j}",(sign*x,q.y/SCALE-.3,z),(10.6,2.0,4.0),
                    "UpperArm."+side,"binding",(0,sign*10,0))
    for sign,side in ((-1,"R"),(1,"L")):
        stitched_panel(side,sign)
        trim_sleeve(side,sign)
        hip=ob(side+" hip pouch")
        paint(hip,"leather")
        for n in ("pouch flap","pouch tab","pouch rivet"):
            select_hidden(scene.objects["GEO-"+side+" "+n])
        x=sign*55
        box(side+" squared pocket lid",(x,-58.3,253.5),(31.5,6.8,15.4),"Hips","leather")
        box(side+" pocket lip",(x,-62.0,247.3),(30.4,2.2,3.2),"Hips","edge")
        box(side+" pocket latch leather",(x,-62.5,242.5),(8.2,4.6,15.5),"Hips","edge")
        box(side+" pocket latch plate",(x,-65.5,241.6),(6.4,3.8,8.9),"Hips","metal")
        box(side+" pocket latch pin",(x,-68,244.3),(3.1,2.1,3.5),"Hips","metal")
        box(side+" keeper loop",(sign*70,-47.3,249),(5.8,8.0,22),"Hips","leather")
        for idx,(dx,z) in enumerate(((-11,218),(11,218),(-11,225),(11,225))):
            box(side+f" pocket leather stitch {idx}",(x+dx,-57.0,z),(1.6,1.4,3.0),"Hips","binding")
    for name in ("Buckle frame mass","Buckle recess"):
        select_hidden(ob(name))
    # Model all four members of the buckle separately to retain the dark opening.
    box("Waist buckle leather backing",(0,-53,247.5),(34,11,31),"Hips","edge")
    for label,(x,z,w,h) in {
        "top":(0,260.1,31,4.6),"bottom":(0,235.1,31,4.6),
        "near":(-13.2,247.5,4.6,22),"far":(13.2,247.5,4.6,22),
    }.items():
        box("Waist square buckle "+label,(x,-58.5,z),(w,5.6,h),"Hips","metal")
    box("Waist buckle tongue",(-4.9,-60.3,247),(12,4.0,3.1),"Hips","metal")
    box("Waist buckle return",(5.8,-57.7,246.8),(6.8,3.2,3.1),"Hips","edge")
    # The brown transverse strap uses offset stitching and a keeper rather
    # than bright raised ridges across the full chest.
    for i in range(8):
        trim=scene.objects[f"GEO-Cross strap stitching {i:02}"]
        midpoint=sum((v.co for v in trim.data.vertices),Vector())/8
        for v in trim.data.vertices:
            v.co.y=midpoint.y+(v.co.y-midpoint.y)*.69 + .6*SCALE
        paint(trim,"edge" if i%4==1 else "leather")
    box("Cross strap keeper",(-20,-57,287),(15,4,9),"Chest","edge",(0,38,0))
    box("Cross strap keeper metal glint",(-23,-59.2,286),(4.5,2.6,3.1),"Chest","metal",(0,38,0))
    # Reposition the rear hardware above the sculpted cloth.
    for suffix in ("pouch","side pouch"):
        paint(ob("Back "+suffix),"leather")
    for k in range(5):
        select_hidden(scene.objects[f"GEO-Back center clasp {k}"])
    for label, center,size in (("upper",(0,74.2,251),(13,3.5,3.0)),
                              ("lower",(0,74.2,239),(13,3.5,3.0)),
                              ("right",(5.4,74.2,245),(2.6,3.5,11)),
                              ("left",(-5.4,74.2,245),(2.6,3.5,11)),
                              ("pin",(-1.1,75.8,245),(6.9,2.4,2.1))):
        box("Back clasp "+label,center,size,"Hips","metal")
    # End of the scarf trails over the upper chest and breaks the uniform band.
    for i,(x,y,z) in enumerate(((36,-49,338),(40,-48,326))):
        box(f"Scarf end {i}",(x,y,z),(15-i*3,6.6,26-i*4),"Neck","scarf",(3,-13,3))

def edit_finish():
    def sharpen_layers(obj, strength, count=4):
        # Tight edge breaks keep the broad front/side planes square.
        verts=obj.data.vertices
        assert len(verts)%8==0
        for low in range(0,min(len(verts),count*8),8):
            ring=[v.co.copy() for v in verts[low:low+8]]
            x0,x1=min(p.x for p in ring),max(p.x for p in ring)
            y0,y1=min(p.y for p in ring),max(p.y for p in ring)
            for i,v in enumerate(verts[low:low+8]):
                p=ring[i]
                if i in (0,5):
                    p.x+=(x0-p.x)*strength
                if i in (1,4):
                    p.x+=(x1-p.x)*strength
                if i in (2,7):
                    p.y+=(y0-p.y)*strength
                if i in (3,6):
                    p.y+=(y1-p.y)*strength
                v.co=p
        obj.data.update()

    for sign,side in ((-1,"R"),(1,"L")):
        leg="Leg."+side
        arm="UpperArm."+side
        # Taller square soles with a thin toe seam and a planar top vamp.
        for name,mat in (("outsole","edge"),("toe","leather"),("boot shaft","leather"),
                         ("boot collar","edge"),("instep strap mass","edge")):
            boot=ob(side+" "+name)
            sharpen_layers(boot,.69,4 if name!="toe" else 3)
            paint(boot,mat)
        x=sign*47.1
        box(side+" sole stitched welt",(x,-58.8,19.4),(61.2,2.9,3.2),leg,"edge")
        box(side+" toe polished lip",(x,-56.8,29.5),(59.3,3.1,5.1),leg,"leather")
        box(side+" toe front step",(x,-52.6,36.4),(55.4,10.1,6.0),leg,"leather")
        box(side+" ankle front strap",(x,-35.0,58.5),(38.4,7.1,15.5),leg,"edge")
        for j in range(5):
            select_hidden(scene.objects[f"GEO-{side} boot strap clasp {j}"])
        for j,(dx,z,w,h) in enumerate(((-13.1,59,5.5,12.3),(13.1,59,5.5,12.3),
                                      (0,63.2,21.5,3.1),(0,54.8,21.5,3.1),(0,59.2,14.0,2.9))):
            box(side+f" broad instep buckle {j}",(x+dx,-39.4,z),(w,3.2,h),leg,"metal" if j<2 else "edge")
        select_hidden(scene.objects["GEO-"+side+" gaiter buckle"])
        face_x=sign*74.5
        box(side+" outer ankle metal plate",(face_x,-21.0,84.7),(6.4,16.1,16.3),leg,"metal")
        box(side+" outer ankle fastening",(face_x+sign*1.1,-15.8,84.8),(5.4,4.6,12),leg,"edge")
        box(side+" lower ankle side plate",(face_x-sign*2.1,-6.5,58.0),(4.9,14.2,12.6),leg,"metal")
        # The knee-wear pattern is deliberately asymmetric like the front concept.
        for j in range(5):
            select_hidden(scene.objects[f"GEO-{side} trouser worn edge {j}"])
        if side=="R":
            patches=[(-43,171,38,13),(-43,183,11,11),(-35,160,12,12)]
        else:
            patches=[(41,164,29,12),(42,175,11,10),(34,158,10,9)]
        for j,(x,z,w,h) in enumerate(patches):
            box(side+f" trouser opening {j}",(x,-35.1,z),(w,1.55,h),leg,"skin")
        box(side+" upper glove leather join",(sign*98,-28.0,224.0),(37,3.2,10.4),
            arm,"coal",(0,sign*10,0))
        box(side+" glove shaded knuckle",(sign*99.2,-28.8,207.0),(25,1.9,11.2),
            arm,"edge",(0,sign*10,0))
        for j in range(2):
            select_hidden(scene.objects[f"GEO-{side} finger tab {j}"])
        for j,(x,z) in enumerate(((91,192),(101,194),(110,196))):
            box(side+f" exposed squared finger {j}",(sign*x,-28.8,z),(6.0,2.1,10.0),
                arm,"skin",(0,sign*9,0))

    # Short square locks enter under the brim then fan into visible layers.
    for sign,side in ((-1,"R"),(1,"L")):
        for i,(outline,anchor) in enumerate((
            ([(60,496),(75,491),(75,485),(87,485),(87,474),(98,474),(101,465),
               (87,463),(79,470),(67,475),(61,485)],59),
            ([(76,461),(89,455),(89,449),(102,449),(102,443),(111,443),
               (116,431),(102,430),(92,435),(82,439),(78,448)],67),
            ([(78,425),(92,418),(92,413),(105,413),(109,401),(105,394),
               (103,385),(92,387),(86,392),(83,407)],64),
            ([(71,391),(88,386),(88,378),(101,374),(101,363),(95,355),
               (95,345),(86,344),(82,352),(79,368)],53),
        )):
            vertices=[(sign*(anchor+.14*(z-410)),y,z) for y,z in outline]
            count=len(vertices)
            inner=[(x-sign*(10 if i in (0,1) else 14),y-3,z) for x,y,z in vertices]
            faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]
            faces.extend((j,(j+1)%count,(j+1)%count+count,j+count) for j in range(count))
            bind_mesh(side+f" stepped nape wisp {i+1}",vertices+inner,faces,"Head","hairline" if i in (0,2) else "hair")
    rear=ob("Rear folded hood panel")
    paint(rear,"olive")
    layer=rear.data.uv_layers.get("Scout Square UV")
    idx=list(PALETTES).index("olive")
    # One continuous checker phase across the large rear cloth plane.
    for loop in rear.data.loops:
        p=rear.data.vertices[loop.vertex_index].co/SCALE
        layer.data[loop.index].uv=((idx%4*16 + 8 + p.x/12)/64,
                                  (idx//4*16+1.8+(p.z-378)/9.8)/64)
    for k in (1,3,4,5,6,7):
        paint(ob(f"Nape lock {k:02}"),"hairline")
    # The gold pixels at the hem follow the same deforming cloth geometry.
    cloak=ob("Long cloak with tapered supporting folds")
    mesh=cloak.data
    index=next((i for i,m in enumerate(mesh.materials) if m==MATERIAL),-1)
    if index<0:
        mesh.materials.append(MATERIAL)
        index=len(mesh.materials)-1
    uv=mesh.uv_layers.new(name="Scout Square UV")
    binding=list(PALETTES).index("binding")
    shade=list(PALETTES).index("shade")
    for face in mesh.polygons:
        center=face.center/SCALE
        if face.normal.y < .18 or center.z>=231:
            continue
        col=math.floor((center.x+81)/13)
        picks=(1,3,5,7,9,11)
        if col in picks and (center.z<205 or col in (3,9)):
            key=binding
        elif col in (2,4,8,10):
            key=shade
        else:
            continue
        face.material_index=index
        for l in face.loop_indices:
            p=mesh.vertices[mesh.loops[l].vertex_index].co/SCALE
            u=max(1.1,min(14.8,8+(p.x-center.x)/3.4))
            v=max(1.1,min(14.8,8+(p.z-center.z)/9.5))
            uv.data[l].uv=((key%4*16+u)/64,(key//4*16+v)/64)
    nudge(cloak,lambda x,y,z:(x, y+3.8*max(0,min(1,(266-z)/110)),z))
    nudge(scene.objects[NAMESPACE+"Mouth pixel"],lambda x,y,z:(x,y+.24,z))

def edit_polish():
    # The copied silhouette stays intact. Settle raised trim onto each surface.
    for side,sign in (("R",-1),("L",1)):
        for j in range(1,5):
            wisp=scene.objects[NAMESPACE+f"{side} stepped nape wisp {j}"]
            nudge(wisp,lambda x,y,z:(
                x-sign*(4.1 if j<3 else 1.6),
                y-3.5*max(0,(y-73)/38),
                z+(2.2 if j==3 else 0.0)))
            count=len(wisp.data.vertices)//2
            for v in wisp.data.vertices[count:]:
                v.co.x-=sign*7*SCALE
                v.co.y-=6.3*SCALE
            paint(wisp,"hairline" if j>=3 else "hair")
        for j in range(1,6):
            to=scene.objects.get(NAMESPACE+f"{side} hood bound step {j}")
            if to:
                # The top gold textile is nearly flush with the shell.
                nudge(to,lambda x,y,z:(x,y+.65,z))
        glove=scene.objects[NAMESPACE+side+" glove shaded knuckle"]
        nudge(glove,lambda x,y,z:(x,y+.95,z+2.3))
        glove=scene.objects[NAMESPACE+side+" upper glove leather join"]
        nudge(glove,lambda x,y,z:(x,y-.85,z))
        # Stretch the small chips of torn skin color slightly into one another.
        for j in (1,2):
            tear=scene.objects[NAMESPACE+f"{side} trouser opening {j}"]
            nudge(tear,lambda x,y,z:(x,y-.2,z+(0 if j==1 else 1.6)))
        step=scene.objects[NAMESPACE+side+" toe front step"]
        nudge(step,lambda x,y,z:(x,y+.5,z-1.9))
        ob(side+" short sleeve").data.update()
    rear=ob("Rear folded hood panel")
    rear_uv=rear.data.uv_layers.get("Scout Square UV")
    cell=list(PALETTES).index("olive")
    for loop in rear.data.loops:
        p=rear.data.vertices[loop.vertex_index].co/SCALE
        rear_uv.data[loop.index].uv=((cell%4*16+8+p.x/11.4)/64,
                                    (cell//4*16+1.3+(p.z-378)/9.5)/64)
    mask=ob("Scarf overlap")
    nudge(mask,lambda x,y,z:(x,y+max(0,1-abs(x)/56)*1.4,z+max(0,1-abs(x)/56)*2.2))
    paint(mask,"scarf")
    cloak=ob("Long cloak with tapered supporting folds")
    keys=cloak.data.shape_keys.key_blocks
    # Keep more of the default weave across the upper back, with short ochre
    # ends only along the lower hem. The UV islands travel with the garment.
    for face in cloak.data.polygons:
        p=face.center/SCALE
        if face.material_index==1 and p.z>170:
            face.material_index=0
    for d in cloak.data.shape_keys.animation_data.drivers:
        if "Rear clearance" in d.data_path:
            d.driver.expression="0 if frame == 2 else max(0, min(1, (-swing + 0.12) / 0.65))"
    for side,sign in (("R",-1),("L",1)):
        key=keys["Rear clearance "+side]
        base=keys[0]
        for new,old in zip(key.data,base.data):
            x,y,z=old.co/SCALE
            gate=max(0,min(1,(230-z)/120))
            lateral=max(0,min(1,.34+sign*x/55))
            new.co.y+=.045*gate*lateral
    # Let the rear edge keep the dark olive of the concept rather than
    # picking up the same broad gold plane as the face opening trim.
    hood=next(o for o in scene.objects if o.name.endswith("hood with returned lining"))
    tone=next(n for n in hood.data.materials[0].node_tree.nodes if n.type=="MIX_RGB")
    tone.inputs[2].default_value=(.61,.677,.566,1)

def edit_seams():
    rear=ob("Rear folded hood panel")
    # Hair can break the side silhouette, but every lock above the hem
    # must sit under the folded rear panel when viewed from behind.
    for side,sign in (("R",-1),("L",1)):
        for j in (1,2):
            part=scene.objects[NAMESPACE+f"{side} stepped nape wisp {j}"]
            for v in part.data.vertices:
                x,y,z=v.co/SCALE
                dx=3.0 if j==1 and z>475 else 1.3
                x=x-sign*dx
                ray=Vector((x*SCALE,1,z*SCALE))
                found,point,_,_=rear.ray_cast(ray,Vector((0,-1,0)))
                if found:
                    surface=point.y/SCALE
                    # At the corners the outermost face can peek out on profile.
                    # Leave it tangent to the cap and tuck the inner side deeper.
                    ceiling=surface-1.8
                    if y>ceiling:
                        y=surface-1.8/(1+.062*(y-ceiling))
                else:
                    y-=9.1
                v.co=Vector((x,y,z))*SCALE
            part.data.update()
    # Seat the rear strap and pouch back onto the changed cloth fold.
    box("Rear belt visible return",(33.0,61.0,247.5),(31.0,9,12.7),"Hips","leather")
    for i,(x,z) in enumerate(((31.4,246.1),(42.5,246.1),(49,246.1))):
        box("Rear belt tack "+str(i),(x,65.6,z),(2.4,1.8,3.1),"Hips","edge")
    lip=scene.objects[NAMESPACE+"Rear belt visible return"]
    nudge(lip,lambda x,y,z:(x,y+(2.8 if x>40 else 0.0),z))
    # Falloff after the mask preserves the skirt silhouette in rest and hero.
    def lower_hem(x,y,z):
        blend=max(0,min(1,(192-z)/60))
        return x*(1-.025*blend),y-2*blend,z
    nudge(ob("Long cloak with tapered supporting folds"),lower_hem)

def edit_cloth():
    hood=next(o for o in scene.objects if o.name.endswith("hood with returned lining"))
    rear=ob("Rear folded hood panel")
    material=bpy.data.materials.new(NAMESPACE+"Painted hood weave")
    material.use_nodes=True
    nodes=material.node_tree.nodes
    bs=nodes.get("Principled BSDF")
    bs.inputs["Roughness"].default_value=.91
    bs.inputs["Specular IOR Level"].default_value=.19
    tex=nodes.new("ShaderNodeTexImage")
    tex.image=bpy.data.images.load(str(OUT.parent/"hood-cloth-64.png"),check_existing=False)
    tex.image.pack()
    tex.interpolation="Closest"
    uv=nodes.new("ShaderNodeUVMap")
    uv.uv_map="Scout Cloth UV"
    material.node_tree.links.new(uv.outputs["UV"],tex.inputs["Vector"])
    material.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
    for obj in (hood,rear,ob("Hood gusset R"),ob("Hood gusset L")):
        mesh=obj.data
        mesh.materials.append(material)
        slot=len(mesh.materials)-1
        layer=mesh.uv_layers.new(name="Scout Cloth UV")
        for face in mesh.polygons:
            if obj==hood and max(i//44 for i in face.vertices)>4:
                continue
            normal=face.normal
            face.material_index=slot
            if obj==rear:
                mapping="rear"
            elif normal.z>.48:
                mapping="top"
            elif abs(normal.x)>.44:
                mapping="side"
            elif normal.y>0:
                mapping="rear"
            else:
                mapping="front"
            for loop in face.loop_indices:
                x,y,z=mesh.vertices[mesh.loops[loop].vertex_index].co/SCALE
                if mapping=="side":
                    col,row,u,v=0,1,(y+63)/151,(z-357)/166
                elif mapping=="top":
                    col,row,u,v=1,1,(x+87)/175,(y+70)/155
                elif mapping=="front":
                    col,row,u,v=0,0,(x+90)/181,(z-367)/162
                else:
                    col,row,u,v=1,0,(x+86)/172,(z-370)/158
                clamp=lambda t:max(.003,min(.997,t))
                layer.data[loop].uv=((col+clamp(u))*.5,(row+clamp(v))*.5)

{1:edit_head,2:edit_outfit,3:edit_finish,4:edit_polish,5:edit_seams,6:edit_cloth}[PASS]()
scene.name = "Scout · Minecraft Refinement"
scene["Review pass"] = PASS
OUT.mkdir(parents=True,exist_ok=True)
sequence = {m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
views = ("front","hero","right","back","left")
render(scene,[(sequence[v][0], v, sequence[v][1]) for v in views],OUT)
scene.render.filepath = "//Scout review.png"
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"Scout.blend"),compress=True,relative_remap=False)

