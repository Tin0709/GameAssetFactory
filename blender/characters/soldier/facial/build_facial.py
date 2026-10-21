"""Add one original Pending facial system inside the existing Soldier library."""
from pathlib import Path
import bpy,sys,json,math,hashlib,uuid
from mathutils import Vector,Matrix
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));import expression_model as model;import face_blender as fb
R=D.parents[3];LIB=D.parent/'showcase/SOLDIER_Asset_Library.blend';bpy.ops.wm.open_mainfile(filepath=str(LIB),load_ui=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];bpy.context.window.scene=scene

def digest(obj):
 d={'matrix':[list(r) for r in obj.matrix_local],'type':obj.type,'parent':obj.parent.name if obj.parent else None}
 if obj.type=='MESH':d.update(v=[list(v.co) for v in obj.data.vertices],f=[list(p.vertices) for p in obj.data.polygons],uv=[[list(t.uv) for t in uv.data] for uv in obj.data.uv_layers],weights=[[(g.group,g.weight) for g in v.groups] for v in obj.data.vertices],groups=[g.name for g in obj.vertex_groups],materials=[m.name for m in obj.data.materials])
 elif obj.type=='ARMATURE':d['bones']={b.name:[list(r) for r in b.matrix_local] for b in obj.data.bones}
 return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
# On a rerun, remove only our own Pending facial review data, never existing assets.
protected={o.name:digest(o) for o in bpy.data.objects if not o.name.startswith('SF_')};prior_actions={a.name:len(list(fb.curves(a))) for a in bpy.data.actions if not a.get('soldier_facial')}
old=bpy.data.collections.get('SOLDIER_Facial_Expressions_PENDING')
if old:assert old.get('review_status')=='Pending'
if 'Facial Expressions' in scene.view_layers:scene.view_layers.remove(scene.view_layers['Facial Expressions'])
for obj in list(bpy.data.objects):
 if obj.name.startswith('SF_'):bpy.data.objects.remove(obj,do_unlink=True)
if old:bpy.data.collections.remove(old)
for action in list(bpy.data.actions):
 if action.get('soldier_facial'):bpy.data.actions.remove(action)
for group in [bpy.data.meshes,bpy.data.armatures,bpy.data.materials,bpy.data.images,bpy.data.cameras]:
 for data in list(group):
  if data.name.startswith('SF_') and data.users==0:group.remove(data)
asset=bpy.data.collections.new('SOLDIER_Facial_Expressions_PENDING');bpy.data.collections['SOLDIER_ASSETS'].children.link(asset);asset['review_status']='Pending';asset['research_only']=True
layer=scene.view_layers.new('Facial Expressions')
def layer_collection(root,col):
 if root.collection==col:return root
 for child in root.children:
  found=layer_collection(child,col)
  if found:return found
registry=json.loads(scene['soldier_registry']);skin=next(e for e in registry['entries'] if e['id']=='SOLDIER_Skin_v001')
for s in bpy.data.scenes:
 for vl in s.view_layers:
  lc=layer_collection(vl.layer_collection,asset)
  if lc:lc.exclude=vl!=layer
for e in registry['entries']:
 if e.get('type')!='facial' and e.get('collection') in bpy.data.collections:
  lc=layer_collection(layer.layer_collection,bpy.data.collections[e['collection']])
  if lc:lc.exclude=True
bpy.context.window.view_layer=layer
for view_layer in scene.view_layers:view_layer.use=view_layer==layer
original_rig=bpy.data.objects[skin['rig']];rig=original_rig.copy();rig.data=original_rig.data.copy();rig.name='SF_Soldier_Rig';rig.data.name='SF_Original_Soldier_RestRig_Copy';rig.animation_data_clear();asset.objects.link(rig);rig.hide_viewport=False;rig.hide_render=False;rig.hide_set(False)
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4);pb.rotation_mode='QUATERNION'
for source in list(bpy.data.collections[skin['collection']].all_objects):
 if source.type!='MESH':continue
 clone=source.copy();clone.name='SF_'+('Soldier_Body' if source.name==skin['body'] else 'Soldier_Hair' if source.name==skin['hair'] else 'Soldier_Clothing');clone.animation_data_clear();asset.objects.link(clone);clone.parent=rig;clone.matrix_world=source.matrix_world;clone.hide_render=False;clone.hide_viewport=False;clone.hide_set(False)
 for mod in clone.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
 clone['actual_soldier_source']=source.name
