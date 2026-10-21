"""Add one standalone Pending backpack to the existing Soldier library; never wear it."""
import bpy, bmesh, json, math, hashlib, random
from mathutils import Vector
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOLDIER = HERE.parents[1]
LIB = SOLDIER/'showcase/SOLDIER_Asset_Library.blend'
ASSET_NAME = 'SOLDIER_Backpack_v001_PENDING'
SCENE_NAME = 'SOLDIER_BACKPACK_REVIEW'
bpy.ops.wm.open_mainfile(filepath=str(LIB), load_ui=True)
bpy.context.preferences.filepaths.save_version=0
library = bpy.data.scenes['SOLDIER_ASSET_LIBRARY']
registry = json.loads(library['soldier_registry'])

def data_digest(obj):
    data={'matrix':[list(r) for r in obj.matrix_local], 'type':obj.type}
    if obj.type=='MESH':
        data.update(vertices=[list(v.co) for v in obj.data.vertices],
                    faces=[list(p.vertices) for p in obj.data.polygons],
                    uv=[[list(t.uv) for t in u.data] for u in obj.data.uv_layers],
                    weights=[[(g.group,g.weight) for g in v.groups] for v in obj.data.vertices],
                    groups=[g.name for g in obj.vertex_groups],
                    materials=[m.name for m in obj.data.materials])
    elif obj.type=='ARMATURE':
        data['bones']={b.name:[list(r) for r in b.matrix_local] for b in obj.data.bones}
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()

skin_entry=next(e for e in registry['entries'] if e['id']=='SOLDIER_Skin_v001')
skin_objects=list(bpy.data.collections[skin_entry['collection']].all_objects)
skin_before={o.name:data_digest(o) for o in skin_objects}
prior_actions=sorted(a.name for a in bpy.data.actions)

# A rerun refines only this same Pending asset. Everything outside BPK_ remains.
old=bpy.data.collections.get(ASSET_NAME)
if old:
    assert old['review_status']=='Pending', 'Reviewed backpack needs a new candidate'
if SCENE_NAME in bpy.data.scenes:
    bpy.data.scenes.remove(bpy.data.scenes[SCENE_NAME])
for o in list(bpy.data.objects):
    if o.name.startswith('BPK_'): bpy.data.objects.remove(o,do_unlink=True)
for c in list(bpy.data.collections):
    if c.name==ASSET_NAME or c.name.startswith('BPK_'): bpy.data.collections.remove(c)
for group in [bpy.data.meshes,bpy.data.materials,bpy.data.images,bpy.data.cameras,bpy.data.lights,bpy.data.worlds]:
    for block in list(group):
        if block.name.startswith('BPK_') and block.users==0: group.remove(block)
registry['entries']=[e for e in registry['entries'] if e['id']!='SOLDIER_Backpack_v001']

asset=bpy.data.collections.new(ASSET_NAME)
bpy.data.collections['04_EQUIPMENT'].children.link(asset)
review=bpy.data.scenes.new(SCENE_NAME)
review.collection.children.link(asset)
studio=bpy.data.collections.new('BPK_REVIEW_STUDIO')
review.collection.children.link(studio)
# Isolate assets in their own reviews; no overlapping/worn backpack in skin review.
def layer_for(root, collection):
    if root.collection==collection:return root
    for child in root.children:
        found=layer_for(child,collection)
        if found:return found
for layer in library.view_layers:
    layer_for(layer.layer_collection,asset).exclude=True
review['review_status']='Pending'
review['asset_id']='SOLDIER_Backpack_v001'
review['library_scene']='SOLDIER_ASSET_LIBRARY'
review['scope']='Standalone equipment only. Not fitted, parented, or attached to the character.'
review.unit_settings.system='METRIC'
regions=json.loads((HERE/'atlas_regions.json').read_text())
atlas=bpy.data.images.load(str(HERE/'backpack_atlas.png'))
atlas.name='BPK_Hand-painted canvas leather steel';atlas.pack()
mat=bpy.data.materials.new('BPK_Canvas Leather Steel / one atlas');mat.use_nodes=True
p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.86
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest'
mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
metal=mat.node_tree.nodes.new('ShaderNodeVertexColor');metal.layer_name='Surface_Metalness'
mat.node_tree.links.new(metal.outputs['Color'],p.inputs['Metallic'])

vertices=[];faces=[];styles=[];parts=[]
def add_mesh(name, verts, polys, tile, *, metal=False, plate=False):
    start=len(vertices);vertices.extend(verts)
    faces.extend([tuple(start+i for i in face) for face in polys])
    for face in polys:styles.append((tile,metal,plate,name))
    parts.append(name)

