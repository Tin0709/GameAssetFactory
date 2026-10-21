"""Build ONLY this Pending model candidate; no existing asset or Action is opened.
Blender 5.2: blender --background --python build_candidate.py -- --views Front Front_3Q Left_Side Back
"""
import bpy,math,json,sys,random,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
OUT=Path(__file__).resolve().parent
ARGS=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
FILE=OUT/'Survivor_Reference_v001.blend'
# Never use the recipe to overwrite a candidate once its review status changes.
if FILE.exists():
 with bpy.data.libraries.load(str(FILE),link=False) as (src,dst):dst.scenes=[src.scenes[0]]
 previous=dst.scenes[0]
 assert previous.get('review_status')=='Pending','Approved/reviewed files need a new version.'
 bpy.data.scenes.remove(previous)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.name='Survivor Reference — PENDING'
scene['review_status']='Pending';scene['candidate']='Survivor_Reference_v001'
scene['scope']='Model review only — no gameplay integration or animation changes'
scene['primary_reference']='primary_reference.png';scene['facing']='-Y, Z up; X+ anatomical left'
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.
asset=bpy.data.collections.new('ASSET — Survivor Reference v001 (Pending)');scene.collection.children.link(asset)
preview=bpy.data.collections.new('REVIEW — cameras / studio');scene.collection.children.link(preview)
refs=bpy.data.collections.new('REFERENCE — supplied sheet (viewport only)');scene.collection.children.link(refs)
regions=json.loads((OUT/'atlas_regions.json').read_text())
texture=bpy.data.images.load(str(OUT/'survivor_atlas.png'));texture.name='Survivor — Original Pixel Atlas 512';texture.pack()
material=bpy.data.materials.new('Survivor — Matte Voxel Atlas');material.use_nodes=True
nt=material.node_tree;shader=nt.nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.88
tex=nt.nodes.new('ShaderNodeTexImage');tex.image=texture;tex.interpolation='Closest';tex.extension='EXTEND'
nt.links.new(tex.outputs['Color'],shader.inputs['Base Color']);material.diffuse_color=(.15,.12,.10,1)
parts=[];pivots={}

FACE_INDICES=[(0,1,5,4),(2,3,7,6),(1,2,6,5),(3,0,4,7),(4,5,6,7),(3,2,1,0)]
def uvrect(name,u,v):
 x,y,w,h=regions[name]
 return ((x+.02+u*(w-.04))/512.,(512-y-h+.02+v*(h-.04))/512.)
def make_mesh(name,vertices,faces,tiles,group,uvs=None):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);asset.objects.link(obj);mesh.materials.append(material)
 uv=mesh.uv_layers.new(name='VoxelAtlas')
 for poly,tile in zip(mesh.polygons,tiles):
  coords=uvs[poly.index] if uvs else [(0,0),(1,0),(1,1),(0,1)]
  for loop,(u,v) in zip(poly.loop_indices,coords):uv.data[loop].uv=uvrect(tile,u,v)
  poly.use_smooth=False
 vg=obj.vertex_groups.new(name=group);vg.add(list(range(len(vertices))),1.,'REPLACE')
 obj['rigid_part']=group;parts.append(obj);return obj

def box(name,center,size,tile,group,transform=None,crop=None):
 x,y,z=[v/2 for v in size]
 vertices=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
 vertices=[Vector(v)+Vector(center) for v in vertices]
 if transform is not None:vertices=[transform@v for v in vertices]
 tiles=[tile]*6 if isinstance(tile,str) else tile
 uvs=None
 if crop:
  a,b,c,d=crop;uvs=[[(a,b),(c,b),(c,d),(a,d)]]*6
 return make_mesh(name,vertices,FACE_INDICES,tiles,group,uvs)

# Large cubic face; the head and all layered hair remain one rigid Head part.
box('Head / simple voxel face',(0,0,1.5475),(.438,.406,.375),['face','skin_side','skin_side','skin_side','skin_side','skin_side'],'Head')
box('Neck / joined collar',(0,0,1.352),(.145,.175,.060),'neck','Neck')
box('Charcoal short-sleeve shirt',(0,0,1.065),(.430,.255,.540),['shirt_front','shirt_back','shirt_side','shirt_side','shirt_side','shirt_side'],'Chest')

