"""Author the user's sand/graphite tactical shotgun as a separate game prop.

+Y forward, +Z up, grip-centered. External stylized geometry only.
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

OUT=Path(__file__).resolve().parent
TARGET=OUT/'Shotgun_Sand_Block_V1.blend'
parser=argparse.ArgumentParser()
parser.add_argument('--rebuild',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
assert args.rebuild or not TARGET.exists(),'Explicit --rebuild required for this Pending source'
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene
s.name='Shotgun Sand Block V1 — Tactical Reference'
s.unit_settings.system='METRIC'
c=bpy.data.collections.new('WEAPON_EXPORT');s.collection.children.link(c)
root=bpy.data.objects.new('Shotgun_Sand_Block_V1',None);c.objects.link(root)
root['review_status']='Pending';root['forward']='+Y';root['origin']='RightHandGrip'
root['reference']='reference.png — user supplied 2026-10-19'
atlas=bpy.data.images.load(str(OUT/'shotgun_palette_source_256.png'),check_existing=False)
atlas.name='Shotgun_Sand_Atlas_256'
pixels=list(atlas.pixels[:])
rng=random.Random(2026101908)
# Preserve the accepted sand and high-contrast graphite; use spare warm swatches
# for red shell bodies, brass caps and red shadows within the same atlas.
for tile,rgb in {12:(178,35,22),13:(208,158,49),14:(113,25,18)}.items():
    shades=[[1.0]*64 for _ in range(64)]
    for _ in range(85):
        x,y=rng.randrange(2,57),rng.randrange(2,57)
        w,h=rng.choice([3,5,7]),rng.choice([3,4,6])
        shade=rng.choice([.90,.96,1.04,1.10])
        for yy in range(y,min(62,y+h)):
            for xx in range(x,min(62,x+w)):shades[yy][xx]=shade
    for y in range(64):
        for x in range(64):
            i=(((tile//4)*64+y)*256+(tile%4)*64+x)*4
            vals=[min(1,v/255*shades[y][x]) for v in rgb]
            pixels[i:i+4]=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals]+[1]
atlas.pixels.foreach_set(pixels)
atlas.filepath_raw=str(OUT/'shotgun_sand_atlas_256.png')
atlas.file_format='PNG';atlas.save();atlas.pack()
mat=bpy.data.materials.new('Shotgun_Sand_Graphite_Atlas');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF')
bs.inputs['Metallic'].default_value=.14;bs.inputs['Roughness'].default_value=.70
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest'
mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
parts={'Frame':[],'Pump':[],'Magazine':[],'Shells':[]}
scale=Vector((1,1,1))

def part(name,vertices,faces,tile=0,bevel=0,group='Frame',face_tiles=None):
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
        face_tile = face_tiles[face.index] if face_tiles else tile
        drop = max(range(3),key=lambda i:abs(face.normal[i]))
        axes = [i for i in range(3) if i != drop]
        for li in face.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u,v = [.08+(co[a]-lo[a])*density for a in axes]
            uv.data[li].uv = ((face_tile%4+u)/4,(face_tile//4+v)/4)
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

# Open stepped stock: upper beam, rear post and a stair-shaped lower brace.
profile('Stock_Sand_Upper_Beam',[(-.395,.134),(-.214,.124),(-.225,.092),(-.392,.100)],
        .058,0,.0012)
profile('Stock_Rear_Post',[(-.395,.104),(-.364,.102),(-.364,-.024),(-.395,-.024)],
        .050,0,.0008)
profile('Stock_Stepped_Brace',[(-.364,.026),(-.285,.084),(-.247,.084),
        (-.247,.066),(-.271,.066),(-.271,.045),(-.295,.045),(-.295,.024),
        (-.319,.024),(-.319,.003),(-.344,.003),(-.344,-.016),(-.364,-.016)],.050,2,.0006)
box('Stock_Front_Web',(0,-.239,.094),(.052,.042,.023),2,.0006)
housing('Stock_Graphite_Pad',[(-.418,.059,.168,.003),(-.412,.064,.175,.003),
        (-.392,.064,.175,.003)],.0535,6,group='Frame')
profile('Stock_Neck',[(-.232,.124),(-.155,.124),(-.155,.135),(-.115,.135),
        (-.105,.102),(-.121,.069),(-.195,.080),(-.212,.092)],.052,4,.0012)
box('Stock_Neck_Joint',(0,-.159,.106),(.056,.017,.059),6,.0007)

# Receiver with genuinely inset side ports under its overhanging roof.
profile('Receiver_Lower',[(-.135,.102),(-.125,.107),(.145,.107),(.158,.094),
        (.158,.050),(-.113,.048),(-.135,.062)],.060,4,.0013)
box('Receiver_Upper_Core',(0,.012,.114),(.050,.275,.023),6,.0007)
box('Receiver_Roof',(0,.012,.128),(.060,.275,.008),5,.0008)
for side in [-1,1]:
    box('Receiver_Rear_Sidewall',(side*.0285,-.0935,.115),(.006,.077,.026),4,.0006)
    box('Receiver_Front_Sidewall',(side*.0285,.1275,.115),(.006,.045,.026),4,.0006)
    box('Port_Lower_Lip',(side*.029,.023,.105),(.005,.158,.006),5,.0003)
    box('Inset_Port_Bolt',(side*.0258,.015,.1135),(.002,.115,.011),7,.0004)
    box('Receiver_Control',(side*.032,-.095,.070),(.005,.017,.006),7,.0004)
    box('Receiver_Control_Pin',(side*.0348,-.095,.070),(.001,.004,.004),8)
    for y in [-.115,.141]:
        box('Receiver_Square_Pin',(side*.0305,y,.061),(.0025,.005,.005),7,.0003)

# Tan raked grip, dark backstrap and broad black heel.
grip_yz=[(-.094,.065),(-.036,.052),(-.074,-.078),(-.137,-.061)]
profile('Grip_Dark_Shell',grip_yz,.043,4,.0010)
for side in [-1,1]:
    profile('Grip_Sand_Panel',[(-.089,.054),(-.044,.047),(-.080,-.069),(-.129,-.056)],
            .002,0,.0007,x=side*.022)
profile('Grip_Sand_Frontstrap',[(-.049,.050),(-.036,.052),(-.074,-.078),(-.084,-.075)],
        .043,1,.0006)
profile('Grip_Graphite_Heel',[(-.143,-.060),(-.072,-.078),(-.077,-.094),(-.148,-.076)],
        .050,6,.0009)
yz_ring('Angular_Trigger_Guard',[(-.044,.055),(.064,.055),(.058,.008),
        (-.006,.008),(-.038,.024),(-.048,.036)],
        [(-.030,.046),(.048,.046),(.042,.020),(-.002,.020),(-.025,.030),(-.033,.037)],
        .029,6,.0008)
profile('Stepped_Trigger',[(-.002,.050),(.009,.050),(.006,.032),(.014,.025),
        (.009,.020),(-.004,.024),(-.008,.035)],.013,8,.0005)

# Compact detachable box matching the short block below the reference receiver.
profile('Magazine_Stub',[(.064,.057),(.144,.057),(.141,.024),(.065,.027)],
        .053,4,.0008,'Magazine')
box('Magazine_Baseplate',(0,.103,.024),(.058,.083,.006),6,.0006,'Magazine')
for side in [-1,1]:
    box('Magazine_Side_Inset',(side*.0268,.103,.040),(.001,.058,.012),6,0,'Magazine')

# Long upper barrel with an open warm graphite crown and a deep square bore.
barrel=housing('Main_Barrel',[(.143,.047,.042,.005),(.173,.041,.038,.004),
        (.603,.041,.038,.004),(.628,.039,.037,.004)],.108,4,
        hole=(.024,.025,.478),group='Frame')
crown=housing('Muzzle_Crown',[(.605,.047,.044,.004),(.632,.047,.044,.004),
        (.640,.044,.042,.003)],.108,7,hole=(.026,.027,.035),through=True,group='Frame')
# Recess both sleeves together so the underlying barrel cannot fill the crown's
# side window. Keep the floor outside the bore and map it to the dark swatch.
for side in [-1,1]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=(side*.0235,.615,.110))
    cutter=bpy.context.object;cutter.dimensions=(.008,.014,.011)
    cutter.data.materials.append(mat)
    for layer in list(cutter.data.uv_layers):cutter.data.uv_layers.remove(layer)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for ob in [barrel,crown]:
        bpy.context.view_layer.objects.active=ob
        mod=ob.modifiers.new('Recessed side window','BOOLEAN')
        mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
for ob,tile in [(barrel,4),(crown,7)]:
    me=ob.data;me.update();uv=me.uv_layers.active
    lo=[min(v.co[i] for v in me.vertices) for i in range(3)]
    spans=[max(v.co[i] for v in me.vertices)-lo[i] for i in range(3)]
    density=min(8.0,.84/max(spans))
    for face in me.polygons:
        drop=max(range(3),key=lambda i:abs(face.normal[i]))
        axes=[i for i in range(3) if i!=drop]
        inset=(.607<face.center.y<.623 and .104<face.center.z<.116
               and abs(abs(face.center.x)-.0195)<.00005)
        face_tile=15 if inset else tile
        for li in face.loop_indices:
            co=me.vertices[me.loops[li].vertex_index].co
            u,v=[.08+(co[a]-lo[a])*density for a in axes]
            uv.data[li].uv=((face_tile%4+u)/4,(face_tile//4+v)/4)

# Under-barrel tube and its four chunky octagonal forward collars.
# Raised as one assembly after the user's spacing review; the narrow clearance
# remains visible between the collars and the underside of the upper barrel.
lower_tube_z=.066
housing('Lower_Tube',[(.143,.034,.034,.007),(.608,.034,.034,.007),
        (.620,.032,.032,.006)],lower_tube_z,6,hole=(.018,.018,.012),group='Frame')
for i,y in enumerate([.428,.458,.488,.518]):
    housing('Tube_Collar_%02d'%i,[(y,.042,.043,.007),(y+.019,.042,.043,.007)],
            lower_tube_z,4 if i%2 else 5,group='Frame')
box('Barrel_Tube_Bridge',(0,.410,.0875),(.044,.017,.015),6,.0008)
housing('Foreend_Front_Collar',[(.399,.069,.078,.006),(.420,.066,.078,.006)],
        .061,6,group='Frame')

# Raised tan ribs leave five real, visibly deeper side grooves in the pump.
housing('Pump_Recessed_Core',[(.205,.056,.077,.005),(.216,.064,.080,.006),
        (.394,.064,.080,.006),(.405,.058,.077,.005)],.063,2,group='Pump')
box('Pump_Upper_Tan_Trim',(0,.303,.095),(.078,.197,.014),1,.0010,'Pump')
profile('Pump_Lower_Continuous_Trim',[(.206,.036),(.404,.036),(.404,.025),
        (.396,.019),(.216,.019),(.206,.026)],.072,2,.0006,'Pump')
for side in [-1,1]:
    for i,y in enumerate([.225,.259,.293,.327,.361,.395]):
        profile('Pump_Rib_%02d'%i,[(y-.011,.087),(y+.011,.087),(y+.011,.029),
                (y+.006,.022),(y-.011,.028)],.007,0,.0006,'Pump',x=side*.0355)

# Dark upper fore-end and continuous Picatinny-style block rail.
box('Foreend_Upper_Shroud',(0,.272,.128),(.060,.267,.028),4,.0010)
box('Receiver_Rail_Riser',(0,.012,.138),(.048,.268,.014),6,.0006)
box('Top_Rail_Base',(0,.142,.145),(.052,.530,.008),6,.0005)
for i in range(23):
    y=-.116+i*.0231
    box('Top_Rail_Tooth_%02d'%i,(0,y,.153),(.056,.012,.009),7 if i%5==0 else 4,.0005)
box('Rear_Sight_Base',(0,-.071,.160),(.039,.024,.006),6,.0004)
for x in [-.012,.012]:
    box('Rear_Sight_Ear',(x,-.071,.166),(.011,.016,.014),4,.0004)
box('Front_Sight_Base',(0,.613,.133),(.027,.018,.005),6,.0004)
box('Front_Sight_Post',(0,.613,.140),(.012,.011,.012),7,.0004)

# One-sided four-shell saddle. Red shells remain a distinct rigid mesh.
box('Shell_Saddle_Backplate',(.0365,.068,.082),(.009,.122,.074),6,.0009)
box('Shell_Saddle_Bottom_Rail',(.045,.068,.054),(.014,.127,.005),8,.0004)
for i,y in enumerate([.024,.052,.080,.108]):
    box('Shell_Red_%02d'%i,(.048,y,.082),(.018,.020,.052),12,.0012,'Shells')
    box('Shell_Brass_Cap_%02d'%i,(.048,y,.112),(.020,.022,.012),13,.0008,'Shells')
    box('Shell_Cap_Primer_%02d'%i,(.048,y,.1181),(.006,.006,.0005),9,0,'Shells')
    box('Shell_Clamp_%02d'%i,(.060,y,.079),(.012,.024,.022),6,.0007)


def join(name,group,pivot):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts[group]:ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[group][0]
    bpy.ops.object.join()
    ob=bpy.context.object;ob.name=name
    pivot=Vector(pivot)
    for v in ob.data.vertices:v.co-=pivot
    ob.parent=root;ob.location=pivot
    return ob

frame=join('Shotgun_Sand_Frame','Frame',(0,0,0))
pump=join('Shotgun_Sand_Pump','Pump',(0,.303,.063))
mag=join('Shotgun_Sand_Magazine','Magazine',(0,.103,.052))
shells=join('Shotgun_Sand_Shells','Shells',(.048,.068,.082))
pump['role']='Independent static fore-end; no animation authored'
mag['role']='Compact detachable box from reference silhouette'
shells['role']='Four decorative red/brass shell props in the side saddle'
markers={'RightHandGrip':(0,0,0),'LeftHandGuide':(0,.303,.035),
         'Muzzle':(0,.641,.108),'AimReference':(0,.613,.146),
         'RecoilPivot':(0,0,0),'HolsterAttach':(0,0,0),'Grip_Point':(0,0,0),
         'Support_Hand_Point':(0,.303,.035),'Muzzle_Point':(0,.641,.108),
         'MagazineFeed':(0,.103,.052)}
for name,pos in markers.items():
    ob=bpy.data.objects.new(name,None);c.objects.link(ob);ob.parent=root;ob.location=pos
    ob.empty_display_type='ARROWS';ob.empty_display_size=.020;root[name]=list(pos)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for ob in c.all_objects:ob.select_set(True)
bpy.context.view_layer.objects.active=frame
bpy.ops.export_scene.gltf(filepath=str(OUT/'Shotgun_Sand_Block_V1.glb'),export_format='GLB',
        use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
meshes=[frame,pump,mag,shells]
points=[ob.matrix_world@v.co for ob in meshes for v in ob.data.vertices]
report={'status':'Pending','meshes':4,'materials':1,'atlas_size':[256,256],
        'reference':'reference.png','forward':'+Y','markers':markers,
        'dimensions_m':[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)],
        'shells':4,'topology':{}}
for ob in meshes:
    ob.data.calc_loop_triangles()
    bm=bmesh.new();bm.from_mesh(ob.data)
    info={'triangles':len(ob.data.loop_triangles),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
          'loose_vertices':sum(not v.link_faces for v in bm.verts)}
    bm.free()
    assert not info['nonmanifold_edges'] and not info['loose_vertices'],(ob.name,info)
    report['topology'][ob.name]=info
report['triangles']=sum(v['triangles'] for v in report['topology'].values())
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
s['review_status']='Pending';s['asset_report']=json.dumps(report)

# Presentation collection stays outside the export and central weapon import.
studio=bpy.data.collections.new('SOURCE_REVIEW_STUDIO');s.collection.children.link(studio)
world=bpy.data.worlds.new('Shotgun Graphite Studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.028,.033,.044,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.35;s.world=world
fm=bpy.data.materials.new('Shotgun Review Floor');fm.use_nodes=True
fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.003,.004,.006,1)
fm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,min(p.z for p in points)-.002))
floor=bpy.context.object
for col in list(floor.users_collection):col.objects.unlink(floor)
studio.objects.link(floor);floor.name='Shotgun_Review_Ground';floor.data.materials.append(fm)
focus=Vector((.008,.105,.045))
for name,loc,power,size,color in [
    ('Shotgun Key',(1.4,-.8,2.2),360,2.0,(1,.91,.79)),
    ('Shotgun Fill',(1.3,1.9,.8),160,1.6,(.76,.85,1)),
    ('Shotgun Rim',(-1.4,-.4,1.8),460,1.7,(1,.86,.69))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.color=color
    ob=bpy.data.objects.new(name,data);studio.objects.link(ob);ob.location=loc
    ob.rotation_euler=(focus-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Shotgun_Review_Camera',bpy.data.cameras.new('Shotgun_Review_Camera'))
studio.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=1.23
cam.location=focus+Vector((1.50,.72,.49))
cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True
s.render.threads_mode='FIXED';s.render.threads=8
s.render.resolution_x,s.render.resolution_y=1700,1050;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX'
bpy.ops.object.select_all(action='DESELECT');frame.select_set(True);bpy.context.view_layer.objects.active=frame
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
            sp.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            sp.region_3d.view_location=focus;sp.region_3d.view_distance=1.48;sp.region_3d.view_perspective='ORTHO'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
review=OUT/'review';review.mkdir(exist_ok=True)
for name,direction,ortho in [('three_quarter',(1.50,.72,.49),1.23),('side',(1.5,0,.015),1.23),
                           ('opposite',(-1.5,0,.015),1.23),('top',(0,0,1.5),1.23),
                           ('front',(0,1.5,.010),.56)]:
    cam.location=focus+Vector(direction)
    cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
    if name=='top':cam.rotation_euler=(0,0,math.pi/2)
    cam.data.ortho_scale=ortho;s.render.filepath=str(review/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('SHOTGUN_SAND_BLOCK_BUILT',json.dumps(report),flush=True)
