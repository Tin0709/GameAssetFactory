"""Build the user's sand/graphite block rifle reference as a separate review asset.

Blender +Y forward, +Z up; grip-centered, no mechanical internals.
Run with a fresh background Blender. Never edits another weapon source.
"""
import argparse
import bmesh
import bpy
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
TARGET = OUT / 'Rifle_Sand_Block_V1.blend'
parser = argparse.ArgumentParser()
parser.add_argument('--rebuild', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
assert args.rebuild or not TARGET.exists(), 'Explicit --rebuild required for this Pending source'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'Rifle Sand Block V1 — Reference Study'
scene.unit_settings.system = 'METRIC'
export = bpy.data.collections.new('WEAPON_EXPORT')
scene.collection.children.link(export)
root = bpy.data.objects.new('Rifle_Sand_Block_V1', None)
export.objects.link(root)
root['review_status'] = 'Pending'
root['forward'] = '+Y'
root['origin'] = 'RightHandGrip'
root['reference'] = 'reference.png — supplied by user 2026-10-19'

# Sixteen padded 64px swatches, with sparse broad rectangular color clusters.
colors = [
    (173, 145, 95), (193, 164, 110), (151, 126, 83), (211, 184, 132),
    (53, 51, 51), (66, 63, 62), (43, 42, 43), (82, 76, 69),
    (29, 30, 32), (102, 91, 74), (127, 109, 79), (57, 52, 48),
    (112, 48, 28), (153, 65, 33), (79, 34, 23), (22, 23, 25),
]
size = 256
pixels = [0.0] * (size * size * 4)
rng = random.Random(20261019)
for tile, rgb in enumerate(colors):
    values = [[1.0] * 64 for _ in range(64)]
    for _ in range(95):
        x, y = rng.randrange(2, 58), rng.randrange(2, 58)
        w, h = rng.choice([4, 6, 8, 12]), rng.choice([3, 4, 6, 8])
        shade = rng.choice([.935, .965, .985, 1.025, 1.045])
        for yy in range(y, min(62, y + h)):
            for xx in range(x, min(62, x + w)):
                values[yy][xx] = shade
    for y in range(64):
        for x in range(64):
            i = (((tile // 4) * 64 + y) * size + (tile % 4) * 64 + x) * 4
            # Blender pixel storage is linear; retain the requested sRGB palette.
            vals = [min(1, c / 255 * values[y][x]) for c in rgb]
            pixels[i:i+4] = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in vals] + [1]
atlas = bpy.data.images.new('Sand_Block_Atlas_256', width=size, height=size, alpha=True)
atlas.pixels.foreach_set(pixels)
atlas.filepath_raw = str(OUT / 'sand_block_atlas_256.png')
atlas.file_format = 'PNG'
atlas.save()
atlas.pack()
mat = bpy.data.materials.new('Sand_Block_Matte_Atlas')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = .72
bsdf.inputs['Metallic'].default_value = .10
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = atlas
tex.interpolation = 'Closest'
mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
parts, magazines = [], []


def mesh(name, vertices, faces, tile=0, bevel=0, magazine=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    export.objects.link(ob)
    data.materials.append(mat)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    if bevel:
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        mod = ob.modifiers.new('Block edge chamfer', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        mod.affect = 'EDGES'
        bpy.ops.object.modifier_apply(modifier=mod.name)
    uv = data.uv_layers.new(name='SandBlockUV')
    for poly in data.polygons:
        normal = poly.normal
        drop = max(range(3), key=lambda i: abs(normal[i]))
        axes = [i for i in range(3) if i != drop]
        for li in poly.loop_indices:
            co = data.vertices[data.loops[li].vertex_index].co
            # Broad pixels at a consistent world density; never sample tile edges.
            u, v = [(co[a] * 1.60 + .46) % .84 + .08 for a in axes]
            uv.data[li].uv = ((tile % 4 + u) / 4, (tile // 4 + v) / 4)
        poly.use_smooth = False
    group = ob.vertex_groups.new(name=name)
    group.add(list(range(len(data.vertices))), 1.0, 'REPLACE')
    (magazines if magazine else parts).append(ob)
    return ob


def profile(name, yz, width, tile=0, bevel=0, x=0, magazine=False):
    n = len(yz)
    vertices = [(x + xx, y, z) for xx in [-width/2, width/2] for y, z in yz]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1) % n, (i+1) % n+n, i+n) for i in range(n)]
    return mesh(name, vertices, faces, tile, bevel, magazine)


def box(name, center, dims, tile=0, bevel=0, magazine=False):
    x, y, z = center
    w, length, h = dims
    return profile(name, [(y-length/2, z-h/2), (y+length/2, z-h/2),
                          (y+length/2, z+h/2), (y-length/2, z+h/2)],
                   w, tile, bevel, x, magazine)


def section(w, h, chamfer):
    return [(-w/2+chamfer, -h/2), (w/2-chamfer, -h/2),
            (w/2, -h/2+chamfer), (w/2, h/2-chamfer),
            (w/2-chamfer, h/2), (-w/2+chamfer, h/2),
            (-w/2, h/2-chamfer), (-w/2, -h/2+chamfer)]


def housing(name, rings, z, tile=4, hollow=None):
    # rings: (Y position, width, height, corner chamfer)
    vs = [(x, y, z+zz) for y, w, h, c in rings for x, zz in section(w, h, c)]
    fs = [tuple(reversed(range(8)))]
    for j in range(len(rings)-1):
        fs += [(j*8+i, j*8+(i+1) % 8, (j+1)*8+(i+1) % 8, (j+1)*8+i) for i in range(8)]
    end = (len(rings)-1)*8
    if hollow:
        w, h, depth = hollow
        start = len(vs)
        vs += [(x, rings[-1][0], z+zz) for x, zz in section(w, h, min(w, h)*.06)]
        vs += [(x, rings[-1][0]-depth, z+zz) for x, zz in section(w, h, min(w, h)*.06)]
        for i in range(8):
            k = (i+1) % 8
            fs += [(end+i, end+k, start+k, start+i), (start+i, start+k, start+8+k, start+8+i)]
        fs.append(tuple(start+8+i for i in range(8)))
    else:
        fs.append(tuple(end+i for i in range(8)))
    return mesh(name, vs, fs, tile)


# Rear rubber pad, full upper stock and stair-stepped lower silhouette.
box('Stock_Rubber_Pad', (0, -.327, .066), (.084, .024, .209), 8, .0014)
profile('Stock_Tan_Upper', [(-.315,.105), (-.116,.105), (-.105,.129),
                          (-.117,.168), (-.308,.174), (-.315,.164)], .078, 0, .0016)
profile('Stock_Stepped_Heel', [(-.310,-.038), (-.263,-.038), (-.263,-.010),
                             (-.247,-.010), (-.247,.023), (-.227,.023),
                             (-.227,.058), (-.202,.058), (-.202,.093),
                             (-.169,.093), (-.169,.120), (-.310,.120)], .067, 0, .0008)
for side in [-1, 1]:
    box('Stock_Shadow_Inset', (side*.035, -.257, .099), (.004,.081,.020), 11)
    box('Stock_Cheek_Block', (side*.037, -.205, .123), (.007,.132,.038), 0)
box('Stock_Neck', (0,-.101,.131), (.062,.053,.059), 6, .001)
box('Stock_Locking_Collar', (0,-.112,.139), (.090,.022,.074), 4, .001)

# Flat, shallow receiver with a separate stepped lower and magazine well.
profile('Upper_Receiver', [(-.092,.090), (.251,.090), (.257,.161),
                           (.231,.176), (-.076,.176), (-.092,.161)], .084, 0, .0012)
profile('Lower_Receiver', [(-.050,.049), (.029,.042), (.043,.027),
                          (.124,.027), (.124,.020), (.232,.032),
                          (.238,.096), (-.054,.100)], .077, 0, .001)
box('Receiver_Top_Trim', (0,.076,.174), (.074,.327,.011), 1, .0006)
box('Magazine_Well_Lip', (0,.178,.032), (.081,.118,.016), 2, .0008)
for side in [-1,1]:
    box('Receiver_Latch', (side*.047,.020,.136), (.011,.036,.023), 4, .0008)
    box('Latch_End', (side*.049,.009,.136), (.013,.006,.023), 6)
    box('Receiver_Small_Lower_Tab', (side*.041,.034,.083), (.005,.043,.018), 1)
    for yy in [.025,.043]:
        box('Receiver_Pin', (side*.044,yy,.084), (.003,.006,.006), 9)
box('Charging_Handle', (0,-.068,.183), (.105,.022,.012), 4, .0008)

# Fore-end: seven genuine openings on each side, with the dark core recessed.
box('Handguard_Inner_Barrel', (0,.390,.126), (.035,.304,.034), 8)
box('Handguard_Top_Spine', (0,.388,.165), (.094,.292,.023), 1, .0013)
box('Handguard_Bottom_Spine', (0,.388,.090), (.092,.292,.020), 2, .001)
for side in [-1,1]:
    x = side*.043
    box('Vent_Panel_Top', (x,.388,.151), (.012,.292,.022), 1, .0006)
    box('Vent_Panel_Bottom', (x,.388,.104), (.012,.292,.022), 0, .0006)
    for i in range(8):
        box('Vent_Bridge_%s_%02d' % (side,i), (x,.253+i*.038,.1275), (.012,.015,.050), 0, .0005)
    box('Front_Handguard_Rim', (x,.533,.127), (.014,.016,.082), 1, .0008)
box('Handguard_Rear_Band', (0,.246,.127), (.101,.021,.087), 1, .0014)
box('Handguard_Front_Band', (0,.536,.123), (.098,.019,.087), 4, .0012)

# Continuous square rail teeth: a broad readable rhythm, including beneath scope.
box('Upper_Rail_Base', (0,.228,.181), (.048,.632,.011), 6)
for i in range(25):
    box('Top_Rail_Tooth_%02d'%i, (0,-.077+i*.0255,.191), (.060,.014,.013), 4, .0005)
box('Lower_Rail_Base', (0,.390,.078), (.057,.278,.012), 6)
for i in range(11):
    box('Lower_Rail_Tooth_%02d'%i, (0,.264+i*.0255,.071), (.066,.014,.012), 6)

# Raked graphite grip with broad inset panels and a closed, open-centered guard.
profile('Grip_Main', [(-.025,.067), (.034,.046), (-.025,-.109),
                      (-.043,-.116), (-.099,-.089)], .058, 4, .0017)
profile('Grip_Heel', [(-.099,-.089), (-.043,-.116), (-.025,-.109),
                      (-.024,-.126), (-.044,-.131), (-.106,-.102)], .065, 7, .0007)
for side in [-1,1]:
    profile('Grip_Inset', [(-.030,.033), (.012,.016), (-.033,-.087),
                          (-.076,-.069)], .003, 5, .0005, side*.030)
    profile('Grip_Tan_Backstrap', [(.020,.033), (.033,.041), (-.025,-.109),
                                 (-.038,-.115)], .004, 9, 0, side*.030)
profile('Trigger_Guard', [(.017,.057), (.115,.057), (.121,.009),
                         (.029,.009), (.020,.021), (.028,.027),
                         (.103,.027), (.104,.045), (.017,.045)], .026, 9, .0007)
profile('Trigger', [(.064,.059), (.074,.056), (.069,.033),
                   (.059,.027), (.055,.033), (.061,.039)], .011, 8)

# Slightly forward-slanted straight magazine, three long stamped flutes.
mag_outline = [(.112,.037), (.214,.037), (.241,-.137), (.133,-.152)]
profile('Magazine_Main', mag_outline, .066, 5, .0011, magazine=True)
profile('Magazine_Floorplate', [(.131,-.140),(.242,-.127),(.245,-.146),
                               (.133,-.161)], .073, 7, .0006, magazine=True)
for side in [-1,1]:
    for i in range(3):
        yy = .124+i*.030
        profile('Magazine_Flute', [(yy,.021),(yy+.009,.021),
                                  (yy+.030,-.134),(yy+.020,-.136)],
                .002, 6, 0, side*.0337, True)
    profile('Magazine_Front_Edge', [(.201,.028),(.212,.028),
                                   (.237,-.132),(.225,-.134)],
            .003, 9, 0, side*.034, True)

# Octagonal barrel and a large chamfered rectangular muzzle, with a real recess.
housing('Barrel', [(.535,.034,.034,.008),(.755,.034,.034,.008)], .123, 4)
housing('Barrel_Rear_Collar', [(.544,.056,.054,.011),(.568,.056,.054,.011),
                              (.577,.043,.042,.008)], .123, 5)
housing('Barrel_Mid_Collar', [(.629,.043,.043,.008),(.642,.043,.043,.008)], .123, 6)
housing('Muzzle_Throat', [(.704,.041,.042,.008),(.714,.061,.061,.010),
                        (.746,.061,.061,.010)], .123, 4)
housing('Muzzle_Main', [(.742,.062,.061,.009),(.755,.077,.074,.012),
                       (.851,.077,.074,.012),(.864,.068,.066,.007)],
        .123, 5, hollow=(.025,.034,.040))
housing('Muzzle_Front_Lip', [(.847,.079,.076,.012),(.866,.071,.068,.008)],
        .123, 7, hollow=(.025,.034,.006))
box('Muzzle_Top_Block', (0,.816,.163), (.026,.026,.006), 6)
for side in [-1,1]:
    box('Muzzle_Side_Recess', (side*.0387,.838,.125), (.001,.016,.032), 8)

# Front sight tower with an open square aperture and small offset lug.
box('Sight_Tower_Base', (0,.548,.166), (.059,.031,.063), 4, .0009)
for side in [-1,1]:
    box('Sight_Tower_Ear', (side*.021,.548,.221), (.014,.032,.057), 7, .0007)
box('Sight_Tower_Top', (0,.548,.245), (.054,.033,.012), 7, .0005)
box('Sight_Tower_Sill', (0,.548,.201), (.054,.032,.012), 5)
box('Sight_Pin', (0,.548,.214), (.006,.012,.019), 6)
box('Sight_Side_Lug', (.036,.549,.185), (.022,.017,.017), 7, .0005)

# Squared low-poly optic with stepped barrels, recessed amber glass and turrets.
for yy in [-.022,.143]:
    box('Scope_Mount_Foot', (0,yy,.198), (.079,.033,.013), 6, .0006)
    box('Scope_Mount_Riser', (0,yy,.213), (.039,.026,.030), 4, .0006)
box('Scope_Mount_Bridge', (0,.063,.214), (.048,.208,.014), 4, .0006)
housing('Scope_Central_Tube', [(-.025,.054,.055,.009),(.170,.054,.055,.009)], .253, 5)
housing('Scope_Ocular', [(-.066,.064,.066,.008),(-.058,.077,.078,.010),
                         (-.024,.077,.078,.010),(-.014,.060,.061,.007)], .253, 4)
housing('Scope_Rear_Eyecup', [(-.073,.058,.060,.008),(-.060,.058,.060,.008)], .253, 6)
for i, yy in enumerate([.006,.045,.085,.125]):
    housing('Scope_Band_%02d'%i, [(yy,.065,.065,.010),(yy+.019,.065,.065,.010)], .253, 4 if i%2 else 7)
housing('Scope_Objective_Shoulder', [(.150,.060,.061,.009),(.161,.080,.078,.006),
                                     (.199,.080,.078,.006)], .253, 5)
housing('Scope_Objective_Rim', [(.195,.085,.083,.004),(.229,.085,.083,.004)],
        .253, 7, hollow=(.061,.061,.009))
box('Scope_Amber_Glass', (0,.221,.253), (.058,.0015,.058), 12)
box('Scope_Amber_Reflection', (-.016,.222,.254), (.009,.001,.050), 13)
box('Scope_Dark_Glass_Edge', (.025,.222,.253), (.007,.001,.057), 14)
box('Scope_Turret_Stem', (0,.048,.293), (.026,.030,.021), 4)
box('Scope_Turret_Cap', (0,.048,.309), (.042,.042,.015), 7, .0007)
box('Scope_Turret_Top', (0,.048,.319), (.026,.027,.008), 5)
box('Scope_Side_Turret', (.042,.048,.255), (.030,.037,.033), 4, .001)
box('Scope_Side_Cap', (.059,.048,.255), (.009,.028,.027), 7, .0006)
for side in [-1,1]:
    box('Scope_Mount_Pin', (side*.040,.134,.199), (.003,.007,.007), 8)


def join(objs, name, pivot=(0,0,0)):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = name
    for vertex in ob.data.vertices:
        vertex.co -= Vector(pivot)
    ob.parent = root
    ob.location = pivot
    return ob


body = join(parts, 'Rifle_Sand_Block_Body')
mag = join(magazines, 'Rifle_Sand_Block_Magazine', (0,.163,.030))
mag['role'] = 'Separate magazine; feed-mouth pivot'
markers = {'RightHandGrip':(0,0,0), 'LeftHandGuide':(0,.350,.077),
           'Muzzle':(0,.867,.123), 'AimReference':(0,.220,.253),
           'RecoilPivot':(0,0,0), 'HolsterAttach':(0,0,0),
           'Grip_Point':(0,0,0), 'Support_Hand_Point':(0,.350,.077),
           'Muzzle_Point':(0,.867,.123)}
for name, pos in markers.items():
    ob = bpy.data.objects.new(name, None)
    export.objects.link(ob)
    ob.parent = root
    ob.location = pos
    ob.empty_display_size = .025
    root[name] = list(pos)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for ob in export.objects:
    ob.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.export_scene.gltf(filepath=str(OUT/'Rifle_Sand_Block_V1.glb'),
                          export_format='GLB', use_selection=True,
                          export_animations=False, export_cameras=False, export_lights=False)
pts = [ob.matrix_world @ v.co for ob in [body,mag] for v in ob.data.vertices]
report = {'status':'Pending', 'source_reference':'reference.png', 'meshes':2,
          'materials':1, 'atlas_size':[256,256], 'markers':markers,
          'dimensions_m':[max(v[i] for v in pts)-min(v[i] for v in pts) for i in range(3)],
          'topology':{}}
for ob in [body,mag]:
    ob.data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    report['topology'][ob.name] = {'triangles':len(ob.data.loop_triangles),
                                 'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
                                 'loose_vertices':sum(not v.link_faces for v in bm.verts)}
    bm.free()
    assert report['topology'][ob.name]['nonmanifold_edges'] == 0
    assert report['topology'][ob.name]['loose_vertices'] == 0
report['triangles'] = sum(t['triangles'] for t in report['topology'].values())
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))

# Presentation lives outside WEAPON_EXPORT and is never appended to the library.
studio = bpy.data.collections.new('SOURCE_REVIEW_STUDIO')
scene.collection.children.link(studio)
world = bpy.data.worlds.new('Graphite Studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.075,.080,.092,1)
world.node_tree.nodes['Background'].inputs[1].default_value = .45
scene.world = world
floor_mat = bpy.data.materials.new('Graphite Floor')
floor_mat.diffuse_color = (.035,.039,.047,1)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.164))
floor = bpy.context.object
floor.name = 'Review_Ground'
for col in list(floor.users_collection):
    col.objects.unlink(floor)
studio.objects.link(floor)
floor.data.materials.append(floor_mat)
focus = Vector((0,.263,.080))
for name, pos, power, width, color in [
    ('Key', (1.0,.0,1.8), 95, 1.8, (1,.90,.76)),
    ('Fill', (1.4,1.9,.7), 55, 1.4, (.76,.85,1)),
    ('Rim', (-.8,-.1,1.2), 115, 1.5, (1,.85,.65)),
]:
    data = bpy.data.lights.new(name,'AREA')
    data.energy, data.size, data.color = power, width, color
    ob = bpy.data.objects.new(name,data)
    studio.objects.link(ob)
    ob.location = pos
    ob.rotation_euler = (focus-ob.location).to_track_quat('-Z','Y').to_euler()
cam = bpy.data.objects.new('Reference_Review_Camera',bpy.data.cameras.new('Reference_Review_Camera'))
studio.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 1.39
cam.location = focus+Vector((1.65,.85,.52))
cam.rotation_euler = (focus-cam.location).to_track_quat('-Z','Y').to_euler()
scene.camera = cam
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.threads_mode = 'FIXED'
scene.render.threads = 8
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene['review_status'] = 'Pending'
scene['asset_report'] = json.dumps(report)
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            sp = area.spaces.active
            sp.overlay.show_overlays = False
            sp.shading.type = 'MATERIAL'
            sp.region_3d.view_rotation = cam.rotation_euler.to_quaternion()
            sp.region_3d.view_location = focus
            sp.region_3d.view_distance = 1.7
            sp.region_3d.view_perspective = 'ORTHO'
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
review = OUT/'review'
review.mkdir(exist_ok=True)
for name, direction in [('three_quarter',(1.65,.85,.52)), ('side',(2,0,.05)),
                        ('top',(.001,0,2)), ('front',(0,2,.03))]:
    cam.location = focus+Vector(direction)
    cam.rotation_euler = (focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale = 1.39 if name != 'front' else .66
    scene.render.filepath = str(review/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('RIFLE_SAND_BLOCK_BUILT',json.dumps(report),flush=True)