# Straight solid limbs, slight reference A-stance. Bind transforms are baked.
for side,sign in [('L',1),('R',-1)]:
 pivot=Vector((sign*.296,0,1.327));rot=Matrix.Rotation(math.radians(-sign*5),4,'Y');T=Matrix.Translation(pivot)@rot
 pivots['Arm.'+side]=(pivot,T@Vector((0,0,-.645)))
 box('Straight arm '+side,(0,0,-.329),(.153,.181,.642),['skin','skin','skin','skin','skin','skin'],'Arm.'+side,T)
 box('Short sleeve '+side,(0,0,-.101),(.177,.209,.226),'sleeve','Arm.'+side,T)
 box('Light forearm wrap '+side,(0,0,-.310),(.177,.205,.076),'wrap','Arm.'+side,T)
 box('Dark wrist band '+side,(0,0,-.478),(.164,.192,.066),'band','Arm.'+side,T)
 box('Block hand '+side,(0,0,-.591),(.157,.187,.128),'hand','Arm.'+side,T)

for side,sign in [('L',1),('R',-1)]:
 pivot=Vector((sign*.104,0,.812));T=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(-sign*5),4,'Y')
 front='pants_'+side+'_front';back='pants_'+side+'_back';edge='pants_'+side+'_side'
 box('Straight rugged trouser leg '+side,(0,0,-.345),(.190,.239,.690),[front,back,edge,edge,edge,edge],'Leg.'+side,T)
 # Broad, almost-flush fabric panels already visible in the reference clothing.
 box('Thigh fabric panel '+side,(0,-.123,-.103),(.178,.010,.151),front,'Leg.'+side,T,crop=(.03,.73,.97,.95))
 box('Worn knee fabric panel '+side,(0,-.124,-.407),(.183,.011,.169),front,'Leg.'+side,T,crop=(.02,.29,.98,.54))
 end=T@Vector((0,0,-.69));pivots['Leg.'+side]=(pivot,end)
 # Flat-soled stepped boots, toe extending forward; no floating support corners.
 x=end.x
 box('Boot sole '+side,(x,-.035,.027),(.224,.321,.054),'sole','Leg.'+side)
 box('Boot toe and upper '+side,(x,-.042,.079),(.213,.300,.066),'boot_toe','Leg.'+side)
 box('Boot ankle '+side,(x,.003,.124),(.199,.236,.078),'boot_collar','Leg.'+side)

