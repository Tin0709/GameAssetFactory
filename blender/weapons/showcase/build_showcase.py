"""Manifest-driven build. Sources are read-only; existing showcase is backed up."""
import bpy,json,sys,hashlib,shutil,datetime,atexit,math
from pathlib import Path
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE));import gaf_weapon_library as lib
from library_safety import UpdateLock
if not globals().get('_WEAPON_LOCK_HELD',False):
 update_lock=UpdateLock(HERE).acquire();atexit.register(update_lock.release)
TARGET=HERE/'Weapon_Showcase.blend';MANIFEST=HERE/'weapon_manifest.json'
initial_target_hash=hashlib.sha256(TARGET.read_bytes()).hexdigest() if TARGET.exists() else None
initial_manifest_hash=hashlib.sha256(MANIFEST.read_bytes()).hexdigest() if MANIFEST.exists() else None
TMP=ROOT/'.validation/weapon_showcase_v2';TMP.mkdir(parents=True,exist_ok=True)
if TARGET.exists():
 backup=TMP/('backup_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));backup.mkdir()
 for p in [TARGET,MANIFEST]:
  if p.exists():shutil.copy2(p,backup/p.name)

def capture_fits():
 source=ROOT/'blender/characters/player/cuboid/player_weapon_stow_r13_upper_back_review.blend'
 before=hashlib.sha256(source.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(source))
 snapshots={};fit={};report={}
 for kind in ['Pistol','Rifle','Shotgun']:
  print('CAPTURE',kind,flush=True)
  rig=bpy.data.objects['R13_'+kind+'_Rig'];mesh=next(o for o in bpy.data.objects if o.type=='MESH' and o.parent==rig and o.name.endswith('Author_Mesh'))
  root=next(o for o in bpy.data.objects if o.type=='EMPTY' and 'Stow_'+kind in o.name and o.name.endswith(('Blocky_Root','Blocky_Pistol_Root','Blocky_Shotgun_Root')))
  scene=next(s for s in bpy.data.scenes if rig.name in s.objects);bpy.context.window.scene=scene
  report[kind]={'scene':scene.name,'rig':rig.name,'mesh':mesh.name,'action':rig.animation_data.action.name,'groups':[g.name for g in mesh.vertex_groups], 'group_vertices':{g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.5 for w in v.groups)] for g in mesh.vertex_groups}}
  for mode,frame in [('READY',1),('HOLSTER',62)]:
   print('SNAPSHOT',kind,mode,frame,flush=True)
   scene.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
   evaluated=mesh.evaluated_get(dg);data=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=dg)
   print('MESH_CAPTURED',len(data.vertices),flush=True)
   # Retain shape/materials, strip scene presentation placement by rig world matrix.
   transform=rig.matrix_world.inverted()@evaluated.matrix_world
   for v in data.vertices:v.co=transform@v.co
   data.name='FIT_'+kind+'_'+mode;data.use_fake_user=True
   snapshots[(kind,mode)]=data
   fit[kind+'_'+mode]=[list(row) for row in rig.matrix_world.inverted()@root.matrix_world]
   report[kind][mode]={'frame':frame,'mount':fit[kind+'_'+mode],'bones':{n:[list(r) for r in rig.matrix_world.inverted()@rig.matrix_world@rig.pose.bones[n].matrix] for n in ['Head','Arm.R','Arm.L','Chest'] if n in rig.pose.bones}}
 # Save a tiny static intermediate; no Actions or rig imported into the final showcase.
 staging=bpy.data.scenes.new('FIT_SNAPSHOTS')
 for (kind,mode),data in snapshots.items():
  o=bpy.data.objects.new(data.name,data);staging.collection.objects.link(o)
 print('WRITING_FITS',flush=True)
 # libraries.write(scene) crashes Blender 5.2 on evaluated snapshot meshes.
 # Save a temporary duplicate normally; final build appends only six static meshes.
 bpy.context.window.scene=staging
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(TMP/'static_fits.blend'))
 (TMP/'fit_inspection.json').write_text(json.dumps(report,indent=2))
 assert hashlib.sha256(source.read_bytes()).hexdigest()==before
 return fit
