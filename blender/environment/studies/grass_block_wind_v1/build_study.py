"""Run only in a fresh, factory-startup background Blender process."""
import bpy
import bmesh
import math
import random
import json
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
BLEND = OUT / 'grass_block_wind_v1.blend'
if bpy.data.filepath:
    raise RuntimeError('Build requires a fresh unsaved factory session.')
if BLEND.exists():
    raise RuntimeError('Study already exists; do not overwrite it with the build recipe.')
OUT.mkdir(parents=True, exist_ok=True)
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
scene = bpy.context.scene
scene.name = 'ENV_Grass_Block_Wind_Review'
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1100
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 96
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.render.film_transparent = False
scene.world.color = (0.24, 0.24, 0.24)
scene.world.use_nodes = True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value = (0.32, 0.36, 0.39, 1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value = 0.42

assets = bpy.data.collections.new('01_ASSETS')
wind_col = bpy.data.collections.new('02_WIND_PREVIEW')
studio = bpy.data.collections.new('03_REVIEW_STUDIO')
for col in (assets, wind_col, studio):
    scene.collection.children.link(col)

def srgb(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def rgb(hex_code):
    return tuple(srgb(int(hex_code[k:k+2], 16) / 255) for k in (0, 2, 4)) + (1.0,)

def pixel_rgb(hex_code):
    # Byte-backed generated images store sRGB values; material constants use linear.
    return tuple(int(hex_code[k:k+2], 16) / 255 for k in (0, 2, 4)) + (1.0,)

# A small, padded, nearest-sampled atlas. No external dependency after packing.
palette = {
    'dirt': ['A78260', '94704F', 'B28B67', '896647', '9F7855'],
    'top': ['91BE5B', '80AD4E', '73A245', '9AC463'],
    'rim': ['7FA751', '739A46', '84AB55'],
    'blade': ['536F42', '668650', '73955C', '7D9F64', '5E7D4B', '6D8D56'],
}
W = 64
pixels = [0.0] * (W * W * 4)
def put(x, y, color):
    idx = (y * W + x) * 4
    pixels[idx:idx+4] = color

tiles = [(2, 2), (22, 2), (42, 2), (2, 22), (22, 22), (42, 22)]
rng = random.Random(817)
for tile_index, (ox, oy) in enumerate(tiles):
    colors = [[palette['dirt'][0] for x in range(16)] for y in range(16)]
    if tile_index < 4 or tile_index == 5:
        # Broad pixel groups, deliberately sparse: no high-frequency noise.
        for i in range(23):
            x, y = rng.randrange(16), rng.randrange(15)
            ww, hh = rng.choice((1, 1, 2)), rng.choice((1, 2, 2))
            color = rng.choice(palette['dirt'][1:])
            for yy in range(y, min(16, y+hh)):
                for xx in range(x, min(16, x+ww)):
                    colors[yy][xx] = color
    else:
        colors = [[palette['top'][0] for x in range(16)] for y in range(16)]
        for x, y, ww, hh in ((2,3,2,2),(8,2,1,1),(12,7,2,2),(5,11,2,2),(10,12,1,1),(1,13,1,1),(7,7,1,1),(13,13,1,1)):
            for yy in range(y, y+hh):
                for xx in range(x, x+ww):
                    colors[yy][xx] = palette['top'][2 if ww == 2 else 1]
    for y in range(-2, 18):
        for x in range(-2, 18):
            put(ox+x, oy+y, pixel_rgb(colors[max(0,min(15,y))][max(0,min(15,x))]))

# Flat-color swatches in the unused upper atlas area.
swatches = {}
for i, code in enumerate(palette['rim'] + palette['blade']):
    x, y = 3 + (i % 9) * 6, 47
    for yy in range(y-2, y+3):
        for xx in range(x-2, x+3):
            put(xx, yy, pixel_rgb(code))
    swatches[code] = ((x+.5)/64, (y+.5)/64)
atlas = bpy.data.images.new('ENV_Atlas_64_Nearest', width=64, height=64, alpha=False)
atlas.pixels.foreach_set(pixels)
atlas.filepath_raw = str(OUT / 'environment_atlas_64.png')
atlas.file_format = 'PNG'
atlas.save()
atlas.pack()

mat = bpy.data.materials.new('ENV_Pixel_Atlas_Opaque')
mat.diffuse_color = rgb(palette['top'][0])
mat.use_nodes = True
nt = mat.node_tree
tex = nt.nodes.new('ShaderNodeTexImage')
tex.name = 'NEAREST_64_PIXEL_ATLAS'
tex.image = atlas
tex.interpolation = 'Closest'
tex.extension = 'EXTEND'
bsdf = nt.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 0.9
bsdf.inputs['Specular IOR Level'].default_value = 0.08
nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])

