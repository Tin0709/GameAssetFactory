"""User-reference sword prop: +Y towards blade tip, grip root at origin."""
import argparse,bmesh,bpy,json,math,random,sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
TARGET=OUT/'Sword_Sand_Block_V1.blend'
p=argparse.ArgumentParser();p.add_argument('--rebuild',action='store_true');p.add_argument('--no-render',action='store_true')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
assert args.rebuild or not TARGET.exists(),'Explicit --rebuild required for this Pending source'
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.name='Sword Sand Block V1 — User Reference'
s.unit_settings.system='METRIC'
c=bpy.data.collections.new('WEAPON_EXPORT');s.collection.children.link(c)
root=bpy.data.objects.new('Sword_Sand_Block_V1',None);c.objects.link(root)
root['review_status']='Pending';root['forward']='+Y';root['origin']='RightHandGrip'
root['reference']='reference.png — user sword multi-view 2026-10-25'
atlas=bpy.data.images.load(str(OUT/'palette_source_256.png'),check_existing=False)
atlas.name='Sword_Sand_Atlas_256';pixels=list(atlas.pixels[:]);rng=random.Random(20261025)
# Preserve the accepted visible graphite pixel texture. Dedicated gold and silver
# swatches replace only unused/old sand colors, with restrained broad patches.
colors={0:(181,139,76),1:(207,168,100),2:(147,111,61),3:(226,190,125),
        12:(183,176,166),13:(212,203,187),14:(152,148,141),15:(34,34,36)}
