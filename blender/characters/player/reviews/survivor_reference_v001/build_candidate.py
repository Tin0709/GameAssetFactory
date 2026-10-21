"""Pending skin/clothing review. Append the ORIGINAL V6 body/rig read-only.
Only requested external clothes are added; no base shape, neck, pose, Action or Godot changes.
"""
import bpy,math,json,sys,hashlib,struct
from pathlib import Path
from mathutils import Vector,Matrix
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
SOURCE=ROOT/'blender/characters/player/cuboid/player_cuboid_v6.blend'
FILE=OUT/'Survivor_Reference_v001.blend'
ARGS=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
if FILE.exists():
 with bpy.data.libraries.load(str(FILE),link=False) as (src,dst):dst.scenes=[src.scenes[0]]
 previous=dst.scenes[0]
 assert previous.get('review_status')=='Pending','Reviewed assets require a new candidate.'
 bpy.data.scenes.remove(previous)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.name='Survivor Skin Review — PENDING'
scene['review_status']='Pending';scene['candidate']='Survivor_Reference_v001'
scene['scope']='Original head/body/legs,3x12x4 slim arms,3D hair/clothes and contact shadows; Blender review only'
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.
asset=bpy.data.collections.new('ASSET — original body / new skin (Pending)');scene.collection.children.link(asset)
preview=bpy.data.collections.new('REVIEW — cameras and studio');scene.collection.children.link(preview)
refs=bpy.data.collections.new('REFERENCE — user sheet (viewport only)');scene.collection.children.link(refs)
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):
 dst.objects=['Player_Cuboid_Base','Player_Cuboid_Rig']
character=next(o for o in dst.objects if o.type=='MESH');rig=next(o for o in dst.objects if o.type=='ARMATURE')
for obj in [character,rig]:asset.objects.link(obj);obj.animation_data_clear()
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
character.name='Survivor_Reference_v001 — ORIGINAL BODY / NEW SKIN';rig.name='Original_V6_Rig — unchanged rest'

def geometry_signature(mesh):
 data=b''.join(struct.pack('<3f',*v.co) for v in mesh.vertices)
 data+=b''.join(struct.pack('<I',len(p.vertices))+struct.pack('<'+'I'*len(p.vertices),*p.vertices) for p in mesh.polygons)
 return hashlib.sha256(data).hexdigest()
original_geometry=geometry_signature(character.data)
original_rest={b.name:list(x for row in b.matrix_local for x in row) for b in rig.data.bones}
original_weights=[[(g.group,g.weight) for g in v.groups] for v in character.data.vertices]
# Restore the documented older slim-arm width:3x12x4 rather than4x12x4.
# Keep each inner shoulder face attached to the unchanged torso; only arm width
# and arm pivot X change. Head, torso, legs, arm length/depth and weights stay exact.
original_nonarm=[tuple(v.co) for v in character.data.vertices if not character.vertex_groups[v.groups[0].group].name.startswith('Arm.')]
for v in character.data.vertices:
 name=character.vertex_groups[v.groups[0].group].name
 if name.startswith('Arm.'):
  sign=1 if name.endswith('.L') else -1
  v.co.x=sign*.225+(v.co.x-sign*.225)*.75
character.data.update()
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for side,sign in [('L',1),('R',-1)]:
 b=rig.data.edit_bones['Arm.'+side];b.head.x=sign*.309375;b.tail.x=sign*.309375
bpy.ops.object.mode_set(mode='OBJECT')
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
adapted_geometry=geometry_signature(character.data)
assert original_nonarm==[tuple(v.co) for v in character.data.vertices if not character.vertex_groups[v.groups[0].group].name.startswith('Arm.')]
for b in rig.data.bones:
 if not b.name.startswith('Arm.'):assert original_rest[b.name]==list(x for row in b.matrix_local for x in row)