def tile_uv(tile, u, v):
    ox, oy = tiles[tile]
    return ((ox + 16*u) / 64, (oy + 16*v) / 64)

def mesh_obj(name, vertices, faces, uvs, collection=assets):
    mesh = bpy.data.meshes.new(name + '_Mesh')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    uv = mesh.uv_layers.new(name='UV_Atlas')
    # Recalculated normals may reverse faces; use vertex-coordinate keyed UVs.
    maps = [{vi: value for vi, value in zip(face, coords)} for face, coords in zip(faces, uvs)]
    for p, mapping in zip(mesh.polygons, maps):
        p.use_smooth = False
        for li in p.loop_indices:
            uv.data[li].uv = mapping[mesh.loops[li].vertex_index]
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    mesh.materials.append(mat)
    return obj

# One closed, connected mesh. Rim thickness is entirely INSIDE the 1m bounds.
# Side-wall strips meet an inset dirt body; bridges close the step changes.
verts, faces, uvs = [], [], []
lookup = {}
def vertex(co):
    key = tuple(round(c, 8) for c in co)
    if key not in lookup:
        lookup[key] = len(verts)
        verts.append(key)
    return lookup[key]

def face(coords, uvcoords):
    faces.append([vertex(co) for co in coords])
    uvs.append(uvcoords)

def border(side, t, z, inner=False):
    a = 0.494 if inner else 0.5
    if side == 0: return (-a + 2*a*t, -a, z)
    if side == 1: return (a, -a + 2*a*t, z)
    if side == 2: return (a - 2*a*t, a, z)
    return (-a, a - 2*a*t, z)

profiles = [
    [2,3,2,4,2,3,2,2],
    [2,2,4,2,3,2,4,2],
    [2,3,2,2,4,2,3,2],
    [2,2,3,4,2,3,2,2],
]
depths = [[1 - d/16 for d in p] for p in profiles]
top, bottom = [], []
for side in range(4):
    ds = depths[side]
    for i, d in enumerate(ds):
        left, right = i/8, (i+1)/8
        prev = ds[i-1] if i else depths[(side-1)%4][-1]
        nxt = ds[i+1] if i < 7 else depths[(side+1)%4][0]
        top.append(border(side,left,1))
        bottom.append(border(side,left,0,True))
        # Intermediate vertices resolve all T-junctions at adjacent step levels.
        coords = [border(side,left,1), border(side,right,1)]
        uvcoords = [swatches[palette['rim'][0]]] * 2
        if d < nxt < 1:
            coords.append(border(side,right,nxt)); uvcoords.append(swatches[palette['rim'][0]])
        coords += [border(side,right,d), border(side,left,d)]
        uvcoords += [swatches[palette['rim'][i%3]]] * 2
        if d < prev < 1:
            coords.append(border(side,left,prev)); uvcoords.append(swatches[palette['rim'][0]])
        # A uniform green swatch per strip preserves intentional pixel blocks.
        face(coords, [swatches[palette['rim'][i%3]]] * len(coords))
        coords = [border(side,left,0,True), border(side,right,0,True)]
        if 0 < nxt < d: coords.append(border(side,right,nxt,True))
        coords += [border(side,right,d,True), border(side,left,d,True)]
        if 0 < prev < d: coords.append(border(side,left,prev,True))
        # Use continuous 16px side texture coordinates despite the inset.
        uvcoords = []
        for co in coords:
            t = left if co == border(side,left,co[2],True) else right
            uvcoords.append(tile_uv(side,t,co[2]))
        face(coords, uvcoords)
        coords = [border(side,left,d),border(side,right,d),border(side,right,d,True),border(side,left,d,True)]
        face(coords, [swatches[palette['rim'][1]]] * 4)
        if i < 7 and d != nxt:
            coords = [border(side,right,d),border(side,right,nxt),border(side,right,nxt,True),border(side,right,d,True)]
            face(coords, [swatches[palette['rim'][1]]] * 4)
