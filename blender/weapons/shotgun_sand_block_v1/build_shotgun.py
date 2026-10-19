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
root['reference']='reference_refined.png — latest user multi-view reference 2026-10-19'
grip_origin=Vector((0,-.133,.006))
root['authoring_origin']=list(grip_origin)
atlas=bpy.data.images.load(str(OUT/'shotgun_palette_source_256.png'),check_existing=False)
atlas.name='Shotgun_Sand_Atlas_256'
pixels=list(atlas.pixels[:])
rng=random.Random(2026101908)
# Preserve the accepted sand and high-contrast graphite; use spare warm swatches
# for red shell bodies, brass caps and red shadows within the same atlas.
for tile,rgb in {12:(178,35,22),13:(221,196,69),14:(113,25,18)}.items():
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


def housing(name,rings,z,tile=4,hole=None,through=False,group='Frame',hole_chamfer=.0008,hole_z=None):
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
            vs += [(x,y,(z if hole_z is None else hole_z)+zz) for x,zz in octagon(w,h,hole_chamfer)]
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

# The reference has a thick upper stock beam and stepped inner ledges, rather
# than a large triangular opening. Its lower, thicker pad sets the silhouette.
profile('Stock_Sand_Upper_Beam',[(-.381,.120),(-.214,.124),(-.244,.068),(-.381,.068)],
        .058,0,.0011)
profile('Stock_Rear_Post',[(-.381,.071),(-.352,.071),(-.352,-.030),(-.381,-.030)],
        .050,0,.0008)
profile('Stock_Stepped_Brace',[(-.352,.009),(-.327,.009),(-.327,.029),
        (-.303,.029),(-.303,.048),(-.244,.048),(-.244,.027),(-.268,.027),
        (-.268,.008),(-.292,.008),(-.292,-.011),(-.316,-.011),
        (-.316,-.030),(-.352,-.030)],.050,2,.0006)
box('Stock_Front_Web',(0,-.260,.058),(.050,.039,.025),2,.0006)
box('Stock_Lower_Socket',(0,-.238,.055),(.033,.016,.026),6,.0005)
housing('Stock_Graphite_Pad',[(-.418,.059,.151,.003),(-.411,.064,.159,.003),
        (-.380,.064,.159,.003)],.040,6)
profile('Stock_Neck_Core',[(-.247,.119),(-.210,.119),(-.210,.126),(-.184,.126),
        (-.184,.134),(-.151,.134),(-.139,.128),(-.136,.081),
        (-.183,.080),(-.196,.086),(-.247,.086)],.044,4,.0008)
housing('Stock_Rear_Collar',[(-.246,.050,.039,.002),(-.226,.050,.039,.002)],.105,6)
profile('Stock_Receiver_Adapter',[(-.169,.130),(-.153,.143),(-.134,.139),
        (-.124,.121),(-.126,.062),(-.148,.064),(-.169,.078)],.057,4,.0008)

# Receiver with genuinely inset side ports under its overhanging roof.
profile('Receiver_Lower',[(-.135,.102),(-.125,.107),(.130,.107),(.139,.094),
        (.139,.050),(-.113,.048),(-.135,.062)],.060,4,.0013)
box('Receiver_Upper_Core',(0,.00675,.114),(.050,.2645,.023),6,.0007)
box('Receiver_Roof',(0,.00675,.128),(.060,.2645,.008),5,.0008)
profile('Receiver_Sloped_Rear_Cover',[(-.132,.059),(-.137,.100),(-.122,.139),
        (-.052,.132),(-.035,.119),(-.041,.056)],.064,4,.0010)
for side in [-1,1]:
    box('Receiver_Rear_Sidewall',(side*.0285,-.0935,.115),(.006,.077,.026),4,.0006)
    box('Receiver_Front_Sidewall',(side*.0285,.122,.115),(.006,.034,.026),4,.0006)
    box('Port_Lower_Lip',(side*.029,.023,.105),(.005,.158,.006),5,.0003)
    box('Inset_Port_Bolt',(side*.0258,.015,.1135),(.002,.115,.011),7,.0004)
    box('Receiver_Control',(side*.033,-.083,.070),(.005,.017,.006),7,.0004)
    box('Receiver_Control_Pin',(side*.0358,-.083,.070),(.001,.004,.004),8)
    for y in [-.115,.126]:
        box('Receiver_Square_Pin',(side*.0305,y,.061),(.0025,.005,.005),7,.0003)