# Weapon preview uses the exact Sand Block source, isolated from the weapon library.
with bpy.data.libraries.load(str(R/'blender/weapons/rifle_sand_block_v1/Rifle_Sand_Block_V1.blend'),link=False) as (src,dst):dst.collections=['WEAPON_EXPORT']
weapon_collection=dst.collections[0]
for obj in list(weapon_collection.all_objects):
 asset.objects.link(obj);obj.name='SF_'+obj.name
weapon=bpy.data.objects['SF_Rifle_Sand_Block_V1'];weapon.rotation_mode='QUATERNION'
bpy.data.collections.remove(weapon_collection)
ctrl=bpy.data.objects.new('SF_Face_Control',None);asset.objects.link(ctrl);ctrl.empty_display_size=.025;ctrl.hide_render=True;ctrl['review_status']='Pending'
for k,v in model.NEUTRAL.items():ctrl[k]=v
for k,v,lo,hi in [('intensity',1.,0.,1.),('look_x',0.,-1.,1.),('look_y',0.,-1.,1.),('auto_blink',1.,0.,1.)]:ctrl[k]=v;ctrl.id_properties_ui(k).update(min=lo,max=hi)
# One packed opaque atlas, one surface, no facial shader effects.
atlas=bpy.data.images.load(str(D/'soldier_face_atlas.png'));atlas.name='SF_Original_Soldier_Face_Atlas';atlas.pack()
material=bpy.data.materials.new('SF_Voxel_Face_One_Atlas');material.use_nodes=True;p=material.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=1.
tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest';material.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
region=json.loads((D/'face_atlas_regions.json').read_text());vertices=[];faces=[];uvs=[];parts=[];unit=.45/32

def quad(x0,x1,y0,y1,depth,tile,side='',kind='',segment=0):
 # Pixel coordinates are measured on the unchanged32px head front.
 lo=Vector((-.225+x0*unit,-.225-depth,1.8-y1*unit));hi=Vector((-.225+x1*unit,-.225-depth,1.8-y0*unit))
 first=len(vertices);vertices.extend([(lo.x,lo.y,lo.z),(hi.x,lo.y,lo.z),(hi.x,hi.y,hi.z),(lo.x,hi.y,hi.z)]);faces.append((first,first+1,first+2,first+3))
 if tile=='face':
  x,y,w,h=region['head_front'];u0=(x+.02)/512;u1=(x+w-.02)/512;v0=(512-y-h+.02)/512;v1=(512-y-.02)/512;uvs.append([(u0,v0),(u1,v0),(u1,v1),(u0,v1)])
 else:uvs.append([region['swatches'][tile]]*4)
 parts.append({'indices':list(range(first,first+4)),'side':side,'kind':kind,'segment':segment})
quad(0,32,0,32,.00045,'face')
for side,x in [('R',4),('L',19)]:
 quad(x,x+9,18,25,.00085,'white',side,'white')
 quad(x+3,x+7,18,25,.00115,'iris',side,'iris')
 quad(x+3,x+6,18,20,.00145,'iris_top',side,'accent')
 for segment,(a,b) in enumerate([(0,3),(3,6),(6,8)]):
  quad(x+a,x+b,15,17,.00165,'brow',side,'brow',segment)
  h0=max(1,a);h1=min(7,b)
  if h1>h0:quad(x+h0,x+h1,15,16,.0018,'brow_light',side,'brow',segment)
 quad(x+.5,x+8.5,21.49998,21.50002,.00195,'lid',side,'lid')
mesh=bpy.data.meshes.new('SF_Voxel_Face_42Triangles');mesh.from_pydata(vertices,[],faces);mesh.update();face=bpy.data.objects.new('SF_Face_Mesh',mesh);asset.objects.link(face);face.parent=rig;mesh.materials.append(material)
uv=mesh.uv_layers.new(name='SF_Face_Atlas')
for poly,coords in zip(mesh.polygons,uvs):
 for li,co in zip(poly.loop_indices,coords):uv.data[li].uv=co
vg=face.vertex_groups.new(name='Head');vg.add(list(range(len(vertices))),1.,'REPLACE');mod=face.modifiers.new('Rigid Head follow / no head deformation','ARMATURE');mod.object=rig
face.shape_key_add(name='Basis');face['review_status']='Pending';face['no_mouth_or_nose']=True;face['original_geometry_unchanged']=True