face(top, [tile_uv(4,co[0]+.5,co[1]+.5) for co in top])
face(list(reversed(bottom)), [tile_uv(5,(co[0]+.494)/.988,(co[1]+.494)/.988) for co in reversed(bottom)])
block = mesh_obj('ENV_GrassDirt_Block_1m', verts, faces, uvs)
block['dimensions_spec'] = '1.000 x 1.000 x 1.000 m'
block['rim_overhang_m'] = 0.006
block['notes'] = 'Actual stepped rim geometry; no bevels, no subdivision. Origin centered on bottom.'

# Four-ring rectangular blades: broad faces, flat tips, no alpha cards.
gv, gf, gu = [], [], []
height_weights = []
blade_def = [
    (-.18,-.12,.30,.060,-.30),(-.075,-.16,.34,.067,.36),(.045,-.15,.28,.072,-.22),(.155,-.10,.32,.062,.55),
    (-.205,.005,.34,.065,.40),(-.10,-.015,.39,.078,-.10),(.005,-.005,.44,.070,.10),(.12,.015,.37,.075,-.38),(.205,.055,.29,.062,.25),
    (-.15,.13,.27,.067,-.58),(-.045,.12,.36,.077,.32),(.055,.16,.31,.070,-.42),(.15,.15,.26,.067,.48),
    (.0,.06,.405,.058,-.62),
]
for blade_i, (x,y,h,width,angle) in enumerate(blade_def):
    start = len(gv)
    ca,sa = math.cos(angle),math.sin(angle)
    for t in (0.0,0.22,0.65,1.0):
        ww = width * (1 if t < .9 else .72)
        thick = .017 * (1 if t < .9 else .8)
        leanx = .018 * t*t * math.sin(blade_i*1.9)
        leany = .015 * t*t * math.cos(blade_i*1.3)
        for lx,ly in ((-ww/2,-thick/2),(ww/2,-thick/2),(ww/2,thick/2),(-ww/2,thick/2)):
            gv.append((x + lx*ca-ly*sa+leanx, y + lx*sa+ly*ca+leany, h*t))
            height_weights.append(t)
    for ring in range(3):
        for side in range(4):
            a = start+ring*4+side
            b = start+ring*4+(side+1)%4
            gf.append((a,b,b+4,a+4))
            # Shared atlas swatches; one material for the entire opaque tuft.
            code = palette['blade'][min(5, (blade_i%3)+ring)]
            gu.append([swatches[code]] * 4)
    gf.extend([(start+3,start+2,start+1,start),(start+12,start+13,start+14,start+15)])
    gu.extend([[swatches[palette['blade'][0]]]*4,[swatches[palette['blade'][(blade_i%3)+2]]]*4])