# Solid tan grip with a narrow connected dark backstrap; shorten and move it
# rearward to match the reference's relation to the receiver and trigger guard.
grip_yz=[(-.094,.065),(-.036,.052),(-.074,-.078),(-.137,-.061)]
profile('Grip_Sand_Core',grip_yz,.043,0,.0012)
profile('Grip_Dark_Backstrap',[(-.094,.065),(-.086,.064),(-.129,-.060),(-.137,-.061)],
        .045,6,.0006)
profile('Grip_Graphite_Heel',[(-.143,-.060),(-.072,-.078),(-.077,-.094),(-.148,-.076)],
        .050,6,.0009)
yz_ring('Angular_Trigger_Guard',[(-.044,.055),(.064,.055),(.058,.008),
        (-.006,.008),(-.038,.024),(-.048,.036)],
        [(-.030,.046),(.048,.046),(.042,.020),(-.002,.020),(-.025,.030),(-.033,.037)],
        .029,6,.0008)
profile('Stepped_Trigger',[(-.002,.050),(.009,.050),(.006,.032),(.014,.025),
        (.009,.020),(-.004,.024),(-.008,.035)],.013,8,.0005)
for ob in parts['Frame']:
    if ob.name.startswith('Grip_'):
        for v in ob.data.vertices:
            v.co.y-=.050
            v.co.z=.055+(v.co.z-.055)*.80
    elif ob.name in ['Angular_Trigger_Guard','Stepped_Trigger']:
        for v in ob.data.vertices:
            v.co.y=-.050+(v.co.y-.008)*.86
            v.co.z=.055+(v.co.z-.055)*.72

# Compact detachable box matching the short block below the reference receiver.
profile('Magazine_Stub',[(.064,.057),(.136,.057),(.134,.035),(.065,.037)],
        .053,4,.0008,'Magazine')
box('Magazine_Baseplate',(0,.101,.035),(.056,.078,.005),6,.0006,'Magazine')
for side in [-1,1]:
    box('Magazine_Side_Inset',(side*.0268,.101,.045),(.001,.055,.009),6,0,'Magazine')

# Long upper barrel with an open warm graphite crown and a deep square bore.
barrel=housing('Main_Barrel',[(.143,.047,.042,.005),(.173,.041,.038,.004),
        (.603,.041,.038,.004),(.628,.039,.037,.004)],.108,4,
        hole=(.024,.025,.478),hole_chamfer=.0065)
crown=housing('Muzzle_Crown',[(.605,.047,.044,.004),(.632,.047,.044,.004),
        (.640,.044,.042,.003)],.108,7,hole=(.026,.027,.035),through=True,hole_chamfer=.0065)
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
        (.620,.032,.032,.006)],lower_tube_z,6,hole=(.018,.018,.012),hole_chamfer=.005)
for i,y in enumerate([.459,.484,.509,.534]):
    housing('Tube_Collar_%02d'%i,[(y,.042,.043,.007),(y+.018,.042,.043,.007)],
            lower_tube_z,4 if i%2 else 5,group='Frame')
box('Barrel_Tube_Bridge',(0,.450,.0875),(.044,.017,.015),6,.0008)
housing('Foreend_Front_Collar',[(.437,.065,.094,.006),(.456,.060,.094,.006)],
        .083,6,hole=(.027,.029,.019),through=True,hole_chamfer=.007,hole_z=.108)

# A slimmer, higher, continuous faceted pump. Shallow rectangular grooves replace
# the old raised fingers; the top/bottom chamfers remain one connected surface.
pump_body=housing('Pump_Faceted_Body',[(.216,.057,.069,.005),(.226,.066,.077,.006),
        (.430,.066,.077,.006),(.442,.058,.071,.005)],.079,0,group='Pump')
for side in [-1,1]:
    for y in [.246,.288,.330,.372,.414]:
        bpy.ops.mesh.primitive_cube_add(size=1,location=(side*.0345,y,.077))
        cutter=bpy.context.object;cutter.dimensions=(.007,.018,.062)
        cutter.data.materials.append(mat)
        for layer in list(cutter.data.uv_layers):cutter.data.uv_layers.remove(layer)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.context.view_layer.objects.active=pump_body
        mod=pump_body.modifiers.new('Shallow grip groove','BOOLEAN')
        mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