fit=capture_fits()
bpy.ops.wm.read_factory_settings(use_empty=True);lib.register();s=bpy.context.scene;s.name='WEAPON_SHOWCASE';s.unit_settings.system='METRIC'
with bpy.data.libraries.load(str(TMP/'static_fits.blend'),link=False) as (src,dst):dst.meshes=[n for n in src.meshes if n.startswith('FIT_')]
for me in dst.meshes:
 kind,mode=me.name.split('_')[1:3];c=bpy.data.collections.new('FIT_'+kind+'_'+mode);s.collection.children.link(c);c['fit_kind']=kind;c['fit_mode']=mode
 o=bpy.data.objects.new(me.name,me);c.objects.link(o);c.hide_viewport=c.hide_render=True
for k,matrix in fit.items():s['fit_'+k]=matrix

if MANIFEST.exists():spec=json.loads(MANIFEST.read_text())['weapons']
else:
 spec=[]
 for kind,folder,stem in [('Rifle','m4a1_blocky','m4a1_blocky'),('Pistol','pistol','blocky_pistol'),('Shotgun','shotgun','blocky_shotgun')]:
  for v in range(1,5):spec.append({'id':kind.lower()+'_v'+str(v),'label':kind+' — '+('Original V1' if v==1 else 'Legacy V'+str(v)),'kind':kind,'source':f'blender/weapons/{folder}/{stem}_v{v}.blend','status':'Pending','status_note':'Preserved historical asset; no individual model approval inferred.'})
  spec.append({'id':kind.lower()+'_production_r13','label':kind+' — Production R13','kind':kind,'source':'game_mobile_3d/assets/characters/r13/'+kind.lower()+'.glb','status':'Approved','status_note':'Existing approved geometry/mounts per player_weapon_socket_r13.gd; status applies only to this preserved production model.'})
 spec.insert(5,{'id':'rifle_stylized_v2','label':'Rifle — Stylized V2','kind':'Rifle','source':'blender/weapons/rifle_stylized_v2/Rifle_Stylized_V2.blend','status':'Pending','status_note':'New original asset; awaiting explicit visual approval.'})
for entry in spec:
 if entry['id']=='rifle_stylized_v2':
  # Latest brief asks for a nearly horizontal back carry. Original source/production
  # actually uses 55 degrees; retain that on original entries, trial 10 only on V2.
  angle=math.radians(10);co=math.cos(angle);si=math.sin(angle)
  entry['holster_preview_matrix']=[[0,1.05*co,1.05*si,0],[-.8925,0,0,.24],[0,-1.05*si,1.05*co,1.02],[0,0,0,1]]
  entry['holster_preview_note']='Pending 10-degree horizontal back fit, as requested; original production 55-degree mount preserved separately.'
 source=ROOT/entry['source'];digest=hashlib.sha256(source.read_bytes()).hexdigest()
 if entry.get('source_sha256'):assert entry['source_sha256']==digest,('Source changed; inspect before refresh',entry['source'])
 collection=bpy.data.collections.new('WEAPON_'+entry['id']);s.collection.children.link(collection);collection['weapon_entry']=entry['id'];entry['collection']=collection.name
 if source.suffix=='.blend':
  with bpy.data.libraries.load(str(source),link=False) as (src,dst):
   assert 'WEAPON_EXPORT' in src.collections,entry['source'];dst.collections=['WEAPON_EXPORT']
  old=dst.collections[0];obs=list(old.all_objects)
  for ob in obs:collection.objects.link(ob)
  bpy.data.collections.remove(old)
 else:
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(source));obs=list(set(bpy.data.objects)-before)
  for ob in obs:
   for c in list(ob.users_collection):c.objects.unlink(ob)
   collection.objects.link(ob)
 roots=[o for o in obs if o.parent not in obs]
 if len(roots)>1:
  wrapper=bpy.data.objects.new(entry['id']+'_GripRoot',None);collection.objects.link(wrapper)
  for ob in roots:
   world=ob.matrix_world.copy();ob.parent=wrapper;ob.matrix_world=world
  obs.append(wrapper);roots=[wrapper]
 assert len(roots)==1,(entry,roots)
 root=roots[0];root['weapon_root']=True
 # All sources use a grip root; only preview parent transform is changed.
 root.matrix_world=Matrix.Identity(4)
 for ob in obs:ob.name=entry['id']+'__'+ob.name;ob.hide_render=False;ob.hide_viewport=False;ob.hide_set(False)
 entry['root']=root.name;entry['source_sha256']=digest
 collection.hide_viewport=collection.hide_render=True
