"""User reference pistol: sand frame, graphite slide, square recessed muzzle.

Static stylized game prop. +Y forward, +Z up, RightHandGrip origin.
Builds only this distinct Pending source; register through the existing library.
"""
import argparse
import bmesh
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
TARGET = OUT/'Pistol_Sand_Block_V1.blend'
parser = argparse.ArgumentParser()
parser.add_argument('--rebuild',action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
assert args.rebuild or not TARGET.exists(), 'Preserve existing source before explicitly rebuilding'
bpy.ops.wm.read_factory_settings(use_empty=True)
s = bpy.context.scene
s.name = 'Pistol Sand Block V1 — Reference Study'
s.unit_settings.system = 'METRIC'
c = bpy.data.collections.new('WEAPON_EXPORT')
s.collection.children.link(c)
root = bpy.data.objects.new('Pistol_Sand_Block_V1',None)
c.objects.link(root)
root['review_status'] = 'Pending'
root['forward'] = '+Y'
root['origin'] = 'RightHandGrip'
root['reference'] = 'reference.png — user supplied 2026-10-19'
atlas = bpy.data.images.load(str(OUT/'pistol_sand_atlas_256.png'),check_existing=False)
atlas.name = 'Pistol_Sand_Atlas_256'
atlas.pack()
mat = bpy.data.materials.new('Pistol_Sand_Graphite_Atlas')
mat.use_nodes = True
bs = mat.node_tree.nodes.get('Principled BSDF')
bs.inputs['Metallic'].default_value = .12
bs.inputs['Roughness'].default_value = .68
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = atlas
tex.interpolation = 'Closest'
mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
parts = {'Frame':[],'Slide':[],'Magazine':[]}
scale = Vector((1,.98,.95))


def part(name,vertices,faces,tile=0,bevel=0,group='Frame'):
    me = bpy.data.meshes.new(name)
    me.from_pydata(vertices,[],faces)
    me.update()
    ob = bpy.data.objects.new(name,me)
    c.objects.link(ob)
    me.materials.append(mat)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(me)
    bm.free()
    if bevel:
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        mod = ob.modifiers.new('Block edge chamfer','BEVEL')
        mod.width,mod.segments = bevel,1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    uv = me.uv_layers.new(name='PistolAtlasUV')
    lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
    spans = [max(v.co[i] for v in me.vertices)-lo[i] for i in range(3)]
    density = min(8.0,.84/max(spans))
    for face in me.polygons:
        drop = max(range(3),key=lambda i:abs(face.normal[i]))
        axes = [i for i in range(3) if i != drop]
        for li in face.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u,v = [.08+(co[a]-lo[a])*density for a in axes]
            uv.data[li].uv = ((tile%4+u)/4,(tile//4+v)/4)
        face.use_smooth = False
    vg = ob.vertex_groups.new(name=name)
    vg.add(list(range(len(me.vertices))),1,'REPLACE')
    parts[group].append(ob)
    return ob


def profile(name,yz,width,tile=0,bevel=0,group='Frame',x=0):
    n = len(yz)
    vs = [(x+xx,y,z) for xx in [-width/2,width/2] for y,z in yz]
    fs = [tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return part(name,vs,fs,tile,bevel,group)


def box(name,center,dims,tile=0,bevel=0,group='Frame'):
    x,y,z = center
    w,l,h = dims
    return profile(name,[(y-l/2,z-h/2),(y+l/2,z-h/2),
                         (y+l/2,z+h/2),(y-l/2,z+h/2)],w,tile,bevel,group,x)


def octagon(w,h,ch):
    return [(-w/2+ch,-h/2),(w/2-ch,-h/2),(w/2,-h/2+ch),(w/2,h/2-ch),
            (w/2-ch,h/2),(-w/2+ch,h/2),(-w/2,h/2-ch),(-w/2,-h/2+ch)]


def housing(name,rings,z,tile=4,hole=None,through=False,group='Slide'):
    # Cross sections along +Y; optional closed deep recess or open ring sleeve.
    vs = [(x,y,z+zz) for y,w,h,ch in rings for x,zz in octagon(w,h,ch)]
    fs = [] if through else [tuple(reversed(range(8)))]
    for j in range(len(rings)-1):
        fs += [(j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i) for i in range(8)]
    last = (len(rings)-1)*8
    if hole:
        w,h,depth = hole
        start = len(vs)
        for y in [rings[-1][0],rings[0][0] if through else rings[-1][0]-depth]:
            vs += [(x,y,z+zz) for x,zz in octagon(w,h,.0008)]
        for i in range(8):
            k = (i+1)%8
            fs += [(last+i,last+k,start+k,start+i),(start+i,start+k,start+8+k,start+8+i)]
        if through:
            fs += [(i,start+8+i,start+8+(i+1)%8,(i+1)%8) for i in range(8)]
        else:
            fs.append(tuple(start+8+i for i in range(8)))
    else:
        fs.append(tuple(last+i for i in range(8)))
    ob = part(name,vs,fs,tile,group=group)
    if hole and not through:
        for li in ob.data.polygons[-1].loop_indices:
            ob.data.uv_layers.active.data[li].uv = (.875,.875)
    return ob


def yz_ring(name,outer,inner,width,tile=0,bevel=0):
    n = len(outer)
    assert n == len(inner)
    vs = [(x,y,z) for x in [-width/2,width/2] for loop in [outer,inner] for y,z in loop]
    fs = []
    for i in range(n):
        j = (i+1)%n
        fs += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
               (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
    return part(name,vs,fs,tile,bevel)


# Sand frame and short stepped accessory rail, with a graphite slide/frame seam.
profile('Sand_Frame',[(-.059,.077),(.201,.077),(.201,.054),(.111,.054),
                       (.106,.050),(.040,.048),(.027,.034),(.016,.034),
                       (.010,.044),(-.043,.045),(-.043,.052),(-.059,.056)],
        .044,0,.0008)
box('Frame_Top_Bevel_Trim',(0,.072,.077),(.045,.260,.004),1,.0005)
box('Slide_Guide_Rail',(0,.083,.080),(.034,.248,.004),6)
profile('Front_Dustcover',[(.112,.061),(.201,.061),(.201,.045),(.129,.045),(.112,.048)],
        .042,0,.0007)
for side in [-1,1]:
    box('Dustcover_Long_Recess',(side*.0214,.155,.055),(.0017,.083,.0034),2)
    box('Dustcover_Lower_Step',(side*.019,.154,.046),(.004,.067,.003),1)
for y in [.130,.166]:
    box('Under_Rail_Lug',(0,y,.044),(.033,.016,.004),2,.0004)
box('Rear_Frame_Step',(0,-.036,.049),(.035,.024,.008),2,.0005)

# Hollow, raked tan grip shell. Inner walls remain when magazine is removed.
sections = [(.050,.0035,.035,.063),(-.046,-.031,.035,.062)]
vs = []
for z,y,w,l in sections:
    for section in [octagon(w,l,.0018),octagon(.024,.040,.001)]:
        vs += [(x,y+yy,z) for x,yy in section]
fs = []
for i in range(8):
    j = (i+1)%8
    fs += [(i,j,j+16,i+16),(i+8,i+24,j+24,j+8),
           (i,i+8,j+8,j),(i+16,j+16,j+24,i+24)]
part('Raked_Grip_Shell',vs,fs,0)
for side in [-1,1]:
    profile('Graphite_Grip_Panel',[(-.027,.042),(.018,.039),(-.006,-.043),(-.061,-.030)],
            .0038,4,.0010,x=side*.0190)
    profile('Grip_Front_Facet',[(.008,.039),(.018,.039),(-.006,-.043),(-.016,-.041)],
            .0012,5,0,x=side*.0213)
    profile('Grip_Rear_Edge',[(-.029,.040),(-.023,.040),(-.055,-.031),(-.063,-.029)],
            .0012,6,0,x=side*.0213)
for z in [.027,.003,-.021]:
    z1,z2 = z+.010,z-.010
    front1,front2 = .035+(z1-.050)*.365,.035+(z2-.050)*.365
    profile('Grip_Sand_Segment',[(front1-.007,z1),(front1+.0007,z1),
                                 (front2+.0007,z2),(front2-.007,z2)],.036,1,.0003)

# A real angular guard opening, with a dark, visibly separated trigger.
yz_ring('Trigger_Guard',[(.032,.051),(.113,.051),(.113,.010),
                         (.048,.010),(.034,.017),(.029,.029)],
        [(.044,.043),(.101,.043),(.101,.021),(.050,.021),(.044,.025),(.041,.032)],
        .030,0,.0007)
box('Guard_Front_Step',(0,.108,.026),(.033,.012,.024),1,.0004)
profile('Trigger',[(.054,.051),(.069,.051),(.068,.035),(.075,.029),
                   (.071,.022),(.059,.024),(.053,.034)],.017,6,.0005)
for side in [-1,1]:
    box('Slide_Release',(side*.024,-.001,.065),(.006,.015,.012),4,.0005)
    box('Frame_Pin_Block',(side*.0237,.055,.058),(.0037,.013,.011),4,.0004)
    box('Frame_Pin_Center',(side*.0257,.055,.058),(.0007,.003,.003),7)
    box('Magazine_Release',(side*.023,.013,.035),(.005,.012,.013),4,.0005)
    box('Magazine_Release_Pin',(side*.0258,.013,.035),(.001,.003,.004),7)

# Detachable magazine and broad black floorplate under the open grip well.
profile('Magazine_Insert',[(-.015,.053),(.024,.053),(-.016,-.051),(-.055,-.047)],
        .022,6,.0005,'Magazine')
profile('Magazine_Floorplate',[(-.066,-.046),(-.002,-.053),(-.004,-.061),(-.068,-.055)],
        .039,8,.0005,'Magazine')

# Chunky rear slide and true wraparound serrations, leaving narrow recessed gaps.
housing('Slide_Rear',[(-.047,.040,.033,.003),(-.043,.043,.036,.0035),
                       (.052,.043,.036,.0035),(.057,.041,.034,.002)],.096,4)
for i in range(6):
    y = -.028+i*.0078
    housing('Rear_Serration_%02d'%i,[(y,.046,.037,.0035),(y+.0047,.046,.037,.0035)],
            .096,5 if i%2 else 4)
box('Rear_Slide_Backplate',(0,-.0475,.096),(.027,.002,.026),6,.0005,'Slide')

# Open lowered top chamber in the reference; the barrel hood is visibly inset.
box('Slide_Lower_Chamber_Web',(0,.080,.085),(.041,.054,.014),4,.0005,'Slide')
box('Chamber_Far_Lip',(-.019,.080,.102),(.004,.050,.020),5,.0004,'Slide')
box('Chamber_Near_Lip',(.019,.080,.091),(.004,.050,.005),6,0,'Slide')
box('Barrel_Hood',(0,.080,.099),(.027,.052,.014),5,.0007)
box('Barrel_Hood_Top',(0,.080,.106),(.027,.050,.002),9,.0003)

# Front slide, inset barrel and warm chamfered square muzzle. The cap is a sleeve.
housing('Slide_Front',[(.103,.043,.036,.0035),(.206,.043,.036,.0035),
                       (.213,.041,.035,.002)],.096,4,hole=(.023,.025,.120))
housing('Fixed_Barrel',[(.105,.027,.028,.003),(.211,.027,.028,.003)],
        .096,6,hole=(.018,.020,.119),group='Frame')
housing('Square_Muzzle_Trim',[(.209,.046,.039,.0025),(.217,.045,.038,.002)],
        .096,9,hole=(.023,.025,.008),through=True)
box('Lower_Recoil_Plug',(0,.208,.066),(.027,.015,.018),6,.0008)
for side in [-1,1]:
    box('Slide_Front_Side_Accent',(side*.0217,.201,.092),(.001,.009,.023),6,0,'Slide')

# Open U rear sight and single square front post, both fixed to the slide.
box('Rear_Sight_Base',(0,-.009,.115),(.033,.020,.004),7,.0004,'Slide')
for x in [-.010,.010]:
    box('Rear_Sight_Ear',(x,-.009,.123),(.011,.016,.014),4,.0005,'Slide')
box('Front_Sight_Base',(0,.193,.115),(.019,.019,.003),6,.0004,'Slide')
box('Front_Sight_Post',(0,.193,.123),(.011,.013,.014),7,.0005,'Slide')


def scaled(pos):
    return tuple(Vector(pos)*scale)


def join(name,group,pivot):
    objs = parts[group]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        for v in ob.data.vertices:
            v.co *= scale
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = name
    pivot = Vector(scaled(pivot))
    for v in ob.data.vertices:
        v.co -= pivot
    ob.parent = root
    ob.location = pivot
    return ob


frame = join('Pistol_Sand_Frame','Frame',(0,0,0))
slide = join('Pistol_Sand_Slide','Slide',(0,-.047,.096))
magazine = join('Pistol_Sand_Magazine','Magazine',(0,.004,.050))
slide['role'] = 'Independent rigid slide; no animation authored'
magazine['role'] = 'Independent rigid magazine in an open grip shell'
markers = {'RightHandGrip':(0,0,0),'LeftHandGuide':(0,.023,.020),
           'Muzzle':(0,.218,.096),'AimReference':(0,.193,.123),
           'RecoilPivot':(0,0,0),'HolsterAttach':(0,0,0),
           'Grip_Point':(0,0,0),'Support_Hand_Point':(0,.023,.020),
           'Muzzle_Point':(0,.218,.096),'MagazineFeed':(0,.004,.050)}
markers = {k:scaled(v) for k,v in markers.items()}
for name,pos in markers.items():
    ob = bpy.data.objects.new(name,None)
    c.objects.link(ob)
    ob.parent = root
    ob.location = pos
    ob.empty_display_type = 'ARROWS'
    ob.empty_display_size = .010
    root[name] = list(pos)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for ob in c.all_objects:
    ob.select_set(True)
bpy.context.view_layer.objects.active = frame
bpy.ops.export_scene.gltf(filepath=str(OUT/'Pistol_Sand_Block_V1.glb'),export_format='GLB',
                          use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
meshes = [frame,slide,magazine]
points = [ob.matrix_world@v.co for ob in meshes for v in ob.data.vertices]
report = {'status':'Pending','meshes':3,'materials':1,'atlas_size':[256,256],
          'reference':'reference.png','forward':'+Y','markers':markers,
          'dimensions_m':[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)],
          'topology':{}}
for ob in meshes:
    ob.data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    info = {'triangles':len(ob.data.loop_triangles),
            'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
            'loose_vertices':sum(not v.link_faces for v in bm.verts)}
    bm.free()
    assert not info['nonmanifold_edges'] and not info['loose_vertices'],(ob.name,info)
    report['topology'][ob.name] = info
report['triangles'] = sum(v['triangles'] for v in report['topology'].values())
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
s['review_status'] = 'Pending'
s['asset_report'] = json.dumps(report)

# Read-only presentation outside WEAPON_EXPORT; never imported to the library.
studio = bpy.data.collections.new('SOURCE_REVIEW_STUDIO')
s.collection.children.link(studio)
world = bpy.data.worlds.new('Pistol Graphite Studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.075,.080,.092,1)
world.node_tree.nodes['Background'].inputs[1].default_value = .45
s.world = world
fm = bpy.data.materials.new('Pistol Review Floor')
fm.use_nodes = True
fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.006,.007,.009,1)
fm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .88
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,min(p.z for p in points)-.0005))
floor = bpy.context.object
for col in list(floor.users_collection):
    col.objects.unlink(floor)
studio.objects.link(floor)
floor.name = 'Pistol_Review_Ground'
floor.data.materials.append(fm)
focus = Vector((0,.068,.030))
for name,loc,power,size,color in [
    ('Pistol Key',(.5,-.20,.78),35,.75,(1,.91,.79)),
    ('Pistol Fill',(.45,.60,.35),20,.60,(.76,.85,1)),
    ('Pistol Rim',(-.42,-.10,.62),50,.70,(1,.86,.69)),
]:
    data = bpy.data.lights.new(name,'AREA')
    data.energy,data.size,data.color = power,size,color
    ob = bpy.data.objects.new(name,data)
    studio.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (focus-ob.location).to_track_quat('-Z','Y').to_euler()
cam = bpy.data.objects.new('Pistol_Review_Camera',bpy.data.cameras.new('Pistol_Review_Camera'))
studio.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = .355
cam.location = focus+Vector((.50,.24,.15))
cam.rotation_euler = (focus-cam.location).to_track_quat('-Z','Y').to_euler()
s.camera = cam
s.render.engine = 'CYCLES'
s.cycles.samples = 32
s.cycles.use_denoising = True
s.render.threads_mode = 'FIXED'
s.render.threads = 8
s.render.resolution_x,s.render.resolution_y = 1500,1100
s.render.resolution_percentage = 100
s.render.image_settings.file_format = 'PNG'
s.view_settings.view_transform = 'AgX'
bpy.ops.object.select_all(action='DESELECT')
frame.select_set(True)
bpy.context.view_layer.objects.active = frame
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            sp = area.spaces.active
            sp.shading.type = 'MATERIAL'
            sp.overlay.show_overlays = False
            sp.region_3d.view_rotation = cam.rotation_euler.to_quaternion()
            sp.region_3d.view_location = focus
            sp.region_3d.view_distance = .48
            sp.region_3d.view_perspective = 'ORTHO'
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
review = OUT/'review'
review.mkdir(exist_ok=True)
for name,direction,ortho in [('three_quarter',(.50,.24,.15),.355),('side',(.65,0,.012),.355),
                              ('top',(.0001,0,.65),.355),('front',(0,.65,.008),.295)]:
    cam.location = focus+Vector(direction)
    cam.rotation_euler = (focus-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale = ortho
    s.render.filepath = str(review/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('PISTOL_SAND_BLOCK_BUILT',json.dumps(report),flush=True)
