"""Refit selected Scout details as assemblies of rectangular cloth and hair pieces."""
from pathlib import Path
import sys
from itertools import product

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_review import render

S = 1.8 / 518
P = "Scout Canon | "
N = "Scout Square | "
scene = bpy.context.scene
scene.frame_set(1)
rig = scene.objects[P + "Rig"]
root = bpy.data.collections[P + "Character"]
atlas = bpy.data.materials[N + "64 by 64 materials"]

stage, folder = sys.argv[-2:]
out = Path(folder).resolve()
collection = bpy.data.collections.new(f"Scout · Block fit · {stage}")
root.children.link(collection)

def replace(obj):
    obj.hide_render = True
    obj.hide_set(True)

def mesh_object(label, points, faces, bone, cell, uv_shift=0):
    name = "Scout Blocks | " + label
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([Vector(p) * S for p in points], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    joint = rig.data.bones[bone]
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_parent_inverse = (joint.matrix_local @ Matrix.Translation((0, joint.length, 0))).inverted()
    mesh.materials.append(atlas)
    uv = mesh.uv_layers.new(name="Scout Square UV")
    lo = [min(p[i] for p in points) for i in range(3)]
    spans = [max(p[i] for p in points) - lo[i] for i in range(3)]
    for face in mesh.polygons:
        normal_axis = max(range(3), key=lambda i: abs(face.normal[i]))
        u_axis, v_axis = ((1, 2), (0, 2), (0, 1))[normal_axis]
        for loop in face.loop_indices:
            p = points[mesh.loops[loop].vertex_index]
            u = min(14.8, 1.35 + uv_shift + (p[u_axis] - lo[u_axis]) / max(3.0, spans[u_axis] / 10.8))
            v = min(14.8, 1.35 + (p[v_axis] - lo[v_axis]) / max(4.3, spans[v_axis] / 13.2))
            uv.data[loop].uv = ((cell % 4 * 16 + u) / 64, (cell // 4 * 16 + v) / 64)
    return obj

def cuboid_union(boxes):
    """Emit only exterior quads on the shared coordinate grid of the boxes."""
    coords = [sorted(set(b[axis][i] for b in boxes for i in (0, 1))) for axis in range(3)]
    cells = set()
    for box in boxes:
        spans = [range(coords[a].index(lo), coords[a].index(hi)) for a, (lo, hi) in enumerate(box)]
        cells.update(product(*spans))
    points, indices, faces = [], {}, []
    for cell in sorted(cells):
        for axis, sign in product(range(3), (-1, 1)):
            neighbor = list(cell)
            neighbor[axis] += sign
            if tuple(neighbor) in cells:
                continue
            u, v = (axis + 1) % 3, (axis + 2) % 3
            corners = ((0, 0), (1, 0), (1, 1), (0, 1))
            if sign < 0:
                corners = tuple(reversed(corners))
            poly = []
            for du, dv in corners:
                i = list(cell)
                i[axis] += sign > 0
                i[u] += du
                i[v] += dv
                point = tuple(coords[a][k] for a, k in enumerate(i))
                if point not in indices:
                    indices[point] = len(points)
                    points.append(point)
                poly.append(indices[point])
            faces.append(tuple(poly))
    return points, faces

def back_hair(label, bands, cell, sweep):
    old = scene.objects["Scout Nape | " + label]
    replace(old)

    def depth(y,z,hero):
        tucked = max(0, min(1, (y - 52) / 60)) * (15 if hero else 28)
        root_offset = max(0, min(1, (z - 412) / 25)) * 9
        return round(y - tucked - root_offset, 2)

    boxes = []
    for x,y,top,bottom,width,thickness in bands:
        z = (top + bottom) * .5
        boxes.append(((x - width/2, x + width/2),
                      (depth(y - thickness/2,z,False), depth(y + thickness/2,z,False)),
                      (bottom,top)))
    points, faces = cuboid_union(boxes)
    new = mesh_object("Nape · " + label, points, faces, "Head", cell, .5 if cell == 4 else 1.4)
    if sweep:
        new.shape_key_add(name="Rest")
        hero = new.shape_key_add(name="Loose hair in hero stance")
        for vertex in hero.data:
            x,y,z = vertex.co/S
            pull = max(0, min(1, (bands[0][2] - z + 4) / 48))
            change = max(0, min(1, (y - 52) / 32)) * 13
            if x < 4:
                x -= max(0,min(1,(392-z)/72))*4
            vertex.co = S*Vector((x-sweep*pull,y+change+2*pull,z))
        hero.driver_add("value").driver.expression = "1.0 if frame == 2 else 0.0"

def hair():
    for sign, side in ((-1,"R"),(1,"L")):
        back_hair(side + " lower tier outside", [
            (sign*40,70,387,346,23,22),(sign*39,75,346,331,17,24),
            (sign*35,74,331,323,11,18)], 5, 7 if sign<0 else 0)
        back_hair(side + " lower tier inner", [
            (sign*27,78,375,343,24,22),(sign*26,83,343,324,20,24),
            (sign*21,81,324,312,13,20)], 4, 10 if sign<0 else 0)
        back_hair(side + " upper tier outside", [
            (sign*41,81,436,409,22,22),(sign*39,87,409,390,22,26),
            (sign*34,87,390,377,15,20)], 5, 6 if sign<0 else 0)
        back_hair(side + " upper tier inner", [
            (sign*21,85,436,407,25,25),(sign*20,92,407,387,25,29),
            (sign*16,94,387,367,15,23)], 4, 7 if sign<0 else 0)
    back_hair("Lower middle lock", [
        (0,81,371,331,32,23),(0,88,331,307,26,26),
        (-2,90,307,295,19,24),(-2,88,295,284,10,18)],5,3)
    back_hair("Upper center lock", [
        (0,87,429,409,28,24),(0,96,409,383,27,31),
        (-1,100,383,362,25,30),(-1,100,362,349,18,24),
        (-1,97,349,342,11,20)],5,7)

    # A longer central lock and a recessed right lock keep the reference's uneven fringe.
    knots = (
        ((-47,-30,455,470,-59),(-47,-35,439,455,-59)),
        ((-35,-11,458,472,-60.6),(-36,-16,444,458,-61.1),(-36,-22,437,444,-61.1)),
        ((-15,13,458,472,-58.8),(-15,9,442,458,-59.5),(-13,3,433.5,442,-59.6)),
        ((10,46,460,471,-55.8),(22,46,447,460,-55.3),(31,46,435,447,-54.6)),
    )
    for i, steps in enumerate(knots,1):
        replace(scene.objects[N + f"Forelock {i}"])
        points,faces = cuboid_union([((x0,x1),(y,y+8),(z0,z1)) for x0,x1,z0,z1,y in steps])
        mesh_object(f"Fringe · lock {i}",points,faces,"Head",4,(i%3)*.9)

def hood_rim():
    hood = next(o for o in scene.objects if o.name.endswith("hood with returned lining"))
    for obj in scene.objects:
        if obj.name.startswith(N) and "hood bound step" in obj.name:
            replace(obj)

    def sample(x,z):
        found,hit,_,_ = hood.ray_cast(Vector((x*S,-1,z*S)),Vector((0,1,0)))
        return hit.y / S if found and hit.y / S < -35 else None

    def tile(name,x,z,width,height,slope_x,slope_z,cell,seat=None):
        # Axes remain perpendicular on the local cloth plane.
        axis_u = Vector((1,slope_x,0)).normalized()
        axis_v = Vector((0,slope_z,1))
        axis_v = (axis_v-axis_u*axis_v.dot(axis_u)).normalized()
        away = axis_v.cross(axis_u)
        estimate = sample(x,z)
        y = estimate if seat is None else seat
        assert y is not None, name
        center = Vector((x,y,z)) + away*1.25
        dimensions = (width*.5/axis_u.x, 3.6, height*.5/axis_v.z)
        points,faces = cuboid_union([[(-r,r) for r in dimensions]])
        placed = [tuple(center + axis_u*u + away*v + axis_v*w) for u,v,w in points]
        mesh_object("Hood · "+name,placed,faces,"Head",cell,(len(name)%3)*.65)

    # The highest tab is inset near the middle of the crown. The other tabs
    # share an approximate outer edge and progressively turn onto the flanks.
    tile("raised center tab",-5,491,18,17,0,.70,0,-64.7)
    tile("crest across forehead",-1,478,77,14,0,.63,0,-72.4)
    for sign,side in ((-1,"R"),(1,"L")):
        for i,(x,z,width,height,sx,sz,cell,seat) in enumerate((
            (48,472,20,15,.17,.40,0,-74.1),
            (55,455,13,21,.63,.06,0,-74.0),
            (62,436,11,20,.94,.05,1,-69.2),
            (69,417,11,20,1.05,.08,1,-61.6),
            (77,399,12,19,.95,.09,1,-54.7),
        ),1):
            tile(f"{side} cheek tab {i}",sign*x,z,width,height,sign*sx,sz,cell,seat)

def cloak_hem():
    cloak = scene.objects[P + "Long cloak with tapered supporting folds"]
    mesh = cloak.data
    # Pair the inside and outside of each seam. The hem keeps the same lower
    # landmarks while the risers become vertical in the back projection.
    for key in mesh.shape_keys.key_blocks:
        for i in range(1,24,2):
            a,b = 125+i,126+i
            for wall in (0,150):
                left,right = (key.data[j+wall].co for j in (a,b))
                seam = (left.x+right.x)*.5
                left.x = seam
                right.x = seam
        # Pair each tab's edge depth to keep a broad bottom plane.
        for i in range(0,24,2):
            for wall in (0,150):
                a,b = (key.data[j+wall].co for j in (125+i,126+i))
                depth = (a.y+b.y)*.5
                a.y = a.y*.37 + depth*.63
                b.y = b.y*.37 + depth*.63
    mesh.update()

operations = {"hair": hair, "rim": hood_rim, "hem": cloak_hem}
operations[stage]()
scene["Source-fit pass"] = f"Fitted rectangular details · {stage}"
keys = {m.name.casefold():(m.frame,m.camera) for m in scene.timeline_markers if m.camera}
render(scene,[(keys[v][0],v,keys[v][1]) for v in ("front","hero","right","back","left")],out)
scene.render.filepath = "//Scout review.png"
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"Scout.blend"),compress=True,relative_remap=False)