assert not bpy.data.actions
manifest={'schema':1,'title':'GameAssetFactory Weapon Library','approval_policy':'New assets start Pending; explicit user approval only. Production is preserved separately.','weapons':spec}
s['weapon_manifest_snapshot']=json.dumps(manifest)
world=bpy.data.worlds.new('Neutral graphite studio');world.use_nodes=True;s.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.18,.21,1);world.node_tree.nodes['Background'].inputs[1].default_value=.5
studio=bpy.data.collections.new('PREVIEW_STUDIO');s.collection.children.link(studio)
for name,loc,power,size,color in [('Key',(2,-2,3),130,3,(.93,.96,1)),('Fill',(-2,-1,1.5),75,2,(.72,.82,1)),('Rim',(1,2,2),180,2,(1,.86,.68))]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.color=color
 o=bpy.data.objects.new(name,data);studio.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Weapon_Review_Camera',bpy.data.cameras.new('Weapon_Review_Camera'));studio.objects.link(cam);cam.data.type='ORTHO';s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True
s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=False
s.view_settings.view_transform='AgX'
lib.fill(s);s.gaf_weapon_index=next(i for i,e in enumerate(spec) if e['id']=='rifle_stylized_v2');lib.activate(s)
for image in bpy.data.images:
 if image.source=='FILE' and not image.packed_file:image.pack()
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   sp=area.spaces.active;sp.show_region_ui=True;sp.overlay.show_overlays=False;sp.shading.type='MATERIAL'
text=bpy.data.texts.new('START_HERE.txt');text.write('Open using Open_Weapon_Showcase.cmd to load Weapon Library reliably. N > Weapon Library. Select a weapon; choose standalone / ready / holster. Orbit normally. Direct opening retains all models in WEAPON_ collections. New assets remain Pending. Production and Animation_Showcase are unchanged. See README.md.')
# Compare again immediately before committing, including edits made outside this builder.
assert (hashlib.sha256(TARGET.read_bytes()).hexdigest() if TARGET.exists() else None)==initial_target_hash,'Showcase changed during build; preserving concurrent edits'
assert (hashlib.sha256(MANIFEST.read_bytes()).hexdigest() if MANIFEST.exists() else None)==initial_manifest_hash,'Manifest changed during build; preserving concurrent edits'
for e in spec:assert hashlib.sha256((ROOT/e['source']).read_bytes()).hexdigest()==e['source_sha256'],'Source changed during build: '+e['source']
staged=TMP/'Weapon_Showcase.staging.blend'
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(staged))
assert (hashlib.sha256(TARGET.read_bytes()).hexdigest() if TARGET.exists() else None)==initial_target_hash,'Showcase changed while saving staging file'
shutil.copy2(staged,TARGET)
MANIFEST.write_text(json.dumps(manifest,indent=2))
print('SHOWCASE_BUILT',len(spec),'entries; static fit only; zero Actions')