# A closed, face-culled voxel shell: coarse staggered locks, not a noise-displaced sphere.
CELL=.035;BASE=1.365
fringe=[1.45,1.48,1.55,1.57,1.62,1.64,1.59,1.62,1.70,1.69,1.65,1.59,1.56,1.53,1.46,1.44]
occupied=set()
for i in range(-8,8):
 for j in range(-8,8):
  x=(i+.5)*CELL;y=(j+.5)*CELL
  lock=(i//2*13+j//2*7)%5
  for k in range(15):
   z=BASE+(k+.5)*CELL
   top=1.850-.115*(abs(x)/.29)**2-.090*(abs(y)/.28)**2+.012*((i//2*7+j//2*11)%3-1)
   # Cut corners/upper silhouette in broad steps, with a few controlled crown tufts.
   hw=.290 if z<1.765 else .260
   hd=.290 if z<1.78 else .260
   if z<1.54:hw=.269;hd=.263
   if z>top or abs(x)>hw or abs(y)>hd:continue
   if max(0,abs(x)-(hw-.070))+max(0,abs(y)-(hd-.070))>.085:continue
   if z<1.754 and abs(x)<.205 and abs(y)<.189:continue
   if y<-.180:
    bottom=fringe[i+8]
    if z<bottom:continue
    # Two staggered shingle depths keep the fringe visibly layered in side view.
    outer=.244+(.029 if ((i-2*(k//3))//3+k//3)%3==0 else 0)
    if -y>outer:continue
   elif y>.17:
    bottom=1.401+.035*((i//3)%3==0)
    if z<bottom:continue
    if y>.237 and ((i+k//2)//3+k//3)%3==1:continue
   else:
    bottom=1.431+.035*((j//2+(1 if i>0 else 0))%4==0)
    if z<bottom:continue
    if abs(x)>.25 and ((j-2*(k//3))//3+k//3)%3==2:continue
   occupied.add((i,j,k))
# Only exposed quads; no duplicate interior cube faces.
verts=[];faces=[];tiles=[]
DIRECTIONS=[((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),((0,1,0),[(1,1,0),(0,1,0),(0,1,1),(1,1,1)]),((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),((-1,0,0),[(0,1,0),(0,0,0),(0,0,1),(0,1,1)]),((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)]),((0,0,-1),[(0,1,0),(1,1,0),(1,0,0),(0,0,0)])]
for i,j,k in sorted(occupied):
 for direction,corners in DIRECTIONS:
  if (i+direction[0],j+direction[1],k+direction[2]) in occupied:continue
  n=len(verts)
  verts.extend([((i+a)*CELL,(j+b)*CELL,BASE+(k+c)*CELL) for a,b,c in corners]);faces.append(tuple(range(n,n+4)))
  # Shared color across adjacent cells forms locks larger than a single voxel.
  shade=((i-k//2)//2*7+(j+k//3)//2*11+k//2*5)%12
  tiles.append('hair'+str(shade))
hair=make_mesh('Layered chunky brown hair',verts,faces,tiles,'Head')
hair['cell_m']=CELL;hair['occupied_cells']=len(occupied);hair['exposed_quads']=len(faces)

# Join into one skinnable mesh with rigid groups; six body blocks remain unbent.
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();character=bpy.context.object
character.name='Survivor_Reference_v001 — PENDING';character.data.name='Survivor — rigid voxel surfaces'
# Merge shared voxel corners; preserve hard normals and per-loop UV islands.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.00001);bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
# Single shared atlas material slot after join.
for poly in character.data.polygons:poly.material_index=0
while len(character.data.materials)>1:character.data.materials.pop(index=len(character.data.materials)-1)
arm=bpy.data.armatures.new('Survivor — rigid base skeleton');rig=bpy.data.objects.new('Survivor_Rig — no Actions',arm);asset.objects.link(rig)
bpy.context.view_layer.objects.active=rig;character.select_set(False);rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
 b=arm.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=arm.edit_bones[parent]
 return b
bone('Root',(0,0,0),(0,0,.15)).use_deform=False
bone('Hips',(0,0,.81),(0,0,.95),'Root');bone('Spine',(0,0,.95),(0,0,1.10),'Hips');bone('Chest',(0,0,1.10),(0,0,1.32),'Spine')
bone('Neck',(0,0,1.32),(0,0,1.37),'Chest');bone('Head',(0,0,1.37),(0,0,1.74),'Neck')
for name,(head,tail) in pivots.items():bone(name,head,tail,'Chest' if name.startswith('Arm') else 'Hips')
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True;arm.display_type='STICK';rig.hide_render=True
mod=character.modifiers.new('Rigid base weights — future rigging','ARMATURE');mod.object=rig;character.parent=rig
character['review_status']='Pending';character['gameplay_integrated']=False
character['reference_sha256']=hashlib.sha256((OUT/'primary_reference.png').read_bytes()).hexdigest()
character.asset_mark();character.asset_data.description='Pending model review: young brown-haired voxel survivor, exact supplied sheet primary target.'

# Original reference is embedded and kept out of rendered/model-only collections.
reference=bpy.data.images.load(str(OUT/'primary_reference.png'));reference.name='PRIMARY — user character reference';reference.pack();reference.use_fake_user=True
empty=bpy.data.objects.new('PRIMARY REFERENCE — supplied six-view sheet',None);refs.objects.link(empty);empty.empty_display_type='IMAGE';empty.data=reference;empty.empty_display_size=2.5;empty.location=(2,1,1);empty.hide_render=True;empty.hide_set(True)
notes=bpy.data.texts.new('REVIEW — START HERE')
notes.write('Survivor Reference v001 | PENDING | MODEL ONLY\nPrimary target: embedded user six-view sheet.\nNumpad0: active camera. Cameras Front / Front_3Q / Left_Side / Back / Right_Side / Back_3Q.\nF12 re-renders the active camera. Render folder contains matching orthographic views.\nOne atlas / one rigid mesh /10-bone base skeleton. No Actions; no Godot integration.\nReference images are embedded. Existing assets are never opened by this recipe.\n')

def studio_mat(name,color,rough=1):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 return m
# Large seamless warm-grey studio floor and soft directional contact shadows.
mesh=bpy.data.meshes.new('Studio plane');mesh.from_pydata([(-200,-200,-.001),(200,-200,-.001),(200,200,-.001),(-200,200,-.001)],[],[(0,1,2,3)]);mesh.update()
floor=bpy.data.objects.new('Review floor (not character)',mesh);preview.objects.link(floor);mesh.materials.append(studio_mat('Warm neutral studio',(.58,.56,.52)))
world=bpy.data.worlds.new('Soft studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.72,.76,.82,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
for name,loc,power,size in [('Key',(-3,-4,5),420,4),('Fill',(3,-2,3),120,3),('Rim',(1,3,4),240,3)]:
 data=bpy.data.lights.new('Studio '+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
 obj=bpy.data.objects.new('Studio '+name,data);preview.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
view_angles={'Front':0,'Front_3Q':-32,'Left_Side':90,'Back':180,'Right_Side':-90,'Back_3Q':145}
for name,deg in view_angles.items():
 a=math.radians(deg);data=bpy.data.cameras.new(name);data.type='ORTHO';data.ortho_scale=2.16
 camera=bpy.data.objects.new(name,data);preview.objects.link(camera);camera.location=(6*math.sin(a),-6*math.cos(a),1.60)
 camera.rotation_euler=(Vector((0,0,.955))-camera.location).to_track_quat('-Z','Y').to_euler();data.lens=60
scene.camera=bpy.data.objects['Front_3Q']
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0.;scene.view_settings.gamma=1.
scene.render.film_transparent=False
# Friendly initial review view, solid/material mode; no rig overlays obscuring the face.
bpy.ops.object.select_all(action='DESELECT');character.select_set(True);bpy.context.view_layer.objects.active=character
rig.hide_set(True)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.region_3d.view_perspective='CAMERA';space.overlay.show_overlays=False;space.shading.type='MATERIAL'
  elif area.type=='PROPERTIES':area.spaces.active.context='OBJECT'
scene['review_cameras']=json.dumps(list(view_angles));scene['texture_filter']='Closest / opaque / hand-authored palette'
bpy.ops.wm.save_as_mainfile(filepath=str(FILE),compress=True)
# Essential model correctness checks, no animation or gameplay experiments.
character.data.calc_loop_triangles()
mins=[min(v.co[a] for v in character.data.vertices) for a in range(3)];maxs=[max(v.co[a] for v in character.data.vertices) for a in range(3)]
unweighted=sum(1 for v in character.data.vertices if len(v.groups)!=1 or abs(sum(g.weight for g in v.groups)-1)>1e-6)
report={'candidate':FILE.name,'status':scene['review_status'],'vertices':len(character.data.vertices),'triangles':len(character.data.loop_triangles),'materials':len(character.data.materials),'bones':len(arm.bones),'actions':len(bpy.data.actions),'unweighted_or_nonrigid_vertices':unweighted,'bounds_min':mins,'bounds_max':maxs,'height_m':maxs[2]-mins[2],'packed_images':[im.name for im in bpy.data.images if im.packed_file],'cameras':list(view_angles),'source_reference_sha256':character['reference_sha256'],'gameplay_integrated':False}
assert unweighted==0 and len(bpy.data.actions)==0 and len(character.data.materials)==1
assert abs(mins[2])<1e-5 and report['triangles']<7000
(OUT/'model_validation.json').write_text(json.dumps(report,indent=2));print('MODEL_VALIDATION',json.dumps(report),flush=True)
(OUT/'renders').mkdir(exist_ok=True)
views=ARGS[ARGS.index('--views')+1:] if '--views' in ARGS else list(view_angles)
for view in views:
 scene.camera=bpy.data.objects[view];scene.render.filepath=str(OUT/'renders'/f'{view}.png');bpy.ops.render.render(write_still=True);print('REVIEW_RENDER',view,flush=True)
# Save with the useful three-quarter camera after rendering all other views.
scene.camera=bpy.data.objects['Front_3Q'];bpy.ops.wm.save_as_mainfile(filepath=str(FILE),compress=True)