me=pump_body.data;me.update();uv=me.uv_layers.active
lo=[min(v.co[i] for v in me.vertices) for i in range(3)]
spans=[max(v.co[i] for v in me.vertices)-lo[i] for i in range(3)]
density=min(8.0,.84/max(spans))
for face in me.polygons:
    drop=max(range(3),key=lambda i:abs(face.normal[i]))
    axes=[i for i in range(3) if i!=drop]
    groove=abs(abs(face.center.x)-.031)<.00005 and .045<face.center.z<.109
    face_tile=2 if groove or face.normal.z<-.5 else (1 if face.center.z>.109 else 0)
    for li in face.loop_indices:
        co=me.vertices[me.loops[li].vertex_index].co
        u,v=[.08+(co[a]-lo[a])*density for a in axes]
        uv.data[li].uv=((face_tile%4+u)/4,(face_tile//4+v)/4)
box('Pump_Rear_Tan_Step',(0,.226,.123),(.064,.023,.020),1,.0008,'Pump')

# Dark upper fore-end and continuous Picatinny-style block rail.
box('Foreend_Upper_Shroud',(0,.29125,.128),(.060,.3055,.028),4,.0010)
box('Receiver_Rail_Riser',(0,.012,.138),(.048,.268,.014),6,.0006)
box('Top_Rail_Base',(0,.153,.145),(.045,.552,.008),6,.0005)
for i in range(25):
    y=-.116+i*.0222
    box('Top_Rail_Tooth_%02d'%i,(0,y,.15225),(.048,.010,.0065),7 if i%5==0 else 4,.0004)
box('Rear_Sight_Base',(0,-.061,.160),(.035,.022,.006),6,.0004)
for x in [-.012,.012]:
    box('Rear_Sight_Ear',(x,-.061,.166),(.011,.016,.014),4,.0004)
box('Front_Sight_Base',(0,.613,.133),(.027,.018,.005),6,.0004)
box('Front_Sight_Post',(0,.613,.140),(.012,.011,.012),7,.0004)

# Octagonal shell ends and brighter yellow brass match the close-up reference.
def upright_shell(name,center,dims,tile,chamfer):
    x,y,z=center;w,d,h=dims
    vs=[(x+xx,y+yy,z+zz) for zz in [-h/2,h/2] for xx,yy in octagon(w,d,chamfer)]
    fs=[tuple(reversed(range(8))),tuple(range(8,16))]
    fs += [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    return part(name,vs,fs,tile,group='Shells')
box('Shell_Saddle_Backplate',(.0365,.075,.082),(.009,.122,.074),6,.0009)
box('Shell_Saddle_Bottom_Rail',(.045,.075,.054),(.014,.127,.005),8,.0004)
for i,y in enumerate([.031,.059,.087,.115]):
    upright_shell('Shell_Red_%02d'%i,(.048,y,.082),(.018,.020,.052),12,.003)
    upright_shell('Shell_Brass_Cap_%02d'%i,(.048,y,.112),(.021,.022,.012),13,.004)
    upright_shell('Shell_Cap_Primer_%02d'%i,(.048,y,.1181),(.006,.006,.0006),9,.0015)
    box('Shell_Clamp_%02d'%i,(.060,y,.079),(.012,.024,.022),6,.0007)


def join(name,group,pivot):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts[group]:ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[group][0]
    bpy.ops.object.join()
    ob=bpy.context.object;ob.name=name
    pivot=Vector(pivot)
    for v in ob.data.vertices:v.co-=pivot
    ob.parent=root;ob.location=pivot-grip_origin
    return ob

frame=join('Shotgun_Sand_Frame','Frame',grip_origin)
pump=join('Shotgun_Sand_Pump','Pump',(0,.329,.079))
mag=join('Shotgun_Sand_Magazine','Magazine',(0,.103,.052))
shells=join('Shotgun_Sand_Shells','Shells',(.048,.075,.082))
pump['role']='Independent static fore-end; no animation authored'
mag['role']='Compact detachable box from reference silhouette'
shells['role']='Four decorative red/brass shell props in the side saddle'
markers={'RightHandGrip':tuple(grip_origin),'LeftHandGuide':(0,.329,.052),
         'Muzzle':(0,.641,.108),'AimReference':(0,.613,.146),
         'RecoilPivot':tuple(grip_origin),'HolsterAttach':tuple(grip_origin),'Grip_Point':tuple(grip_origin),
         'Support_Hand_Point':(0,.329,.052),'Muzzle_Point':(0,.641,.108),
         'MagazineFeed':(0,.103,.052)}
markers={name:tuple(Vector(pos)-grip_origin) for name,pos in markers.items()}
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
        'reference':'reference_refined.png','forward':'+Y','markers':markers,
        'authoring_origin_m':list(grip_origin),
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
focus=Vector((.008,.105,.045))-grip_origin
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