regions=json.loads((OUT/'atlas_regions.json').read_text())
image=bpy.data.images.load(str(OUT/'survivor_atlas.png'));image.name='Survivor — original hand-painted skin';image.pack()
material=bpy.data.materials.new('Survivor Skin — opaque / nearest');material.use_nodes=True
p=material.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.90
tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Closest';tex.extension='EXTEND';material.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
character.data.materials.clear();character.data.materials.append(material)
for old_uv in list(character.data.uv_layers):character.data.uv_layers.remove(old_uv)
uv=character.data.uv_layers.new(name='Survivor_Skin')
group_names=[g.name for g in character.vertex_groups]
body_bounds={}
for g in character.vertex_groups:
 pts=[v.co.copy() for v in character.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)]
 body_bounds[g.name]={'min':[min(v[i] for v in pts) for i in range(3)],'max':[max(v[i] for v in pts) for i in range(3)]}

def region_for(bone,n):
 if bone=='Head':
  if n.z>.5:return 'head_top'
  if n.z<-.5:return 'head_bottom'
  if n.y<-.5:return 'head_front'
  if n.y>.5:return 'head_back'
  return 'head_left' if n.x<0 else 'head_right'
 if bone=='Chest':
  if n.z>.5:return 'shirt_top'
  if n.z<-.5:return 'shirt_bottom'
  if n.y<-.5:return 'shirt_front'
  if n.y>.5:return 'shirt_back'
  return 'shirt_side'
 kind,side=bone.split('.')
 prefix=('arm_' if kind=='Arm' else 'leg_')+side+'_'
 if n.z>.5:return prefix+'top'
 if n.z<-.5:return prefix+'bottom'
 if n.y<-.5:return prefix+'front'
 if n.y>.5:return prefix+'back'
 return prefix+('side' if (n.x>0)==(side=='L') else 'inside')
for poly in character.data.polygons:
 bone=group_names[character.data.vertices[poly.vertices[0]].groups[0].group]
 bounds=body_bounds[bone];lo=Vector(bounds['min']);hi=Vector(bounds['max']);span=hi-lo
 tile=region_for(bone,poly.normal);x,y,w,h=regions[tile]
 for li in poly.loop_indices:
  co=character.data.vertices[character.data.loops[li].vertex_index].co
  if abs(poly.normal.z)>.5:
   u=(co.x-lo.x)/span.x;v=(co.y-lo.y)/span.y
  elif abs(poly.normal.y)>.5:
   u=(co.x-lo.x)/span.x if poly.normal.y<0 else (hi.x-co.x)/span.x
   v=(co.z-lo.z)/span.z
  else:
   u=(co.y-lo.y)/span.y if poly.normal.x>0 else (hi.y-co.y)/span.y
   v=(co.z-lo.z)/span.z
  uv.data[li].uv=((x+.02+u*(w-.04))/512,(512-y-h+.02+v*(h-.04))/512)
 poly.material_index=0;poly.use_smooth=False

# USER-REQUESTED EXCEPTIONS: lightweight external clothes, never reshape the base.
overlays=[]
def cloth_mesh(name,vertices,faces,bone,override=None,edge=None):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);asset.objects.link(obj);mesh.materials.append(material)
 group=obj.vertex_groups.new(name=bone);group.add(list(range(len(vertices))),1.,'REPLACE')
 texcoords=mesh.uv_layers.new(name='Survivor_Skin')
 lo=Vector(body_bounds[bone]['min']);hi=Vector(body_bounds[bone]['max']);span=hi-lo
 for poly in mesh.polygons:
  normal=poly.normal
  tile=override or (edge if edge and abs(normal.z)>.5 else region_for(bone,normal))
  x,y,w,h=regions[tile]
  for n,li in enumerate(poly.loop_indices):
   co=mesh.vertices[mesh.loops[li].vertex_index].co
   if override or (edge and abs(normal.z)>.5):u,v=[(0,0),(1,0),(1,1),(0,1)][n]
   elif abs(normal.z)>.5:u=(co.x-lo.x)/span.x;v=(co.y-lo.y)/span.y
   elif abs(normal.y)>.5:u=((co.x-lo.x) if normal.y<0 else (hi.x-co.x))/span.x;v=(co.z-lo.z)/span.z
   else:u=((co.y-lo.y) if normal.x>0 else (hi.y-co.y))/span.y;v=(co.z-lo.z)/span.z
   u=max(0,min(1,u));v=max(0,min(1,v))
   texcoords.data[li].uv=((x+.02+u*(w-.04))/512,(512-y-h+.02+v*(h-.04))/512)
  poly.use_smooth=False
 overlays.append(obj);return obj

