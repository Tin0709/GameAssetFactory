"""Seat joined gold trim and compact the rear layers on the fitted Scout."""
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from blender_review import render

S = 1.8 / 518
P = "Scout Canon | "
B = "Scout Blocks | "
N = "Scout Square | "
scene = bpy.context.scene
scene.frame_set(1)
collection = bpy.data.collections.new("Scout · Joined textile blocks")
root = bpy.data.collections[P + "Character"]
root.children.link(collection)
rig = scene.objects[P + "Rig"]
mode = sys.argv[-2]
out = Path(sys.argv[-1]).resolve()

def hide(obj):
    obj.hide_render = True
    obj.hide_set(True)

def trim():
    for obj in scene.objects:
        if obj.name.startswith(B + "Hood · "):
            hide(obj)

    # This grid follows the edges of the sewn tiles in the front drawing.
    # Neighbors share edges, including where the crown turns onto the cheeks.
    bands = [(-47,47,471,485,0),(-14,4,485,500,0),(4,21,485,493,1)]
    for side in (-1,1):
        for x0,x1,z0,z1,tone in (
            (36,57,463,479,0),(48,63,449,463,0),(55,68,431,449,1),
            (62,76,415,431,1),(70,83,396,415,1),(74,84,389,396,1),
        ):
            xa,xb = sorted((side*x0,side*x1))
            bands.append((xa,xb,z0,z1,tone))

    xx = sorted(set(a for x0,x1,_,_,_ in bands for a in (x0,x1)))
    zz = sorted(set(a for _,_,z0,z1,_ in bands for a in (z0,z1)))
    tiles = {(i,j):tone for x0,x1,z0,z1,tone in bands
             for i in range(xx.index(x0), xx.index(x1)) for j in range(zz.index(z0), zz.index(z1))}

    def cloth_depth(x,z):
        # Above the opening the brow slopes into the crown. At the cheeks
        # the leather-colored cloth turns around the head.
        x = abs(x)
        crown = -77.9 + (z-472)*.62 + max(0,x-29)*.09
        cheek_x = 53.5 + max(0,(459-z))*.41
        cheek = -74.0 + max(0,(456-z))*.322 + (x-cheek_x)*.87
        blend = max(0,min(1,(472-z)/11))*max(0,min(1,(x-36)/12))
        return crown*(1-blend)+cheek*blend

    points,indices,faces,colors = [],{},{},{}
    def vertex(i,j,edge):
        key = (i,j,edge)
        if key not in indices:
            x,z = xx[i],zz[j]
            y = cloth_depth(x,z)+edge*8.8
            indices[key] = len(points)
            points.append((x*S,y*S,z*S))
        return indices[key]

    def face(corners, color):
        faces[len(faces)] = tuple(vertex(*p) for p in corners)
        colors[len(colors)] = color

    for (i,j), tone in sorted(tiles.items()):
        ring = [(i,j),(i+1,j),(i+1,j+1),(i,j+1)]
        face([(a,b,0) for a,b in ring],tone)
        face([(a,b,1) for a,b in reversed(ring)],1)
        for k,(di,dj) in enumerate(((0,-1),(1,0),(0,1),(-1,0))):
            if (i+di,j+dj) in tiles:
                continue
            a,b = ring[k], ring[(k+1)%4]
            face([(*b,0),(*a,0),(*a,1),(*b,1)],1)
    name = B + "Hood · Sewn stepped binding"
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points,[],list(faces.values()))
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    collection.objects.link(obj)
    joint = rig.data.bones["Head"]
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = joint.name
    obj.matrix_parent_inverse = (joint.matrix_local @ Matrix.Translation((0,joint.length,0))).inverted()
    # Slightly mute the trim so the brightest corner belongs to the key light.
    material = bpy.data.materials[N + "64 by 64 materials"].copy()
    material.name = "Scout Blocks | Ochre binding"
    nodes = material.node_tree.nodes
    img = next(n for n in nodes if n.type == "TEX_IMAGE")
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    dye = nodes.new("ShaderNodeMixRGB")
    dye.name = "Warm cloth dye"
    dye.blend_type = "MULTIPLY"
    dye.inputs[0].default_value = 1.0
    dye.inputs[2].default_value = (.78,.69,.56,1)
    material.node_tree.links.new(img.outputs["Color"],dye.inputs[1])
    material.node_tree.links.new(dye.outputs[0],bsdf.inputs["Base Color"])
    mesh.materials.append(material)
    uv = mesh.uv_layers.new(name="Scout Square UV")
    for poly in mesh.polygons:
        tone = colors[poly.index]
        for loop in poly.loop_indices:
            x,y,z = Vector(points[mesh.loops[loop].vertex_index])/S
            u = 2.0+(x+84)*.061
            v = 2.0+(z-389)*.086
            uv.data[loop].uv = ((tone*16+u)/64,v/64)

def nape():
    # Retain the side lobes behind the cap, with their free ends tucked in
    # toward the large center tiers. This reduces fins seen from the back.
    names = ("middle swept lock","under swept lock","nape side fall")
    for sign,side in ((-1,"R"),(1,"L")):
        for name in [P+side+" "+s for s in names]+[N+f"{side} stepped nape wisp {i}" for i in (3,4)]:
            obj = scene.objects[name]
            keys = obj.data.shape_keys
            versions = [(k.name,k.data) for k in keys.key_blocks] if keys else [("",obj.data.vertices)]
            for label,version in versions:
                for v in version:
                    x,y,z = v.co/S
                    pull = max(0,min(1,(y-63)/27))*max(0,min(1,(455-z)/33))
                    if label == "3/4 loose locks":
                        pull *= .52
                    v.co.x -= sign*9.0*pull*S
                    v.co.y -= 4.0*pull*S
            obj.data.update()

trim()
if mode == "compact":
    nape()
scene["Source-fit pass"] = "Fitted rectangular details · joined binding and compact nape"
markers = {m.name.casefold():m for m in scene.timeline_markers if m.camera}
render(scene,[(markers[v].frame,v,markers[v].camera) for v in ("front","hero","right","back","left")],out)
scene.render.filepath = "//Scout review.png"
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)