grass = mesh_obj('ENV_Grass_Tuft_Hero', gv, gf, gu)
grass.location = (0,0,1)
grass['blade_count'] = len(blade_def)
grass['origin_note'] = 'Local root plane Z=0; placed at world Z=1 on the block.'
grass['wind_loop_seconds'] = 4.0
grass['wind_period_frames'] = 96
grass['wind_tip_amplitude_x_m'] = .018
grass['wind_tip_amplitude_y_m'] = .007
group = grass.vertex_groups.new(name='WIND_HEIGHT_SQUARED')
for i,t in enumerate(height_weights):
    group.add([i], t*t, 'REPLACE')
controller = bpy.data.objects.new('ENV_Wind_Global',None)
wind_col.objects.link(controller)
controller.empty_display_type = 'PLAIN_AXES'
controller.empty_display_size = .13
controller.location = (-.78,0,0)
controller['phase'] = 0.0
controller['phase_formula'] = '2*pi*(frame-1)/96; one shared phase for all future instances'
controller['runtime_note'] = 'Blender preview only. Future shader should use global phase, local height squared, and local height delay.'
phase = controller.driver_add('["phase"]')
phase.driver.expression = '2*pi*(frame-1)/96'
basis = grass.shape_key_add(name='Basis',from_mix=False)
for axis, trig in (('X','Sin'),('X','Cos'),('Y','Sin'),('Y','Cos')):
    key = grass.shape_key_add(name='Wind_'+axis+'_'+trig,from_mix=False)
    key.slider_min = -1
    key.slider_max = 1
    for i,t in enumerate(height_weights):
        # Analytic sine/cosine decomposition includes a soft delay toward the tips.
        lag = -.28*t if axis == 'X' else math.pi/3 - .23*t
        amplitude = (.018 if axis == 'X' else .007)*t*t
        delta = amplitude * (math.cos(lag) if trig == 'Sin' else math.sin(lag))
        key.data[i].co[0 if axis == 'X' else 1] += delta
    drv = key.driver_add('value').driver
    var = drv.variables.new()
    var.name = 'p'
    var.type = 'SINGLE_PROP'
    var.targets[0].id = controller
    var.targets[0].data_path = '["phase"]'
    drv.expression = 'sin(p)' if trig == 'Sin' else 'cos(p)'
grass.data.shape_keys.name = 'ENV_Grass_Wind_Analytic_4s'

floor_mat = bpy.data.materials.new('REVIEW_Neutral_Floor')
floor_mat.use_nodes = True
floor_mat.diffuse_color = rgb('C8C5B9')
floor_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = rgb('C8C5B9')
floor_mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = 1
floor_mesh = bpy.data.meshes.new('REVIEW_Floor_Mesh')
floor_mesh.from_pydata([(-100,-100,-.004),(100,-100,-.004),(100,100,-.004),(-100,100,-.004)],[],[(0,1,2,3)])
floor = bpy.data.objects.new('REVIEW_Floor',floor_mesh)
studio.objects.link(floor)
floor.data.materials.append(floor_mat)
floor.hide_select = True