def add_key(name,side,fn):
 key=face.shape_key_add(name=name,from_mix=False);key.slider_min=-1.;key.slider_max=1.5
 for i,co in enumerate(vertices):key.data[i].co=co
 for part in parts:
  if part['side']!=side:continue
  for i in part['indices']:key.data[i].co=fn(Vector(vertices[i]),part)
 return key

def driver(key,expression,mapping):
 curve=key.driver_add('value');d=curve.driver;d.type='SCRIPTED';d.expression=expression
 for name,prop in mapping.items():
  variable=d.variables.new();variable.name=name;variable.type='SINGLE_PROP';variable.targets[0].id=ctrl;variable.targets[0].data_path=f'["{prop}"]'

for side in ['L','R']:
 x=19 if side=='L' else 4;centre=Vector((-.225+(x+5)*unit,-.226,1.8-21.5*unit));cy=centre.z
 eye=lambda part:part['kind'] in ['white','iris','accent']
 pupil=lambda part:part['kind'] in ['iris','accent']
 def close(v,p):
  if eye(p):v.z=cy
  return v
 key=add_key('Close_'+side,side,close)
 effective='max(.05,min(1.3,1+(o-1)*i))*(1-min(1,max(0,b*i+a*u)))'
 mapping={'o':'open_'+side.lower(),'i':'intensity','b':'blink','a':'auto_blink','u':'blink_auto'}
 driver(key,'1-('+effective+')',mapping)
 def gaze(v,p):
  if pupil(p):v.x+=1.7*unit
  return v
 key=add_key('GazeX_'+side,side,gaze);driver(key,'max(-1,min(1,g*i+x))',{'g':'gaze_x','i':'intensity','x':'look_x'})
 def up(v,p):
  if p['kind']=='iris' and v.z<cy:v.z+=unit
  return v
 def down(v,p):
  if p['kind']=='iris' and v.z>cy or p['kind']=='accent':v.z-=unit
  return v
 for suffix,fn,sign in [('Up',up,''),('Down',down,'-')]:
  key=add_key('Gaze'+suffix+'_'+side,side,fn);driver(key,'max(0,min(1,'+sign+'(g*i+y)))*('+effective+')',{**mapping,'g':'gaze_y','y':'look_y'})
 def small(v,p):
  if pupil(p):v.x=centre.x;v.z=cy
  return v
 key=add_key('PupilSmall_'+side,side,small);driver(key,'(1-(1+(s-1)*i))*('+effective+')',{**mapping,'s':'pupil_scale'})
 def lift(v,p):
  if p['kind']=='brow':v.z+=unit*1.6
  return v
 key=add_key('BrowLift_'+side,side,lift);driver(key,'h*i',{'h':'brow_'+side.lower(),'i':'intensity'})
 def tilt(v,p):
  if p['kind']=='brow':
   inner=(2-p['segment']) if side=='L' else p['segment'];v.z+=(.5-inner*.65)*unit
  return v
 key=add_key('BrowTilt_'+side,side,tilt);driver(key,'t*i',{'t':'tilt_'+side.lower(),'i':'intensity'})
 def lid(v,p):
  if p['kind']=='lid':v.z=cy+(.0018 if v.z>cy else -.0018)
  return v
 key=add_key('Lid_'+side,side,lid);driver(key,'min(1,max(0,b*i+a*u))*min(1,max(0,b*i+a*u))*min(1,max(0,b*i+a*u))',{'b':'blink','a':'auto_blink','u':'blink_auto','i':'intensity'})
face['parts_json']=json.dumps(parts)
# Store presets and contextual clips in this one native file.
for name,preset in model.PRESETS.items():fb.face_action('SOLDIER_Face_Preset_'+name,ctrl,'preset',name,preset['duration'])
for name,duration in model.SITUATIONS.items():fb.face_action('SOLDIER_Face_Situation_'+name.replace(' ','_'),ctrl,'situation',name,duration)
for name,path in [('SOLDIER — body preview samples (research only)',D/'body_preview_samples.json'),('SOLDIER — verified facial source evidence',D/'source_evidence.json'),('SOLDIER — facial design and limitations',D/'DESIGN.md')]:
 text=bpy.data.texts.get(name) or bpy.data.texts.new(name);text.clear();text.write(path.read_text())
