"""Fresh block character, pixel atlas, expressive face and stepped sabre.

No source asset is opened by this module. All geometry, UVs and pixels below are
authored numerically. Coordinates are Blender Z-up, forward -Y, character left +X.
The rigid rig deliberately has no elbows or knees. Animation belongs to motion.py.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector


PALETTE = {
    "red": (0.584, 0.125, 0.157),
    "red_light": (0.66, 0.160, 0.183),
    "red_dark": (0.443, 0.082, 0.133),
    "skin": (0.72, 0.40, 0.235),
    "skin_light": (0.7804, 0.4902, 0.302),
    "skin_dark": (0.6392, 0.3098, 0.2196),
    "pants": (0.075, 0.065, 0.085),
    "pants_light": (0.125, 0.105, 0.14),
    "boot": (0.42, 0.22, 0.16),
    "boot_light": (0.4784, 0.2863, 0.2353),
    "armor": (0.41, 0.45, 0.47),
    "armor_light": (0.52, 0.54, 0.56),
    "armor_dark": (0.245, 0.28, 0.30),
    "belt": (0.18, 0.115, 0.095),
    "magenta": (0.85, 0.045, 0.48),
    "black": (0.025, 0.022, 0.025),
    "white": (0.92, 0.94, 0.86),
    "green": (0.102, 0.357, 0.2784),
    "green_light": (0.40, 0.85, 0.27),
    "silver": (0.7765, 0.7765, 0.7765),
    "silver_light": (0.953, 0.953, 0.953),
    "silver_dark": (0.50, 0.50, 0.50),
    "gold": (0.7255, 0.4471, 0.1529),
    "gold_light": (0.9059, 0.6588, 0.1294),
    "gold_dark": (0.54, 0.31, 0.065),
    "grip": (0.24, 0.095, 0.040),
    "cream": (0.58, 0.50, 0.35),
    "sleeve": (0.035, 0.040, 0.052),
    "sleeve_light": (0.060, 0.066, 0.081),
    "headband": (0.145, 0.165, 0.175),
    "brow": (0.2353, 0.0471, 0.0745),
}
TILES = {name: index for index, name in enumerate(PALETTE)}


def _atlas(out_dir):
    image = bpy.data.images.new("Sabre_AuthoredAtlas_128", width=128, height=128, alpha=False)
    # 16px tiles, with authored 2px flecks and a quiet edge. Integer hashes keep
    # the palette reproducible without reading a reference or sampling pixels.
    pixels = [0.0] * (128 * 128 * 4)
    colors = list(PALETTE.values())
    for y in range(128):
        for x in range(128):
            tile = (y // 16) * 8 + x // 16
            color = colors[tile] if tile < len(colors) else (0.20, 0.13, 0.20)
            lx, ly = x % 16, y % 16
            variation = (((lx // 4) * 13 + (ly // 4) * 7 + tile * 11) % 11 - 5) * .004
            if lx in (0, 15) or ly in (0, 15):
                variation -= .035
            # Flat eyes and metallic highlights retain a crisp pixel silhouette.
            if tile in [TILES[k] for k in ("black", "white", "green", "green_light", "magenta")]:
                variation = 0.0
            offset = 4 * (y * 128 + x)
            pixels[offset:offset + 4] = [max(0.0, min(1.0, c + variation)) for c in color] + [1.0]
    image.pixels.foreach_set(pixels)
    image.update()
    image.filepath_raw = str(out_dir / "Sabre_AuthoredAtlas_128.png")
    image.file_format = "PNG"
    image.save()
    image.pack()
    return image


def _material(atlas):
    material = bpy.data.materials.new("Sabre_AuthoredPixelMaterial")
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .9
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Specular IOR Level"].default_value = .15
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.name = "Original_128px_Palette"
    texture.image = atlas
    texture.interpolation = "Closest"
    material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    material.diffuse_color = (.67, .055, .075, 1)
    return material


class _Mesh:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.tiles = []
        self.groups = []
        self.parts = []

    def quad(self, coords, tile, bone, tag=""):
        start = len(self.vertices)
        self.vertices.extend(tuple(c) for c in coords)
        self.groups.extend([bone] * 4)
        self.faces.append(tuple(range(start, start + 4)))
        self.tiles.append(tile)
        self.parts.append((tag, tuple(range(start, start + 4))))

    def box(self, center, size, tile, bone, front=None, top=None):
        x, y, z = center
        hx, hy, hz = (a * .5 for a in size)
        vertices = [(x - hx, y - hy, z - hz), (x + hx, y - hy, z - hz),
                    (x + hx, y + hy, z - hz), (x - hx, y + hy, z - hz),
                    (x - hx, y - hy, z + hz), (x + hx, y - hy, z + hz),
                    (x + hx, y + hy, z + hz), (x - hx, y + hy, z + hz)]
        for index, face in enumerate([(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                                      (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]):
            color = front if index == 2 and front else top if index == 1 and top else tile
            self.quad([vertices[i] for i in face], color, bone)

    def object(self, name, collection, material, rig):
        mesh = bpy.data.meshes.new(name + "_Mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        obj.parent = rig
        obj.data.materials.append(material)
        uv = mesh.uv_layers.new(name="AuthoredPixelUV")
        for polygon, tile in zip(mesh.polygons, self.tiles):
            tile_index = TILES[tile]
            # Texel-center inset prevents neighboring palette bleeding.
            u0 = ((tile_index % 8) * 16 + .5) / 128
            v0 = ((tile_index // 8) * 16 + .5) / 128
            u1, v1 = u0 + 15 / 128, v0 + 15 / 128
            for loop, coord in zip(polygon.loop_indices, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]):
                uv.data[loop].uv = coord
            polygon.use_smooth = False
        for name in sorted(set(self.groups)):
            group = obj.vertex_groups.new(name=name)
            group.add([i for i, bone in enumerate(self.groups) if bone == name], 1.0, "REPLACE")
        modifier = obj.modifiers.new("AuthoredRigidSkin", "ARMATURE")
        modifier.object = rig
        obj["authorship"] = "Fresh procedural cuboids, original UVs and original pixel palette"
        return obj


def _rig(scene, collection):
    data = bpy.data.armatures.new("Sabre_AuthoredRigidRig")
    rig = bpy.data.objects.new("Sabre_AuthoredRig", data)
    collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    definitions = [
        ("Root", None, (0, 0, 0)),
        ("Hips", "Root", (0, 0, .75)),
        ("Body", "Hips", (0, 0, .75)),
        ("Head", "Body", (0, 0, 1.495)),
        ("Arm.L", "Body", (.3435, 0, 1.44)),
        ("Arm.R", "Body", (-.3435, 0, 1.44)),
        ("Leg.L", "Hips", (.125, 0, .75)),
        ("Leg.R", "Hips", (-.125, 0, .75)),
        ("Hand.R", "Arm.R", (-.3435, 0, .78)),
        ("Hand.L", "Arm.L", (.3435, 0, .78)),
        ("Weapon", "Hand.R", (-.3435, 0, .78)),
    ]
    for name, parent, head in definitions:
        bone = data.edit_bones.new(name)
        bone.head = head
        bone.tail = Vector(head) + Vector((0, .12 if name != "Root" else .20, 0))
        bone.roll = 0
        if parent:
            bone.parent = data.edit_bones[parent]
        bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in rig.pose.bones:
        bone.rotation_mode = "XYZ"
    rig.pose.bones["Weapon"].rotation_euler.x = math.radians(-45)
    rig.show_in_front = True
    data.display_type = "STICK"
    rig["coordinate_convention"] = "Z up; forward -Y; left +X; all rest bone bases identity"
    return rig


def _body():
    mesh = _Mesh()
    # Torso envelope matches the declared .5 x .75 x .25 block proportions.
    mesh.box((0, 0, 1.125), (.5, .25, .75), "red_dark", "Body", front="red", top="red_dark")
    mesh.box((0, -.132, 1.245), (.245, .018, .35), "red_dark", "Body")
    # Narrow, separately authored tabard edges replace the earlier chest plate.
    for sign in [-1, 1]:
        mesh.box((sign * .184, -.135, 1.247), (.080, .020, .365), "red", "Body", front="red_light")
        mesh.box((sign * .184, -.147, 1.183), (.080, .006, .061), "red", "Body")
        mesh.box((sign * .184, -.147, 1.326), (.080, .006, .050), "red_dark", "Body")
    # A quiet cream neck facing is visible directly beneath the chin.
    mesh.box((0, -.133, 1.476), (.257, .020, .043), "cream", "Body")
    mesh.box((0, -.137, 1.429), (.105, .023, .071), "cream", "Body")
    # A solid belt, metal rim, and magenta clasp are authored geometry.
    mesh.box((0, 0, .938), (.502, .258, .152), "boot", "Body", front="boot_light")
    mesh.box((0, -.137, .938), (.14, .018, .13), "armor_dark", "Body")
    mesh.box((0, -.149, .938), (.094, .009, .091), "magenta", "Body")
    mesh.box((0, -.156, .961), (.045, .004, .044), "white", "Body")
    mesh.box((-.208, -.133, .845), (.057, .013, .075), "red_dark", "Body")
    mesh.box((.208, -.133, .845), (.057, .013, .075), "red_dark", "Body")
    # Rigid shoulder-to-hand blocks; the cuffs are part of the same arm group.
    for sign, side in [(1, "L"), (-1, "R")]:
        x, bone = sign * .3435, "Arm." + side
        mesh.box((x, 0, 1.45), (.187, .25, .10), "armor_dark", bone, front="armor", top="armor_light")
        mesh.box((x, 0, 1.375), (.187, .25, .05), "sleeve", bone, front="sleeve_light")
        mesh.box((x, 0, 1.275), (.187, .25, .15), "red_dark", bone, front="red")
        mesh.box((x, 0, 1.075), (.187, .25, .25), "sleeve", bone, front="sleeve_light")
        mesh.box((x, 0, .85), (.187, .25, .20), "skin", bone, front="skin_light")
        mesh.box((x - sign * .048, -.128, .790), (.038, .006, .055), "skin", bone)
        mesh.box((sign * .125, 0, .50), (.25, .25, .50), "pants", "Leg." + side, front="pants_light")
        mesh.box((sign * .125, 0, .135), (.25, .25, .27), "boot", "Leg." + side, front="boot_light")
        mesh.box((sign * .125, -.001, .33), (.25, .252, .12), "red_dark", "Leg." + side, front="red")
        mesh.box((sign * .125, -.132, .505), (.218, .018, .185), "armor_dark", "Leg." + side, front="armor")
        mesh.box((sign * .125, -.143, .562), (.218, .006, .035), "armor", "Leg." + side)
        mesh.box((sign * .203, -.128, .690), (.094, .006, .12), "red", "Leg." + side)
        mesh.box((sign * .125, -.126, .065), (.25, .008, .07), "boot", "Leg." + side)
        mesh.box((sign * .125, -.131, .172), (.125, .005, .185), "boot_light", "Leg." + side)
    mesh.box((0, -.131, .802), (.14, .010, .085), "sleeve", "Body")
    # The hood is a cap above a broad tan face, with no lower red pillars.
    # Its complete envelope remains the declared .508 cube.
    mesh.box((0, -.005, 1.6475), (.49, .460, .305), "skin", "Head", front="skin_light")
    mesh.box((0, -.247, 1.6475), (.49, .016, .305), "skin_light", "Head")
    mesh.box((0, .209, 1.6475), (.49, .09, .305), "red_dark", "Head")
    mesh.box((0, 0, 1.9015), (.508, .508, .203), "red", "Head", front="red_light", top="red")
    for sign in [-1, 1]:
        mesh.box((sign * .2495, .005, 1.6475), (.009, .498, .305), "red_dark", "Head")
        mesh.box((sign * .215, -.2535, 1.776), (.06, .007, .048), "skin_dark", "Head")
        mesh.box((sign * .18, -.2555, 1.868), (.085, .005, .055), "red", "Head")
    mesh.box((0, -.2565, 1.824), (.508, .005, .049), "headband", "Head")
    mesh.box((0, -.2565, 1.885), (.0625, .005, .0625), "skin", "Head")
    mesh.box((0, -.2555, 1.785), (.49, .005, .027), "skin_dark", "Head")
    # Thin neck facing; the reference has no separately protruding rear scarf.
    mesh.box((0, 0, 1.489), (.408, .250, .020), "red_dark", "Body")
    return mesh


def _face():
    mesh = _Mesh()

    def patch(cx, cz, width, height, color, depth, tag):
        mesh.quad([(cx - width / 2, depth, cz - height / 2),
                   (cx + width / 2, depth, cz - height / 2),
                   (cx + width / 2, depth, cz + height / 2),
                   (cx - width / 2, depth, cz + height / 2)], color, "Head", tag)

    for sign in [-1, 1]:
        label = "L" if sign > 0 else "R"
        cx = sign * .125
        patch(cx, 1.718, .125, .0625, "white", -.259, "eye_" + label)
        patch(sign * .0925, 1.718, .0625, .0625, "green", -.260, "iris_" + label)
        # The reference has flat green inner halves, with no black pupil/glint.
        patch(cx, 1.7808, .125, .016, "brow", -.260, "brow_" + label)
        patch(cx, 1.718, .125, 0, "skin_dark", -.262, "lid_" + label)
    patch(0, 1.588, .125, .0625, "skin_dark", -.260, "mouth")
    return mesh


def _face_shapes(obj, mesh):
    obj.shape_key_add(name="Basis")
    focused = obj.shape_key_add(name="Focused")
    blink = obj.shape_key_add(name="Blink")
    for tag, indices in mesh.parts:
        if tag.startswith("brow_"):
            for index in indices:
                coord = focused.data[index].co
                # Inner corners descend, outer corners rise: a clear intent pose.
                coord.z += -.032 if abs(coord.x) < .125 else .005
        if tag.startswith(("eye_", "iris_", "pupil_", "glint_")):
            for index in indices:
                original = obj.data.vertices[index].co
                focused.data[index].co.z = 1.709 + (original.z - 1.718) * .72
                blink.data[index].co.z = 1.718 + (original.z - 1.718) * .025
        if tag.startswith("lid_"):
            for order, index in enumerate(indices):
                blink.data[index].co.z = 1.718 + (-.006 if order < 2 else .006)
        if tag == "mouth":
            for index in indices:
                coord = focused.data[index].co
                coord.z = 1.583 + (coord.z - 1.588) * .6
                coord.x *= .82
    # Blender 5.2 currently gives newly added keys value 1.0 in this workflow.
    # Geometry always hands the motion builder a clean neutral expression.
    focused.value = 0.0
    blink.value = 0.0
    obj["expression_controls"] = "Focused: lowered inner brows and narrowed eyes; Blink: eyelid closure"


def _sabre():
    mesh = _Mesh()
    wrist = Vector((-.3435, 0, .78))

    def box(center, size, tile, front=None, top=None):
        mesh.box(wrist + Vector(center), size, tile, "Weapon", front=front, top=top)

    # Joined trapezoid facets give a continuous, gently curving pixel blade.
    # Shared section endpoints eliminate the old sawtooth gaps between boxes.
    sections = [(-.133, 0, .092), (-.40, .008, .096), (-.70, .028, .100),
                (-.95, .057, .104), (-1.15, .096, .102), (-1.31, .142, .092),
                (-1.40, .195, .066), (-1.458, .263, .004)]

    def blade_quad(coords, tile):
        mesh.quad([wrist + Vector(v) for v in coords], tile, "Weapon")

    for first, second in zip(sections, sections[1:]):
        z0, x0, w0 = first
        z1, x1, w1 = second
        left0, right0, left1, right1 = x0 - w0 / 2, x0 + w0 / 2, x1 - w1 / 2, x1 + w1 / 2
        blade_quad([(left0, -.0175, z0), (left1, -.0175, z1), (right1, -.0175, z1), (right0, -.0175, z0)], "silver_light")
        blade_quad([(right0, .0175, z0), (right1, .0175, z1), (left1, .0175, z1), (left0, .0175, z0)], "silver")
        blade_quad([(left0, .0175, z0), (left1, .0175, z1), (left1, -.0175, z1), (left0, -.0175, z0)], "silver_dark")
        blade_quad([(right0, -.0175, z0), (right1, -.0175, z1), (right1, .0175, z1), (right0, .0175, z0)], "silver")
        blade_quad([(x0 - w0 * .23, -.018, z0), (x1 - w1 * .23, -.018, z1),
                    (x1 - w1 * .08, -.018, z1), (x0 - w0 * .08, -.018, z0)], "silver")
    for z, x, width in (sections[0], sections[-1]):
        blade_quad([(x - width / 2, -.0175, z), (x + width / 2, -.0175, z),
                    (x + width / 2, .0175, z), (x - width / 2, .0175, z)], "silver_dark")
    # Brown grip, pommel and the leftward D guard. The handle spans the full
    # specified unmounted axial envelope, -1.458 .. +.310 = 1.768 metres.
    box((0, 0, .085), (.077, .050, .330), "grip", front="boot_light")
    for z in [-.04, .025, .09, .155, .22]:
        box((0, -.026, z), (.079, .004, .018), "grip")
    # A continuous D-shaped ribbon has adjoining front facets. Overlapping
    # boxes at a common front depth caused black coplanar seams in Cycles.
    guard = [((.0525, .310), (.0525, .238)),
             ((-.205, .310), (-.180, .248)),
             ((-.250, .265), (-.192, .205)),
             ((-.265, .180), (-.205, .160)),
             ((-.265, -.035), (-.205, -.018)),
             ((-.240, -.149), (-.182, -.087)),
             ((.210, -.149), (.210, -.087))]

    def guard_vertex(point, depth):
        return (point[0], depth, point[1])

    for (outer0, inner0), (outer1, inner1) in zip(guard, guard[1:]):
        blade_quad([guard_vertex(outer0, -.0315), guard_vertex(outer1, -.0315),
                    guard_vertex(inner1, -.0315), guard_vertex(inner0, -.0315)], "gold_light")
        blade_quad([guard_vertex(inner0, .0315), guard_vertex(inner1, .0315),
                    guard_vertex(outer1, .0315), guard_vertex(outer0, .0315)], "gold")
        blade_quad([guard_vertex(outer0, .0315), guard_vertex(outer1, .0315),
                    guard_vertex(outer1, -.0315), guard_vertex(outer0, -.0315)], "gold_dark")
        blade_quad([guard_vertex(inner0, -.0315), guard_vertex(inner1, -.0315),
                    guard_vertex(inner1, .0315), guard_vertex(inner0, .0315)], "gold")
    for outer, inner in (guard[0], guard[-1]):
        blade_quad([guard_vertex(outer, -.0315), guard_vertex(inner, -.0315),
                    guard_vertex(inner, .0315), guard_vertex(outer, .0315)], "gold")
    return mesh


def build(scene, out_dir):
    """Build fresh objects into scene; return Blender objects and original atlas.

    Objects use root-space rest vertices and one weight of 1.0 per vertex. Weapon
    is skinned at the right wrist; the default -45deg local X pose is not baked
    into its mesh. No Actions, cameras, lights or external assets are created.
    """
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    collection = bpy.data.collections.new("MD2_Sabre_Authored_v001")
    scene.collection.children.link(collection)
    atlas = _atlas(out_dir)
    material = _material(atlas)
    rig = _rig(scene, collection)
    body_mesh, face_mesh, sabre_mesh = _body(), _face(), _sabre()
    body = body_mesh.object("Sabre_AuthoredCharacter", collection, material, rig)
    face = face_mesh.object("Sabre_AuthoredFace", collection, material, rig)
    _face_shapes(face, face_mesh)
    sabre = sabre_mesh.object("Sabre_AuthoredSteppedBlade", collection, material, rig)
    bpy.context.view_layer.update()
    metrics = {
        "authored_from_scratch": True,
        "height_m": 2.003,
        "head_cube_m": .508,
        "torso_xyz_m": [.5, .25, .75],
        "rigid_arm_xyz_m": [.187, .25, .75],
        "rigid_leg_xyz_m": [.25, .25, .75],
        "sabre_unmounted_xyz_m": [.530, .063, 1.768],
        "sabre_local_z_m": [-1.458, .310],
        "atlas_size": 128,
        "bones": len(rig.data.bones),
        "triangles": sum(len(p.vertices) - 2 for obj in (body, face, sabre) for p in obj.data.polygons),
        "shape_keys": ["Focused", "Blink"],
    }
    return {"rig": rig, "body": body, "face": face, "sabre": sabre,
            "atlas": atlas, "materials": [material], "metrics": metrics}
