"""Original Stevens-inspired blocky shotgun; source assets remain read-only."""
import bpy,bmesh,math,json,sys,shutil,datetime
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];TARGET=HERE/'Shotgun_Stylized_V2.blend'
if TARGET.exists():
 assert '--refine-iteration' in sys.argv,'Back up the Pending source before refining'
 backup=ROOT/'.validation/shotgun_stylized_v2'/('iteration_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));backup.mkdir(parents=True)
 for name in ['Shotgun_Stylized_V2.blend','Shotgun_Stylized_V2.glb','asset_report.json','shotgun_v2_palette_64.png']:
  if (HERE/name).exists():shutil.copy2(HERE/name,backup/name)
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.unit_settings.system='METRIC'
c=bpy.data.collections.new('WEAPON_EXPORT');s.collection.children.link(c)
root=bpy.data.objects.new('Shotgun_Stylized_V2',None);c.objects.link(root)
root['review_status']='Pending';root['forward']='+Y';root['origin']='RightHandGrip'
palette=[(42,48,57),(106,123,135),(143,159,170),(105,117,126),(25,31,40),(107,77,62),(79,59,44),(50,57,68)]
im=bpy.data.images.new('Shotgun_V2_Family_Palette',width=64,height=64,alpha=True);im.colorspace_settings.name='sRGB'
im.pixels.foreach_set([v for y in range(64) for x in range(64) for v in (*[n/255 for n in palette[x//8]],1)])
im.filepath_raw=str(HERE/'shotgun_v2_palette_64.png');im.file_format='PNG';im.save();im.pack()
mat=bpy.data.materials.new('Shotgun_V2_Graphite_Steel_Wood');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=.12;bs.inputs['Roughness'].default_value=.5
tx=mat.node_tree.nodes.new('ShaderNodeTexImage');tx.image=im;tx.interpolation='Closest';mat.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
parts={'Base':[],'Pump':[]}
def mesh(name,vs,fs,tile=0,bevel=0,kind='Base',tiles=None):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);c.objects.link(o);me.materials.append(mat)
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 if bevel:
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
  m=o.modifiers.new('Small single-segment chamfer','BEVEL');m.width=bevel;m.segments=1;bpy.ops.object.modifier_apply(modifier=m.name)
 uv=me.uv_layers.new(name='PaletteUV')
 for p in me.polygons:
  color=tiles[p.index] if tiles else tile
  if bevel and p.area<.00002:color={0:7,7:1,4:0,5:5,6:5}.get(color,color)
  for li in p.loop_indices:uv.data[li].uv=((color*8+4)/64,.5)
  p.use_smooth=False
 vg=o.vertex_groups.new(name=name);vg.add(list(range(len(me.vertices))),1,'REPLACE');parts[kind].append(o);return o
def profile(name,points,width,tile=0,bevel=0,kind='Base',x=0):
 n=len(points);vs=[(x+xx,y,z) for xx in [-width/2,width/2] for y,z in points]
 fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,vs,fs,tile,bevel,kind)
def box(name,y0,y1,z0,z1,width,tile=0,bevel=0,kind='Base',x=0):return profile(name,[(y0,z1),(y1,z1),(y1,z0),(y0,z0)],width,tile,bevel,kind,x)
def ring(name,outer,inner,width,tile=0):
 n=len(outer);assert n==len(inner)
 vs=[(x,y,z) for x in [-width/2,width/2] for pts in [outer,inner] for y,z in pts];fs=[]
 for i in range(n):
  j=(i+1)%n;fs.extend([(i,j,j+n,i+n),(i+2*n,i+3*n,j+3*n,j+2*n),(i,i+2*n,j+2*n,j),(i+n,j+n,j+3*n,i+3*n)])
 return mesh(name,vs,fs,tile)
def tube(name,y0,y1,z,r,tile=0,bore=None):
 n=8;cross=lambda radius:[(math.cos((i+.5)*math.tau/n)*radius,z+math.sin((i+.5)*math.tau/n)*radius) for i in range(n)]
 if bore:
  vs=[(x,y,zz) for y in [y0,y1] for radius in [r,bore] for x,zz in cross(radius)];fs=[];colors=[]
  for i in range(n):
   j=(i+1)%n;fs.extend([(i,j,j+16,i+16),(i+8,i+24,j+24,j+8),(i+16,j+16,j+24,i+24),(i,i+8,j+8,j)])
   colors.extend([tile,4,3,tile])
  return mesh(name,vs,fs,tiles=colors)
 vs=[(x,y,zz) for y in [y0,y1] for x,zz in cross(r)]
 fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,vs,fs,tile)
def pin(name,y,z,x):
 n=6;vs=[(xx,y+math.cos(i*math.tau/n)*.0024,z+math.sin(i*math.tau/n)*.0024) for xx in [x-.0004,x+.0004] for i in range(n)]
 fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,vs,fs,3)
# Traditional rising comb and dropped butt, redesigned with broad faceted wood planes.
profile('WoodStock',[(-.203,.001),(-.053,.045),(-.025,.038),(-.041,-.020),(-.198,-.102)],.049,5,.0012)
profile('CurvedWoodWrist',[(-.047,.027),(-.026,.038),(.029,.064),(.035,.030),(.011,.019),(-.001,-.002),(-.010,-.034),(-.031,-.034),(-.042,-.019)],.034,5,.0007)
profile('ButtPad',[(-.211,.001),(-.203,.004),(-.198,-.102),(-.206,-.107)],.051,4,.0007)
for side in [-1,1]:
 profile('StockSideInset',[(-.190,-.008),(-.058,.031),(-.044,.025),(-.052,-.012),(-.188,-.087)],.0006,6,x=side*.0247)
 profile('StockCombAccent',[(-.176,.002),(-.061,.036),(-.055,.031),(-.174,-.003)],.0005,5,x=side*.0251)
# The squared double step above the wrist is the main Stevens-style cue.
profile('SteppedReceiver',[(.020,.023),(.020,.066),(.029,.082),(.088,.082),(.088,.077),(.156,.077),(.161,.084),(.177,.084),(.185,.075),(.185,.018),(.075,.018),(.060,.014),(.040,.014),(.030,.025)],.043,7,.0007)
box('ReceiverFrontCollar',.172,.193,.016,.083,.046,0,.0006)
box('ReceiverUpperSaddle',.090,.154,.078,.081,.034,3)
for side in [-1,1]:
 profile('ReceiverLowerStep',[(.042,.019),(.170,.019),(.170,.025),(.049,.025)],.0005,0,x=side*.0217)
 profile('RearJointBand',[(.023,.030),(.029,.069),(.034,.074),(.036,.025)],.0006,4,x=side*.0218)
 pin('ReceiverPin',.068,.037,side*.0221)
box('EjectionInset',.094,.151,.049,.071,.0005,4,x=.0218)
box('BoltFace',.098,.147,.052,.068,.0005,3,x=.0221)
profile('BoltHandle',[(.142,.050),(.157,.049),(.160,.045),(.157,.041),(.147,.042)],.006,0,x=.024)
# Thin steel barrel and lower magazine tube remain distinct in the silhouette.
tube('HollowLongBarrel',.181,.767,.073,.013,0,bore=.0085)
tube('MagazineTube',.183,.568,.0493,.010,7)
tube('TubeFrontCap',.559,.580,.0493,.011,0)
box('BarrelTubeBridge',.548,.559,.0483,.067,.012,0)
box('PumpActionBar',.180,.459,.0393,.0443,.0025,3,x=-.013)
profile('FrontSight',[(.742,.084),(.751,.084),(.751,.089),(.747,.090)],.006,3)
# Connected open guard and hooked trigger; no detached upper joints.
ring('TriggerGuard',[(.038,.022),(.092,.022),(.098,.006),(.093,-.014),(.080,-.025),(.053,-.023),(.040,-.010),(.034,.006)],[(.046,.014),(.085,.014),(.090,.004),(.086,-.009),(.077,-.017),(.057,-.015),(.047,-.006),(.042,.005)],.014,0)
profile('Trigger',[(.065,.022),(.071,.022),(.069,.004),(.074,-.006),(.070,-.010),(.062,.001)],.007,3)
# Hollow fore-end with broad shallow grooves, genuinely separate for pumping.
cross=[(-.018,.0283),(.018,.0283),(.024,.0343),(.024,.0545),(.018,.0602),(-.018,.0602),(-.024,.0545),(-.024,.0343)]
ys=[.255,.263,.283,.286,.317,.320,.351,.354,.385,.388,.419,.422,.451,.459]
vs=[];fs=[];colors=[]
for index,y in enumerate(ys):
 scale=.94 if index in [0,len(ys)-1] else (.985 if index in [2,3,4,5,6,7,8,9,10,11] else 1)
 vs.extend((x*scale,y,.0483+(z-.0483)*scale) for x,z in cross)
for k in range(len(ys)-1):
 for i in range(8):
  j=(i+1)%8;fs.append((k*8+i,k*8+j,(k+1)*8+j,(k+1)*8+i));colors.append(6 if k in [2,4,6,8,10] else 5)
outer_end=(len(ys)-1)*8;inner0=len(vs)
for y in [ys[0],ys[-1]]:vs.extend((math.cos((i+.5)*math.tau/8)*.0108,y,.0493+math.sin((i+.5)*math.tau/8)*.0108) for i in range(8))
for i in range(8):
 j=(i+1)%8;fs.extend([(inner0+i,inner0+8+i,inner0+8+j,inner0+j),(i,inner0+i,inner0+j,j),(outer_end+i,outer_end+j,inner0+8+j,inner0+8+i)]);colors.extend([6,6,6])
mesh('WoodPumpWithOpenTubeChannel',vs,fs,kind='Pump',tiles=colors)
def join(objects,name,pivot):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 if len(objects)>1:bpy.ops.object.join()
 o=bpy.context.object;o.name=name
 for v in o.data.vertices:v.co-=pivot
 o.parent=root;o.location=pivot
 for poly in o.data.polygons:poly.material_index=0
 while len(o.data.materials)>1:o.data.materials.pop(index=len(o.data.materials)-1)
 return o
base=join(parts['Base'],'Shotgun_V2_Base',Vector((0,0,0)))
pump=join(parts['Pump'],'Shotgun_V2_Pump',Vector((0,.356,.0483)));pump['role']='Independent fore-end; reference pumping travel local Y -55mm'
markers={'RightHandGrip':(0,0,0),'LeftHandGuide':(0,.356,.0483),'Muzzle':(0,.767,.073),'AimReference':(0,.740,.089),'RecoilPivot':(0,0,0),'HolsterAttach':(0,0,0),'Grip_Point':(0,0,0),'Support_Hand_Point':(0,.356,.0483),'Muzzle_Point':(0,.767,.073),'ReloadPort':(.0225,.123,.060),'PumpReference':(0,.356,.0483)}
for name,pos in markers.items():
 o=bpy.data.objects.new(name,None);c.objects.link(o);o.parent=root;o.location=pos;o.empty_display_type='ARROWS';o.empty_display_size=.014
bpy.context.view_layer.update();meshes=[base,pump];points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices];topology={}
for o in meshes:
 o.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(o.data)
 topology[o.name]={'triangles':len(o.data.loop_triangles),'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'signed_volume':bm.calc_volume(signed=True)};bm.free()
report={'name':'Shotgun_Stylized_V2','status':'Pending','dimensions_m':{'width':max(p.x for p in points)-min(p.x for p in points),'length':max(p.y for p in points)-min(p.y for p in points),'height':max(p.z for p in points)-min(p.z for p in points)},'triangles':sum(t['triangles'] for t in topology.values()),'meshes':2,'materials':1,'texture':[64,64],'palette_srgb':palette,'markers':markers,'topology':topology,'reference_url':'https://sketchfab.com/3d-models/low-poly-stevens-model-520a-275af36ee49545f3bdf117329f72745f','reference_note':'Original geometry inspired by supplied image; online page returned 403','workflow':'55mm independent pump; markers for later aim/recoil/reload/holster; no Action or runtime edits'}
assert report['triangles']<=1400,report['triangles']
assert all(t['nonmanifold_edges']==0 and t['signed_volume']>0 for t in topology.values()),topology
bpy.ops.object.select_all(action='DESELECT')
for o in c.objects:o.select_set(True)
bpy.context.view_layer.objects.active=base
bpy.ops.export_scene.gltf(filepath=str(HERE/'Shotgun_Stylized_V2.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
s['asset_report']=json.dumps(report);s['review_status']='Pending'
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
   sp.region_3d.view_location=(0,.28,.0);sp.region_3d.view_distance=1.15;sp.region_3d.view_rotation=Vector((3,-.3,.4)).to_track_quat('Z','Y');sp.region_3d.view_perspective='ORTHO'
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
(HERE/'asset_report.json').write_text(json.dumps(report,indent=2));print('SHOTGUN_BUILT',json.dumps(report))