text=bpy.data.texts.get('SOLDIER — facial preset manifest') or bpy.data.texts.new('SOLDIER — facial preset manifest');text.clear();text.write(json.dumps({'schema':1,'status':'Pending','original_facial_design':True,'presets':model.PRESETS,'situations':model.SITUATIONS,'channels':model.NEUTRAL,'limits':model.LIMITS,'no_godot_integration':True},indent=2))
# New cameras belong to the same scene/view layer; existing studio/cameras survive.
def camera(name,pos,target,scale):
 c=bpy.data.objects.new(name,bpy.data.cameras.new(name));asset.objects.link(c);c.location=pos;c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=scale;c.data.lens=50;return c
camera('SF_Front_Close',(0,-5,1.63),(0,0,1.60),.69)
camera('SF_ThreeQuarter_Close',(-2.7,-5,2.4),(0,-.03,1.59),.80)
camera('SF_Side_Close',(-5,-.4,1.85),(0,0,1.59),.78)
camera('SF_Gameplay_Distance',(-6,-8,6),(0,-.05,.96),12.8)

head_frame=bpy.data.objects.get('SF_Head_Frame')
if head_frame is None:
 head_frame=bpy.data.objects.new('SF_Head_Frame',None);asset.objects.link(head_frame)
 c=head_frame.constraints.new('COPY_TRANSFORMS');c.name='Follow Head only / preview camera';c.target=rig;c.subtarget='Head'
 target=bpy.data.objects.new('SF_Face_Target',None);asset.objects.link(target);target.parent=head_frame;target.location=(0,.225,0)
else:target=bpy.data.objects['SF_Face_Target']
for camera_name in ['SF_Front_Close','SF_ThreeQuarter_Close','SF_Side_Close']:
 cam=bpy.data.objects[camera_name]
 if not cam.constraints:
  c=cam.constraints.new('TRACK_TO');c.target=target;c.track_axis='TRACK_NEGATIVE_Z';c.up_axis='UP_Y'

registry['entries']=[e for e in registry['entries'] if e['id']!='SOLDIER_Facial_System_v001']
registry['entries'].append({'id':'SOLDIER_Facial_System_v001','label':'Facial Expressions','status':'Pending','type':'facial','collection':asset.name,'review_scene':scene.name,'view_layer':layer.name,'object':ctrl.name,'controller':ctrl.name,'face':face.name,'presets':list(model.PRESETS),'situations':list(model.SITUATIONS),'original_face_design':True,'research_body_previews':True})
scene['soldier_registry']=json.dumps(registry);scene['sf_selected_preset']=0;scene['sf_mode']='preset';scene['sf_situation']='Idle';scene['sf_loop']=True
asset.asset_mark();asset.asset_data.description='Pending | Original Soldier face states + research-only body compatibility previews; one central library.'
scene.render.fps=30;scene.render.fps_base=1.;scene.frame_start=1;scene.frame_end=240
fb.assign(ctrl,fb.face_action('SF_Preview_Live_Face',ctrl,'preset','Neutral_Idle',8.));fb.body_action(rig,weapon,'preset','Neutral_Idle',8.)
scene.camera=bpy.data.objects['SF_Front_Close'];scene.frame_set(1)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  space=area.spaces.active;space.show_region_ui=True;space.overlay.show_overlays=False;space.region_3d.view_perspective='CAMERA';space.use_local_camera=False
for obj in layer.objects:obj.select_set(False)
ctrl.select_set(True);layer.objects.active=ctrl
assert all(digest(bpy.data.objects[name])==value for name,value in protected.items()),'Existing asset object/data changed'
assert all(name in bpy.data.actions and len(list(fb.curves(bpy.data.actions[name])))==count for name,count in prior_actions.items())
bpy.ops.wm.save_as_mainfile(filepath=str(LIB))
(D.parent/'showcase/registry.json').write_text(json.dumps(registry,indent=2)+'\n')
(D/'build_validation.json').write_text(json.dumps({'passed':True,'protected_objects':protected,'prior_actions':prior_actions,'presets':18,'situations':len(model.SITUATIONS),'face_vertices':len(vertices),'face_triangles':len(faces)*2,'facial_shape_keys':len(face.data.shape_keys.key_blocks),'body_rig_bones':len(rig.data.bones),'no_new_permanent_library':True,'no_godot_changes':True},indent=2)+'\n')
print('SOLDIER_FACIAL_BUILD_OK',len(vertices),len(faces)*2,len(bpy.data.actions),flush=True)