def box(name,center,size,tile='canvas',metal=False,plate=False):
    x,y,z=[v/2 for v in size];cx,cy,cz=center
    v=[(cx+a*x,cy+b*y,cz+c*z) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    f=[(0,1,5,4),(2,3,7,6),(1,2,6,5),(3,0,4,7),(4,5,6,7),(3,2,1,0)]
    add_mesh(name,v,f,tile,metal=metal,plate=plate)

def stepped(name,cx,z0,width,height,y_back,y_front,corner,tile):
    # Two coarse steps at each corner; no smooth round/beveled character geometry.
    l,r=cx-width/2,cx+width/2;b,t=z0,z0+height;c=corner
    outline=[(l+c,b),(r-c,b),(r-c,b+c/2),(r-c/2,b+c/2),(r-c/2,b+c),(r,b+c),
             (r,t-c),(r-c/2,t-c),(r-c/2,t-c/2),(r-c,t-c/2),(r-c,t),
             (l+c,t),(l+c,t-c/2),(l+c/2,t-c/2),(l+c/2,t-c),(l,t-c),
             (l,b+c),(l+c/2,b+c),(l+c/2,b+c/2),(l+c,b+c/2)]
    v=[(x,y,z) for y in [y_front,y_back] for x,z in outline];n=len(outline)
    f=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    add_mesh(name,v,f,tile)

def ribbon(name,x,path,width,thickness,tile):
    # A solid flat strap through a polygonal path, with square cross section.
    v=[]
    for i,(y,z) in enumerate(path):
        before=Vector(path[max(0,i-1)]);after=Vector(path[min(len(path)-1,i+1)])
        tangent=(after-before).normalized();normal=Vector((-tangent.y,tangent.x))
        for sx,st in [(-1,-1),(1,-1),(1,1),(-1,1)]:
            v.append((x+sx*width/2,y+st*normal.x*thickness/2,z+st*normal.y*thickness/2))
    f=[(3,2,1,0)]
    for i in range(len(path)-1):
        for j in range(4):f.append((4*i+j,4*i+(j+1)%4,4*(i+1)+(j+1)%4,4*(i+1)+j))
    a=4*(len(path)-1);f.append((a,a+1,a+2,a+3))
    add_mesh(name,v,f,tile)

def frame(name,x,y,z,w,h,bar=.010):
    # True open center: the dark strap shows through the metal frame.
    box(name+' left',(x-w/2+bar/2,y,z),(bar,.012,h),'steel',True)
    box(name+' right',(x+w/2-bar/2,y,z),(bar,.012,h),'steel',True)
    box(name+' upper',(x,y,z+h/2-bar/2),(w-2*bar,.012,bar),'steel',True)
    box(name+' lower',(x,y,z-h/2+bar/2),(w-2*bar,.012,bar),'steel',True)

# Compact layered canvas shell and darker silhouette/seam bands.
stepped('shadow silhouette',0,.026,.438,.630,.103,-.151,.042,'canvas_shadow')
stepped('main canvas body',0,.036,.422,.619,.102,-.168,.038,'canvas')
stepped('front raised seam rim',0,.042,.407,.606,-.166,-.180,.035,'canvas_edge')
stepped('front inner fabric',0,.055,.373,.577,-.179,-.185,.026,'canvas_warm')
box('top cap fold',(0,-.018,.649),(.340,.202,.030),'canvas_flap')
box('top front piping',(0,-.161,.647),(.336,.025,.020),'canvas_edge')
box('base reinforcement',(0,-.010,.045),(.351,.215,.034),'canvas_shadow')
box('bottom front canvas hem',(0,-.180,.065),(.348,.023,.024),'canvas_warm')
for sign in [-1,1]:
    x=sign*.200
    box('vertical rounded edge '+str(sign),(x,-.137,.346),(.022,.064,.527),'canvas_side')
    box('front perimeter stitch '+str(sign),(sign*.184,-.187,.345),(.010,.010,.516),'canvas_edge')

# Broad top flap and its paired dark webbing / silver closure tabs.
stepped('large top flap',0,.386,.351,.251,-.190,-.218,.022,'canvas_flap')
box('flap lower folded hem',(0,-.227,.397),(.327,.020,.023),'canvas_edge')
box('flap top shoulder fold',(0,-.204,.628),(.318,.050,.023),'canvas_edge')
for sign in [-1,1]:
    x=sign*.125
    box('upper closure understrap '+str(sign),(x,-.222,.390),(.039,.016,.128),'webbing_brown')
    box('upper closure metal tab '+str(sign),(x,-.240,.395),(.039,.014,.077),'buckle_plate',True,True)
    box('upper tab dark tip '+str(sign),(x,-.229,.345),(.031,.015,.025),'leather')

# Two separate front cargo pouches, with real volume and layered flap lips.
for sign in [-1,1]:
    x=sign*.094
    stepped('front pouch shadow '+str(sign),x,.083,.181,.236,-.185,-.273,.016,'canvas_shadow')
    stepped('front pouch body '+str(sign),x,.090,.170,.220,-.190,-.285,.012,'canvas_warm')
    box('pouch lower piping '+str(sign),(x,-.289,.100),(.145,.014,.014),'canvas_edge')
    stepped('front pouch flap '+str(sign),x,.182,.177,.132,-.267,-.305,.012,'canvas_flap')
    box('pouch flap folded hem '+str(sign),(x,-.309,.187),(.156,.013,.018),'canvas_edge')
    box('pouch long closure '+str(sign),(x,-.297,.167),(.034,.018,.154),'webbing_brown')
    box('pouch closure plate '+str(sign),(x,-.322,.182),(.040,.014,.066),'buckle_plate',True,True)
    box('pouch closure tail '+str(sign),(x,-.304,.122),(.029,.016,.032),'leather')
    for edge in [-1,1]:
        box('pouch side seam',(x+edge*.079,-.282,.196),(.008,.011,.171),'canvas_edge')

# Side sleeves, compression webbing, and lower accessory pockets.
for sign in [-1,1]:
    x=sign*.232
    box('upper side canvas bolster '+str(sign),(x,-.005,.520),(.048,.151,.213),'canvas_side')
    box('upper side outer panel '+str(sign),(sign*.261,-.005,.524),(.013,.126,.172),'canvas_warm')
    box('upper compression band '+str(sign),(sign*.256,-.004,.475),(.032,.170,.044),'leather')
    box('side upper steel guide '+str(sign),(sign*.278,-.001,.531),(.012,.037,.107),'steel',True)
    box('side lower guide tail '+str(sign),(sign*.266,-.001,.464),(.012,.023,.044),'steel_edge',True)
    box('lower side pocket shadow '+str(sign),(sign*.237,.001,.183),(.081,.155,.254),'canvas_shadow')
    box('lower side pocket '+str(sign),(sign*.255,-.004,.184),(.072,.145,.237),'canvas_warm')
    box('side pocket flap '+str(sign),(sign*.269,-.004,.270),(.065,.155,.086),'canvas_flap')
    box('side pocket flap edge '+str(sign),(sign*.299,-.004,.236),(.013,.145,.016),'canvas_edge')
    box('side pocket black strap '+str(sign),(sign*.296,-.001,.194),(.012,.160,.041),'leather')
    box('side pocket closure plate '+str(sign),(sign*.313,-.002,.228),(.014,.042,.066),'buckle_plate',True,True)
    box('lower compression band '+str(sign),(sign*.255,.005,.095),(.093,.167,.036),'leather')

# Back canvas and crossed padding/waist webbing, faithful to the back reference.
stepped('back padded inset',0,.080,.336,.525,.129,.102,.018,'canvas_warm')
for z in [.249,.427]:
    box('back horizontal dark pad',(0,.137,z),(.322,.021,.055),'leather')
for sign in [-1,1]:
    x=sign*.122
    box('back shoulder padding '+str(sign),(x,.148,.361),(.067,.038,.564),'canvas_side')
    box('back padding face '+str(sign),(x,.171,.372),(.053,.015,.525),'canvas_warm')
    box('upper back dark strap '+str(sign),(x,.184,.548),(.077,.017,.047),'leather')
    box('adjustment webbing '+str(sign),(x,.188,.226),(.040,.020,.236),'leather')
    frame('back shoulder adjuster '+str(sign),x,.210,.344,.074,.074,.011)
    # Shoulder loop is unsupported equipment geometry, not attached to any rig.
    path=[(.119,.633),(.174,.602),(.228,.536),(.266,.432),(.278,.307),(.252,.205),(.201,.135),(.118,.104)]
    ribbon('outer shoulder loop '+str(sign),sign*.135,path,.058,.023,'webbing_brown')
    ribbon('upper shoulder reinforcement '+str(sign),sign*.135,path[:3],.064,.026,'canvas_side')
    ribbon('lower shoulder strap '+str(sign),sign*.135,path[4:],.052,.025,'leather')
    box('bottom back strap keeper '+str(sign),(x,.208,.139),(.078,.026,.043),'leather')
box('waist webbing',(0,.211,.126),(.366,.025,.052),'leather')
frame('waist buckle',0,.232,.126,.084,.071,.012)

# Squared carry handle and its short mount blocks.
for sign in [-1,1]:
    box('handle mount '+str(sign),(sign*.062,.057,.665),(.032,.046,.033),'leather')
    box('handle upright '+str(sign),(sign*.062,.057,.690),(.021,.032,.040),'leather')
box('top carry handle',(0,.057,.710),(.145,.035,.021),'leather')

mesh=bpy.data.meshes.new('BPK_Standalone backpack mesh')
mesh.from_pydata(vertices,[],faces);mesh.update()
obj=bpy.data.objects.new('BPK_Backpack_v001',mesh);asset.objects.link(obj)
mesh.materials.append(mat)
# Fix winding on generated solids; keep their hard block-shaped surfaces.
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
uv=mesh.uv_layers.new(name='Backpack_Atlas')
attr=mesh.color_attributes.new(name='Surface_Metalness',type='FLOAT_COLOR',domain='CORNER')
for poly,style in zip(mesh.polygons,styles):
    tile,is_metal,is_plate,part=style
    if is_metal and not is_plate and abs(poly.normal.z)>.5:tile='steel_edge'
    # Subtle seam highlights are geometry-specific, not screen-space noise.
    rx,ry,rw,rh=regions[tile]
    coords=[mesh.vertices[i].co for i in poly.vertices]
    axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=axis]
    if axis==1:axes=[0,2]
    if axis==0:axes=[1,2]
    lo=[min(v[a] for v in coords) for a in axes];hi=[max(v[a] for v in coords) for a in axes]
    span=[max(hi[i]-lo[i],1e-5) for i in range(2)]
    rng=random.Random(part+str(poly.index//6))
    # Keep a consistent coarse pixel density rather than stretching a full tile per small box.
    scale=[min(.98,max(.08,v/(.0048*rw))) for v in span]
    offset=[rng.uniform(0,1-scale[i]) for i in range(2)]
    if is_plate:scale=[.98,.98];offset=[.01,.01]
    for li in poly.loop_indices:
        co=mesh.vertices[mesh.loops[li].vertex_index].co
        a=(co[axes[0]]-lo[0])/span[0];b=(co[axes[1]]-lo[1])/span[1]
        u=offset[0]+a*scale[0];v=offset[1]+b*scale[1]
        uv.data[li].uv=((rx+.02+u*(rw-.04))/512,(512-ry-rh+.02+v*(rh-.04))/512)
        m=.62 if is_metal else 0.
        attr.data[li].color=(m,m,m,1.)
    poly.use_smooth=False
obj['asset_id']='SOLDIER_Backpack_v001';obj['review_status']='Pending'
obj['scope']='Standalone backpack only; no parent, armature, attachment, or gameplay integration'
obj['parts']=json.dumps(parts)
asset.asset_mark();asset['review_status']='Pending';asset['standalone']=True
asset.asset_data.description='Pending standalone survival backpack matching supplied sheet: layered brown canvas, twin cargo pockets, side pouches, shoulder loops, square metal buckles. Not worn or attached.'
asset.asset_data.author='GameAssetFactory'
for tag in ['Soldier','Equipment','Backpack','Pending','Standalone']:asset.asset_data.tags.new(tag)
import uuid
asset.asset_data.catalog_id=str(uuid.uuid5(uuid.UUID('61d15e50-3029-47c6-9db9-3d1c2813aa89'),'SOLDIER/Equipment'))

def studio_material(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=1
    return m
floor_mesh=bpy.data.meshes.new('BPK_Studio floor')
floor_mesh.from_pydata([(-100,-100,.025),(100,-100,.025),(100,100,.025),(-100,100,.025)],[],[(0,1,2,3)]);floor_mesh.update()
floor=bpy.data.objects.new('BPK_Review floor',floor_mesh);studio.objects.link(floor)
floor_mesh.materials.append(studio_material('BPK_Studio matte',(.54,.52,.47)))
world=bpy.data.worlds.new('BPK_Soft studio');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.74,.76,.79,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.45;review.world=world
for name,loc,power,size in [('Key',(-2,-3,3),220,2.5),('Fill',(3,-1,2),75,2.5),('Rim',(1,2,3),150,2)]:
    data=bpy.data.lights.new('BPK_'+name,'AREA');data.energy=power;data.size=size
    light=bpy.data.objects.new('BPK_'+name,data);studio.objects.link(light);light.location=loc
    light.rotation_euler=(Vector((0,0,.37))-light.location).to_track_quat('-Z','Y').to_euler()
views={'Front':0,'Front_3Q':-38,'Left_Side':90,'Back':180,'Right_Side':-90,'Back_3Q':145}
for name,degrees in views.items():
    a=math.radians(degrees);data=bpy.data.cameras.new('BPK_'+name);data.type='ORTHO';data.ortho_scale=.87
    camera=bpy.data.objects.new('BPK_'+name,data);studio.objects.link(camera)
    camera.location=(3*math.sin(a),-3*math.cos(a),1.01)
    camera.rotation_euler=(Vector((0,-.012,.361))-camera.location).to_track_quat('-Z','Y').to_euler()
review.camera=bpy.data.objects['BPK_Front_3Q']
review.render.engine='CYCLES';review.cycles.device='CPU';review.cycles.samples=48;review.cycles.use_denoising=True
review.render.resolution_x=800;review.render.resolution_y=900;review.render.resolution_percentage=100
review.render.image_settings.file_format='PNG';review.render.image_settings.color_mode='RGBA'
review.view_settings.view_transform='Standard';review.view_settings.look='None'
review.view_settings.exposure=0;review.view_settings.gamma=1
for window in bpy.context.window_manager.windows:window.scene=review
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.shading.type='MATERIAL'

reference=bpy.data.images.load(str(HERE/'primary_reference.png'))
reference.name='BPK_PRIMARY backpack reference';reference.pack();reference.use_fake_user=True
mesh.calc_loop_triangles()
entry={'id':'SOLDIER_Backpack_v001','label':'Survival Backpack / supplied reference','status':'Pending','type':'equipment','collection':asset.name,'object':obj.name,'review_scene':review.name,'standalone':True,'attached_to_character':False,'cameras':['BPK_'+v for v in views],'dimensions_m':[float(v) for v in obj.dimensions]}
registry['entries'].append(entry);library['soldier_registry']=json.dumps(registry)
library['active_equipment_review']=review.name
notes=bpy.data.texts.new('BPK_START HERE — STANDALONE BACKPACK')
notes.write('SOLDIER BACKPACK v001 / PENDING\nStandalone backpack built from supplied reference.\nNot attached, parented or fitted to the character.\nReview scene SOLDIER_BACKPACK_REVIEW. Skin review remains SOLDIER_ASSET_LIBRARY.\nFront, three-quarter, side and back cameras have the BPK_ prefix.\nOne mesh / one packed pixel atlas. No Actions or Godot integration.\nAsset Browser catalog SOLDIER/Equipment, Current File.\n')
(HERE/'renders').mkdir(exist_ok=True)
for view in views:
    review.camera=bpy.data.objects['BPK_'+view]
    review.render.filepath=str(HERE/'renders'/f'{view}.png')
    bpy.ops.render.render(write_still=True,scene=review.name)
    print('BACKPACK_RENDER',view,flush=True)
review.camera=bpy.data.objects['BPK_Front_3Q']
with bpy.context.temp_override(id=asset):bpy.ops.ed.lib_id_load_custom_preview(filepath=str(HERE/'renders/Front_3Q.png'))
assert skin_before=={o.name:data_digest(o) for o in skin_objects},'Existing Soldier skin changed'
assert sorted(a.name for a in bpy.data.actions)==prior_actions
assert obj.parent is None and len(obj.modifiers)==0
assert len([o for o in review.objects if o.type=='ARMATURE'])==0
bpy.ops.wm.save_as_mainfile(filepath=str(LIB),compress=True)
(SOLDIER/'showcase/registry.json').write_text(json.dumps(registry,indent=2))
report={'asset_id':entry['id'],'status':'Pending','vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),'mesh_objects':1,'materials':1,'parts':len(parts),'dimensions_m':entry['dimensions_m'],'standalone':True,'attached_to_character':False,'actions_added':0,'skin_preserved':True,'skin_fingerprints':skin_before,'primary_reference_sha256':hashlib.sha256((HERE/'primary_reference.png').read_bytes()).hexdigest(),'library':str(LIB),'review_scene':review.name}
(HERE/'validation.json').write_text(json.dumps(report,indent=2))
print('BACKPACK_SAVED',json.dumps(report),flush=True)