def cloth_box(name,center,size,bone,edge):
 x,y,z=[v/2 for v in size];cx,cy,cz=center
 verts=[(cx+a*x,cy+b*y,cz+c*z) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 faces=[(0,1,5,4),(2,3,7,6),(1,2,6,5),(3,0,4,7),(4,5,6,7),(3,2,1,0)]
 return cloth_mesh(name,verts,faces,bone,edge=edge)

def ring(name,cx,cy,cz,inner_w,inner_d,thickness,height,bone,tile):
 verts=[]
 for z in [cz-height/2,cz+height/2]:
  for w,d in [(inner_w/2+thickness,inner_d/2+thickness),(inner_w/2,inner_d/2)]:
   verts += [(cx-w,cy-d,z),(cx+w,cy-d,z),(cx+w,cy+d,z),(cx-w,cy+d,z)]
 faces=[]
 for i in range(4):
  j=(i+1)%4
  faces.extend([(i,j,8+j,8+i),(4+j,4+i,12+i,12+j),(8+i,8+j,12+j,12+i),(j,i,4+i,4+j)])
 return cloth_mesh(name,verts,faces,bone,override=tile)

# A6mm shirt layer/hem and short sleeves, retaining original shoulder/waist heights.
cloth_box('Black shirt / thin external layer',(0,0,1.0125),(.462,.237,.675),'Chest','shirt3d_edge')
ring('Shirt lower hem',0,0,.686,.462,.237,.0035,.022,'Chest','shirt3d_edge')
for side,sign in [('L',1),('R',-1)]:
 cx=sign*.309375
 cloth_box('Black short sleeve '+side,(cx,0,1.2375),(.18075,.237,.225),'Arm.'+side,'shirt3d_edge')
 ring('Sleeve hem '+side,cx,0,1.134,.18075,.237,.003,.018,'Arm.'+side,'shirt3d_edge')
 ring('White forearm wrap '+side,cx,0,1.0125,.16875,.225,.010,.084375,'Arm.'+side,'wrap3d')
 ring('Black wrist band '+side,cx,0,.82265625,.16875,.225,.0075,.0703125,'Arm.'+side,'band3d')
 # Broad stepped fabric panels,6–10mm relief; no added bag or redesigned limb.
 lx=sign*.1125
 cloth_box('Raised upper trouser panel '+side,(lx,-.1175,.579),(.205,.010,.145),'Leg.'+side,'pants3d_edge')
 cloth_box('Raised knee fabric panel '+side,(lx,-.118,.348),(.212,.011,.158),'Leg.'+side,'pants3d_edge')
 cloth_box('Outer trouser fabric panel '+side,(lx+sign*.116,0,.574),(.007,.199,.142),'Leg.'+side,'pants3d_edge')
 ring('Trouser lower hem '+side,lx,0,.147,.225,.225,.005,.034,'Leg.'+side,'pants3d_edge')
bpy.ops.object.select_all(action='DESELECT')
for obj in overlays:obj.select_set(True)
bpy.context.view_layer.objects.active=overlays[0];bpy.ops.object.join();clothes=bpy.context.object
clothes.name='Survivor_Clothing_3D — requested outer relief'
for poly in clothes.data.polygons:poly.material_index=0
while len(clothes.data.materials)>1:clothes.data.materials.pop(index=len(clothes.data.materials)-1)
mod=clothes.modifiers.new('Original rigid bone weights','ARMATURE');mod.object=rig;clothes.parent=rig
clothes['scope']='Requested3D shirt / white-black arm rings / trouser relief only'
clothes.data.calc_loop_triangles()


# User-authorized3D hair, a rigid external layer around the unchanged head cube.
# Curated staggered locks define depth; no periodic columns or fine noise geometry.
CELL=.0375;BASE=1.35
fringe=[1.44,1.48,1.55,1.57,1.62,1.64,1.59,1.62,1.70,1.69,1.65,1.59,1.56,1.53,1.46,1.44]
front_locks=[(-.26,-.14,1.61,1.75),(-.17,-.055,1.68,1.81),(-.08,.06,1.74,1.82),(.04,.18,1.69,1.77),(.14,.27,1.55,1.68),(-.26,-.19,1.45,1.60),(-.14,-.065,1.57,1.68),(.02,.09,1.66,1.73),(.17,.26,1.73,1.80)]
back_locks=[(-.26,-.13,1.56,1.73),(-.14,.045,1.64,1.78),(.055,.22,1.51,1.68),(-.08,.08,1.43,1.61),(.13,.26,1.68,1.77),(-.25,-.15,1.42,1.52),(-.20,-.035,1.77,1.83)]
side_locks=[(-.25,-.09,1.56,1.73),(-.08,.075,1.66,1.80),(.015,.19,1.49,1.66),(-.13,.025,1.43,1.59),(.12,.26,1.65,1.75)]
def lock_index(a,z,patches):
 for n,(a0,a1,z0,z1) in enumerate(patches):
  if a0<=a<=a1 and z0<=z<=z1:return n
 return -1
occupied=set()
for i in range(-8,8):
 for j in range(-8,8):
  x=(i+.5)*CELL;y=(j+.5)*CELL
  for k in range(15):
   z=BASE+(k+.5)*CELL
   top=1.870-.065*(abs(x)/.30)**2-.050*(abs(y)/.30)**2+.010*((i//2*7+j//2*11)%3-1)
   # Cover every corner of the original cubic head without modifying it.
   if abs(x)<.25 and abs(y)<.25:top=max(top,1.825)
   if z>top:continue
   hw=.30 if z<1.80 else .27;hd=.30 if z<1.80 else .27
   if abs(x)>hw or abs(y)>hd:continue
   if max(0,abs(x)-(hw-.075))+max(0,abs(y)-(hd-.075))>.09375:continue
   if z<1.79 and abs(x)<.19 and abs(y)<.19:continue
   if y<-.1875:
    if z<fringe[i+8]:continue
    outer=.294 if lock_index(x,z,front_locks)>=0 else .252
    if -y>outer:continue
   elif y>.1875:
    if z<1.397+.0375*((i//3)%3==0):continue
    outer=.294 if lock_index(x,z,back_locks)>=0 else .252
    if y>outer:continue
   else:
    shift=.018 if i>0 else 0.
    if z<1.425+.0375*((j//2+(1 if i>0 else 0))%4==0):continue
    outer=.294 if lock_index(y,z+shift,side_locks)>=0 else .252
    if abs(x)>outer:continue
   occupied.add((i,j,k))
verts=[];faces=[];tiles=[]
directions=[((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),((0,1,0),[(1,1,0),(0,1,0),(0,1,1),(1,1,1)]),((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),((-1,0,0),[(0,1,0),(0,0,0),(0,0,1),(0,1,1)]),((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)]),((0,0,-1),[(0,1,0),(1,1,0),(1,0,0),(0,0,0)])]
for i,j,k in sorted(occupied):
 x=(i+.5)*CELL;y=(j+.5)*CELL;z=BASE+(k+.5)*CELL
 for direction,corners in directions:
  if (i+direction[0],j+direction[1],k+direction[2]) in occupied:continue
  first=len(verts);verts.extend([((i+a)*CELL,(j+b)*CELL,BASE+(k+c)*CELL) for a,b,c in corners]);faces.append(tuple(range(first,first+4)))
  which=lock_index(x,z,front_locks if y<0 else back_locks) if abs(direction[1]) else lock_index(y,z,side_locks)
  tone=(which*5+1)%6 if which>=0 else ((i-k//2)//2*7+j//2*3+k//2)%6
  tiles.append('hair3d_'+str(tone))
mesh=bpy.data.meshes.new('Soldier / staggered voxel hair');mesh.from_pydata(verts,[],faces);mesh.update()
hair=bpy.data.objects.new('Survivor_Hair_3D — layered brown locks',mesh);asset.objects.link(hair);mesh.materials.append(material)
uvh=mesh.uv_layers.new(name='Survivor_Skin')
for poly,tile in zip(mesh.polygons,tiles):
 x,y,w,h=regions[tile]
 for li,(u,v) in zip(poly.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uvh.data[li].uv=((x+.02+u*(w-.04))/512,(512-y-h+.02+v*(h-.04))/512)
 poly.use_smooth=False
vg=hair.vertex_groups.new(name='Head');vg.add(list(range(len(mesh.vertices))),1.,'REPLACE')
mod=hair.modifiers.new('Rigid Head follow','ARMATURE');mod.object=rig;hair.parent=rig
hair['scope']='User-requested3D hair only; original head cube is unchanged';hair['hair_voxel_m']=CELL
mesh.calc_loop_triangles()

# Nothing below changes any body vertex, face, normal, bone or skin weight.
assert geometry_signature(character.data)==adapted_geometry
assert original_weights==[[(g.group,g.weight) for g in v.groups] for v in character.data.vertices]
assert all(original_rest[b.name]==list(x for row in b.matrix_local for x in row) for b in rig.data.bones if not b.name.startswith('Arm.'))
character['review_status']='Pending';character['skin_only']=False;character['original_body_unchanged']=False;character['non_arm_original_geometry_exact']=True;character['slim_arm_dimensions_m']=[.16875,.675,.225];character['no_neck_geometry']=True
character['body_geometry_sha256']=adapted_geometry;character['body_source']='blender/characters/player/cuboid/player_cuboid_v6.blend'
character['primary_reference_sha256']=hashlib.sha256((OUT/'primary_reference.png').read_bytes()).hexdigest()
asset.asset_mark();asset.asset_data.description='Pending skin and3D clothes on original V6 head/body/legs with documented3x12x4 slim arms; no neck/nose/mouth.'
asset['review_status']='Pending'
reference=bpy.data.images.load(str(OUT/'primary_reference.png'));reference.name='PRIMARY — supplied six-view character';reference.pack();reference.use_fake_user=True
ref=bpy.data.objects.new('PRIMARY REFERENCE — viewport only',None);refs.objects.link(ref);ref.empty_display_type='IMAGE';ref.data=reference;ref.empty_display_size=2.5;ref.location=(2,1,1);ref.hide_render=True;ref.hide_set(True)
notes=bpy.data.texts.new('START HERE — SKIN ONLY')
notes.write('PENDING / Survivor Reference v001\nOriginal V6 head/body/legs exact; older3x12x4 slim arms restored;48base vertices, no neck.\nNew skin plus user-requested3D clothing: white/black arm bands, black shirt and trouser relief.\nLarge eyes only; no nose/mouth. A separate3D brown hair layer surrounds the unchanged original head cube.\nNo new Action or Godot integration.\nCameras Front / Front_3Q / Left_Side / Back / Right_Side / Back_3Q.\nNumpad0: camera; F12: render. Images packed.\n')

def studio_mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=1
 return m
mesh=bpy.data.meshes.new('Studio plane');mesh.from_pydata([(-200,-200,-.001),(200,-200,-.001),(200,200,-.001),(-200,200,-.001)],[],[(0,1,2,3)]);mesh.update()
floor=bpy.data.objects.new('Review floor (not character)',mesh);preview.objects.link(floor);mesh.materials.append(studio_mat('Neutral studio',(.58,.56,.52)))
world=bpy.data.worlds.new('Soft studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.72,.76,.82,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
for name,loc,power,size in [('Key',(-3,-4,5),420,4),('Fill',(3,-2,3),120,3),('Rim',(1,3,4),240,3)]:
 data=bpy.data.lights.new('Studio '+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
 obj=bpy.data.objects.new('Studio '+name,data);preview.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
views={'Front':0,'Front_3Q':-32,'Left_Side':90,'Back':180,'Right_Side':-90,'Back_3Q':145}
for name,degrees in views.items():
 a=math.radians(degrees);data=bpy.data.cameras.new(name);data.type='ORTHO';data.ortho_scale=2.10
 camera=bpy.data.objects.new(name,data);preview.objects.link(camera);camera.location=(6*math.sin(a),-6*math.cos(a),1.53);camera.rotation_euler=(Vector((0,0,.92))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera=bpy.data.objects['Front_3Q']
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0.;scene.view_settings.gamma=1.
scene.render.film_transparent=False
bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT');character.select_set(True);bpy.context.view_layer.objects.active=character;rig.hide_set(True)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.region_3d.view_perspective='CAMERA';space.overlay.show_overlays=False;space.shading.type='MATERIAL'
  elif area.type=='PROPERTIES':area.spaces.active.context='OBJECT'
# Drop unused imported materials/images from the review copy; source remains read-only.
for m in list(bpy.data.materials):
 if m.users==0:bpy.data.materials.remove(m)
for im in list(bpy.data.images):
 if im.users==0 and not im.use_fake_user:bpy.data.images.remove(im)
scene['review_cameras']=json.dumps(list(views));scene['skin_only']=False;scene['original_body_unchanged']=False;scene['non_arm_original_geometry_exact']=True;scene['slim_arms']=True;scene['requested_clothing_relief']=True
bpy.ops.wm.save_as_mainfile(filepath=str(FILE),compress=True)
character.data.calc_loop_triangles()
report={'candidate':FILE.name,'status':'Pending','skin_only':False,'original_body_unchanged':False,'non_arm_original_geometry_exact':True,'slim_arm_dimensions_wld_m':[.16875,.675,.225],'slim_arm_reference':'blender/characters/player/cuboid/create_slim_arm_study.py (3x12x4)','vertices':len(character.data.vertices),'triangles':len(character.data.loop_triangles),'quads':len(character.data.polygons),'materials':len(character.data.materials),'bones':len(rig.data.bones),'actions':len(bpy.data.actions),'body_source_sha256':source_hash,'original_geometry_sha256':original_geometry,'body_geometry_sha256':adapted_geometry,'geometry_exact':False,'non_arm_geometry_exact':True,'non_arm_rest_skeleton_exact':True,'arm_pivots_seated_to_body':True,'weights_exact':True,'no_neck_geometry':True,'no_nose_or_mouth':True,'added_3d_clothing_only':True,'clothing_vertices':len(clothes.data.vertices),'clothing_triangles':len(clothes.data.loop_triangles),'clothing_parts':['Black shirt and short sleeves','White forearm wraps','Black wrist bands','Trouser fabric panels and hems'],'volumetric_hair':True,'hair_vertices':len(hair.data.vertices),'hair_triangles':len(hair.data.loop_triangles),'hair_style':'Curated staggered3D locks, dark warm brown palette','rigid_bounds_m':body_bounds,'packed_images':[im.name for im in bpy.data.images if im.packed_file],'review_cameras':list(views),'gameplay_integrated':False}
assert report['vertices']==48 and report['triangles']==72 and report['quads']==36 and report['actions']==0
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
(OUT/'model_validation.json').write_text(json.dumps(report,indent=2));print('MODEL_VALIDATION',json.dumps(report),flush=True)
(OUT/'renders').mkdir(exist_ok=True)
requested=ARGS[ARGS.index('--views')+1:] if '--views' in ARGS else list(views)
for view in requested:
 scene.camera=bpy.data.objects[view];scene.render.filepath=str(OUT/'renders'/f'{view}.png');bpy.ops.render.render(write_still=True);print('REVIEW_RENDER',view,flush=True)
scene.camera=bpy.data.objects['Front_3Q'];bpy.ops.wm.save_as_mainfile(filepath=str(FILE),compress=True)