for tile,rgb in colors.items():
    shades=[[1.0]*64 for _ in range(64)]
    for _ in range(92):
        xx,yy=rng.randrange(2,58),rng.randrange(2,58);w,h=rng.choice([3,4,6]),rng.choice([3,5,7])
        shade=rng.choice([.90,.95,1.04,1.09]) if tile<4 else rng.choice([.94,.98,1.02,1.06])
        for y in range(yy,min(62,yy+h)):
            for x in range(xx,min(62,xx+w)):shades[y][x]=shade
    for y in range(64):
        for x in range(64):
            i=(((tile//4)*64+y)*256+(tile%4)*64+x)*4
            values=[min(1,v/255*shades[y][x]) for v in rgb]
            pixels[i:i+4]=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values]+[1]
atlas.pixels.foreach_set(pixels);atlas.filepath_raw=str(OUT/'sword_sand_atlas_256.png')
atlas.file_format='PNG';atlas.save();atlas.pack()
mat=bpy.data.materials.new('Sword_Hilt_Gold_Graphite');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=.28;bs.inputs['Roughness'].default_value=.62
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest'
mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
blade_mat=mat.copy();blade_mat.name='Sword_Blade_Graphite_Silver'
blade_mat.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value=.55
blade_mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.47
parts={'Hilt':[],'Blade':[]}
def Y(px):return (px-116)*.0019
def Z(py):return (587-py)*.0019
def P(px,py,x=0):return (x,Y(px),Z(py))
def part(name,vertices,faces,tile=0,bevel=0,group='Hilt',face_tiles=None):
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
    uv = me.uv_layers.new(name='SwordAtlasUV')
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


def profile(name,yz,width,tile=0,bevel=0,group='Hilt',x=0):
    n = len(yz)
    vs = [(x+xx,y,z) for xx in [-width/2,width/2] for y,z in yz]
    fs = [tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return part(name,vs,fs,tile,bevel,group)


def box(name,center,dims,tile=0,bevel=0,group='Hilt'):
    x,y,z = center
    w,l,h = dims
    return profile(name,[(y-l/2,z-h/2),(y+l/2,z-h/2),
                         (y+l/2,z+h/2),(y-l/2,z+h/2)],w,tile,bevel,group,x)


def octagon(w,h,ch):
    return [(-w/2+ch,-h/2),(w/2-ch,-h/2),(w/2,-h/2+ch),(w/2,h/2-ch),
            (w/2-ch,h/2),(-w/2+ch,h/2),(-w/2,h/2-ch),(-w/2,-h/2+ch)]


def housing(name,rings,z,tile=4,hole=None,through=False,group='Hilt',hole_chamfer=.0008,hole_z=None):
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

def block(name,px,py,length,height,width,tile=0,bevel=.0007,x=0):
    return box(name,P(px,py,x),(width,length*.0019,height*.0019),tile,bevel)

# Five separate faceted wraps, with a recessed core visible between the bands.
housing('Grip_Dark_Core',[(Y(80),.042,.049,.005),(Y(148),.042,.049,.005)],0,6)
for i,px in enumerate([89,101,113,125,137]):
    housing('Grip_Wrap_%02d'%i,[(Y(px-5.3),.046,.052,.005),
        (Y(px-4.6),.052,.057,.0055),(Y(px+4.6),.052,.057,.0055),
        (Y(px+5.3),.046,.052,.005)],0,4 if i%2==0 else 5)

# Framed gold pommel: real recessed rear end and dark raised side inserts.
housing('Pommel_Gold_Frame',[(Y(40),.055,.084,.006),(Y(44),.070,.098,.006),
        (Y(76),.070,.098,.006),(Y(82),.056,.084,.004)],0,0,
        hole=(.028,.046,.001),through=True,hole_chamfer=.002)
block('Pommel_Recessed_End_Floor',48,587,4,25,.029,8,.0003)
for side in [-1,1]:
    block('Pommel_Dark_Side_Inlay',60,587,22,34,.0042,4,.0012,side*.0361)
    block('Pommel_Inlay_Inner_Panel',60,587,16,26,.0012,6,.0003,side*.0388)
block('Pommel_Upper_Gold_Cap',60,563,30,7,.067,1,.0008)
block('Pommel_Lower_Gold_Cap',60,611,30,7,.067,2,.0008)

# Central boss is thicker than the crossbar; its raised graphite face and gold
# forward flange match the layered guard detail in the supplied image.
block('Guard_Gold_Rear_Ferrule',151,587,20,45,.064,1,.0011)
block('Guard_Gold_Central_Boss',165,587,33,52,.074,0,.0014)
block('Guard_Upright_Gold_Core',181,588,25,119,.055,0,.0010)
for side in [-1,1]:
    block('Guard_Upright_Dark_Inlay',185.8,588,10,101,.003,6,.0004,side*.0293)
    block('Guard_Raised_Dark_Face',169,587,23,35,.006,4,.0014,side*.0405)
    block('Guard_Face_Lower_Segment',169,596,22,15,.001,6,.0003,side*.0442)
block('Guard_Upper_Gold_Cap',181,528,32,11,.068,1,.0011)
block('Guard_Lower_Gold_Cap',181,648,32,11,.068,0,.0011)
block('Guard_Lower_Dark_Sole',181,655,26,3,.053,8,.0005)
block('Guard_Upper_Dark_End_Inset',181,521.7,12,1,.031,6,.0002)
block('Guard_Forward_Gold_Flange',194,587,7,68,.057,1,.0006)
block('Guard_Blade_Seat',199,587,6,51,.044,6,.0004)

# One continuous stepped blade. The broad dark fields, shallow central fuller
# and tapered silver edging share a closed loft. Subdivisions preserve pixel
# density on the long surface; they add no separate floating decal planes.
sections=[(200,230,34,12,.0205),(230.4,332,30,8,.0205),
    (332.4,458,28,8,.0205),(458.4,546,26,7,.0205),
    (546.4,582,25,7,.0205),(582.4,596,18,6,.019),
    (596.4,608,12,5,.014),(608.4,620,7,4,.008),(622,622.8,2,1,.004)]
rings=[]
for a,b,half,edge,face_x in sections:
    count=max(1,math.ceil((b-a)/16))
    for j in range(count+1):
        px=a+(b-a)*j/count
        rings.append((px,half*.0019,edge*.0019,face_x))
vertices=[]
for px,half,edge,face_x in rings:
    outer_x=min(.006,face_x*.6);channel=min(.006,half*.25)
    inset=face_x-min(.0013,face_x*.12)
    section=[(outer_x,half),(face_x,half-edge),(face_x,channel),(inset,channel),
        (inset,-channel),(face_x,-channel),(face_x,-half+edge),(outer_x,-half),
        (-outer_x,-half),(-face_x,-half+edge),(-face_x,-channel),(-inset,-channel),
        (-inset,channel),(-face_x,channel),(-face_x,half-edge),(-outer_x,half)]
    vertices += [(x,Y(px),z) for x,z in section]
faces=[tuple(reversed(range(16)))];tiles=[14]
for j in range(len(rings)-1):
    tip=rings[j][0]>=608
    for i in range(16):
        k=(i+1)%16
        faces.append((16*j+i,16*j+k,16*(j+1)+k,16*(j+1)+i))
        if tip:tile=13 if i in [0,14,15] else 12
        elif i in [0,14,15]:tile=13
        elif i in [6,7,8]:tile=12
        elif i in [2,3,4,10,11,12]:tile=6
        else:tile=4 if (j//3)%3 else 5
        tiles.append(tile)
faces.append(tuple((len(rings)-1)*16+i for i in range(16)));tiles.append(13)
blade=part('Blade_Continuous_Stepped_Loft',vertices,faces,4,group='Blade',face_tiles=tiles)
blade.data.materials.clear();blade.data.materials.append(blade_mat)
# Map each short face locally, retaining a consistent density and per-cell pixel
# variation rather than stretching one small swatch over the entire blade.
uv=blade.data.uv_layers.active
for face in blade.data.polygons:
    drop=max(range(3),key=lambda i:abs(face.normal[i]));axes=[i for i in range(3) if i!=drop]
    coords=[blade.data.vertices[i].co for i in face.vertices]
    lo=[min(v[a] for v in coords) for a in axes]
    span=max(max(v[a] for v in coords)-lo[k] for k,a in enumerate(axes))
    density=min(8,.70/max(span,1e-6));tile=tiles[face.index]
    offsets=[.08+(face.index*7%11)*.012,.08+(face.index*13%7)*.014]
    for li in face.loop_indices:
        co=blade.data.vertices[blade.data.loops[li].vertex_index].co
        u,v=[offsets[k]+(co[a]-lo[k])*density for k,a in enumerate(axes)]
        uv.data[li].uv=((tile%4+u)/4,(tile//4+v)/4)

# A short raised dark lock plate and a recessed-looking panel distinguish the
# ricasso from the long flat blade as in the reference's side/detail views.
for side in [-1,1]:
    ob=box('Blade_Root_Dark_Plate',P(211,587,side*.0222),(.004,23*.0019,17*.0019),4,.0007,'Blade')
    ob.data.materials.clear();ob.data.materials.append(blade_mat)

def join(name,group):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts[group]:ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[group][0];bpy.ops.object.join()
    ob=bpy.context.object;ob.name=name;ob.parent=root
    return ob
hilt=join('Sword_Hilt','Hilt');blade=join('Sword_Blade','Blade')
markers={'RightHandGrip':(0,0,0),'Grip_Point':(0,0,0),'HolsterAttach':(0,0,0),
    'BladeBase':P(200,587),'BladeTip':P(622.8,587),'GuardCenter':P(181,587)}
for name,pos in markers.items():
    ob=bpy.data.objects.new(name,None);c.objects.link(ob);ob.parent=root;ob.location=pos
    ob.empty_display_type='ARROWS';ob.empty_display_size=.018;root[name]=list(pos)
bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for ob in c.all_objects:ob.select_set(True)
bpy.context.view_layer.objects.active=hilt
bpy.ops.export_scene.gltf(filepath=str(OUT/'Sword_Sand_Block_V1.glb'),export_format='GLB',
    use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
meshes=[hilt,blade];points=[ob.matrix_world@v.co for ob in meshes for v in ob.data.vertices]
report={'status':'Pending','meshes':2,'materials':2,'atlas_size':[256,256],'forward':'+Y',
    'reference':'reference.png','markers':markers,'topology':{},
    'dimensions_m':[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]}
for ob in meshes:
    ob.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(ob.data)
    info={'triangles':len(ob.data.loop_triangles),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),
        'loose_vertices':sum(not v.link_faces for v in bm.verts)};bm.free()
    assert not info['nonmanifold_edges'] and not info['loose_vertices'],(ob.name,info)
    report['topology'][ob.name]=info
report['triangles']=sum(v['triangles'] for v in report['topology'].values())
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
s['review_status']='Pending';s['asset_report']=json.dumps(report)

studio=bpy.data.collections.new('SOURCE_REVIEW_STUDIO');s.collection.children.link(studio)
world=bpy.data.worlds.new('Sword Graphite Studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.028,.033,.044,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.35;s.world=world
fm=bpy.data.materials.new('Sword Review Floor');fm.use_nodes=True
fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.003,.004,.006,1)
fm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,min(p.z for p in points)-.002))
floor=bpy.context.object
for col in list(floor.users_collection):col.objects.unlink(floor)
studio.objects.link(floor);floor.name='Sword_Review_Ground';floor.data.materials.append(fm)
focus=Vector(P(330,587))
for name,loc,power,size,color in [
    ('Sword Key',(1.4,-.8,2.2),340,2.0,(1,.91,.79)),
    ('Sword Fill',(1.3,1.9,.8),150,1.6,(.76,.85,1)),
    ('Sword Rim',(-1.4,-.4,1.8),430,1.7,(1,.86,.69))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.color=color
    ob=bpy.data.objects.new(name,data);studio.objects.link(ob);ob.location=loc
    ob.rotation_euler=(focus-ob.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Sword_Review_Camera',bpy.data.cameras.new('Sword_Review_Camera'))
studio.objects.link(cam);cam.data.type='ORTHO';cam.data.ortho_scale=1.27
cam.location=focus+Vector((1.6,.59,.48))
cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=40;s.cycles.use_denoising=True
s.render.threads_mode='FIXED';s.render.threads=8
s.render.resolution_x,s.render.resolution_y=1700,1000;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX'
bpy.ops.object.select_all(action='DESELECT');hilt.select_set(True);bpy.context.view_layer.objects.active=hilt
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
            sp.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            sp.region_3d.view_location=focus;sp.region_3d.view_distance=1.5;sp.region_3d.view_perspective='ORTHO'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET));print('SWORD_SAVED',json.dumps(report),flush=True)
review=OUT/'review';review.mkdir(exist_ok=True)
if not args.no_render:
    for name,direction,ortho in [('three_quarter',(1.6,.59,.48),1.27),('side',(1.6,0,.002),1.27),
        ('opposite',(-1.6,0,.002),1.27),('top',(0,0,1.6),1.27),('front',(0,1.6,.006),.47)]:
        cam.location=focus+Vector(direction);cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler()
        if name=='top':cam.rotation_euler=(0,0,math.pi/2)
        floor.hide_render=name!='three_quarter'
        cam.data.ortho_scale=ortho;s.render.filepath=str(review/(name+'.png'));bpy.ops.render.render(write_still=True)
print('SWORD_SAND_BLOCK_BUILT',flush=True)