def track(obj,target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

def camera(name,loc,target,scale):
    data = bpy.data.cameras.new(name)
    data.type='ORTHO'
    data.ortho_scale=scale
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=loc
    track(obj,target)
    return obj

hero=camera('REVIEW_Camera_Hero',(3,-4,3.0),(0,0,.69),2.18)
camera('REVIEW_Camera_Grass_Detail',(2.8,-4,2.4),(0,0,1.21),.90)
camera('REVIEW_Camera_Block_Back',(-3,4,2.7),(0,0,.62),2.05)
scene.camera=hero
for name,loc,power,size in (('REVIEW_Key',(-3,-4,6),400,4.0),('REVIEW_Fill',(4,-1,4),150,4.0),('REVIEW_Rim',(1,4,5),220,3.0)):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.shape='DISK'
    data.size=size
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=loc
    track(obj,(0,0,.7))
for f,name in ((1,'LOOP_START'),(25,'QUARTER'),(49,'HALF'),(73,'THREE_QUARTERS'),(97,'SEAM_MATCHES_FRAME_1')):
    scene.timeline_markers.new(name,frame=f)
scene['review_scope']='Blender study only. No Godot integration or game export.'
scene['review_hint']='Space: play wind 1-96. Numpad0: hero camera. Select grass to inspect shape-key drivers. REVIEW_NOTES text contains full details.'
notes='''GRASS BLOCK + WIND | BLENDER REVIEW v1

Scope: separate study. No production assets overwritten; no Godot files touched.
Block: ENV_GrassDirt_Block_1m, exact 1 x 1 x 1 m, bottom origin, identity transforms.
The rim overhang is 6 mm per edge WITHIN the block bounds. Stepped grass edge reaches
0.75-0.875 m. Geometry stays sharp, with no bevels, subdivision, or alpha surfaces.
Grass: ENV_Grass_Tuft_Hero, 14 broad opaque rectangular blades, height 0.44 m.
Its local root plane is Z=0; review placement is Z=1 on the block.
One shared opaque material and packed 64 x 64 nearest-sampled atlas for both assets.

PLAYBACK: frames 1-96, 24 fps, 4 seconds. Frame 97 is the mathematical duplicate
of frame 1 and is deliberately excluded from playback. Space starts/stops playback.
Global controller: ENV_Wind_Global["phase"] = 2*pi*(frame-1)/96.
Four signed shape keys decompose sine/cosine motion in X and Y. Every blade root is
unchanged. Weight is normalized blade height squared. Tip amplitude is 0.018 m in X,
0.007 m in Y, with a slight height-dependent delay. No random time offsets or jitter.
The WIND_HEIGHT_SQUARED vertex group documents the equivalent deformation mask.

LATER GAME SYNC RECOMMENDATION (DOCUMENTATION ONLY):
Use ONE global time/phase uniform, phase = 2*pi*global_time/4, for all grass instances.
Apply wind in a shared world direction, anchored at local root Z=0. Use local blade
height weight squared and a small height delay, preserving the same global phase.
Uniform-height tuft meshes may use normalized local Y after coordinate conversion;
for these varied-height blades preserve the per-vertex WIND_HEIGHT_SQUARED mask.
Optional seeded amplitude variation can be +/-10%; keep phase identical by default.
Small seeded phase offsets can be added later only if desired, never independent clocks.
This Blender shape-key loop is a preview recipe; no runtime rig/shader is installed.

REVIEW: choose camera Hero for proportions, Grass_Detail for silhouette/sway, or
Block_Back for opposite sides. Studio collection can be hidden while inspecting.
Human review still needed: palette, stepped rim, tuft density/scale, and sway strength.
'''
text=bpy.data.texts.new('REVIEW_NOTES')
text.write(notes)
(OUT/'REVIEW_NOTES.txt').write_text(notes,encoding='utf-8')
for obj in scene.objects:
    obj.select_set(False)
grass.select_set(True)
bpy.context.view_layer.objects.active=grass
scene.frame_set(1)
bpy.context.view_layer.update()
for workspace in bpy.data.workspaces:
    for screen in (workspace.screens if hasattr(workspace,'screens') else []):
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.overlay.show_overlays=False
                area.spaces.active.shading.type='MATERIAL'
                area.spaces.active.shading.use_scene_world=False
                area.spaces.active.shading.use_scene_lights=False
                area.spaces.active.clip_end=200
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.shading.type='MATERIAL'
scene.render.filepath=str(OUT/'preview_hero.png')
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND),check_existing=False)
summary={'blend':str(BLEND),'block_dimensions':list(block.dimensions),'grass_rest_dimensions':list(grass.dimensions),'asset_objects':[block.name,grass.name,controller.name],'version':bpy.app.version_string}
(OUT/'build_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
bpy.ops.render.render(write_still=True)
print('STUDY_CREATED '+json.dumps(summary))
