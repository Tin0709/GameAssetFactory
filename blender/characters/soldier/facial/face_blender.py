"""Native face/body preview bakes. Touches SF_ review objects only."""
from pathlib import Path
import bpy,json,math
from mathutils import Matrix,Vector
import expression_model as model
D=Path(__file__).resolve().parent
_DATA=None

def body_data():
 global _DATA
 if _DATA is None:
  packed=bpy.data.texts.get('SOLDIER — body preview samples (research only)')
  _DATA=json.loads(packed.as_string() if packed else (D/'body_preview_samples.json').read_text())
 return _DATA

def curves(action):
 for layer in action.layers:
  for strip in layer.strips:
   if strip.type=='KEYFRAME':
    for bag in strip.channelbags:yield from bag.fcurves

def assign(obj,action):
 obj.animation_data_create();obj.animation_data.action=action
 if action.slots:obj.animation_data.action_slot=action.slots[0]

def action_channels(name,obj,channels,frames,description,asset=False):
 action=bpy.data.actions.get(name)
 if action:
  assert action.get('soldier_facial',False)
  for layer in list(action.layers):action.layers.remove(layer)
 else:action=bpy.data.actions.new(name)
 slot=next((s for s in action.slots if s.target_id_type=='OBJECT'),None) or action.slots.new(id_type='OBJECT',name=obj.name)
 layer=action.layers.new('SOLDIER facial / preview');strip=layer.strips.new(type='KEYFRAME');bag=strip.channelbag(slot,ensure=True)
 for path,values in channels.items():
  dimensions=len(values[0]) if isinstance(values[0],(list,tuple,Vector)) else 1
  for index in range(dimensions):
   curve=bag.fcurves.new(data_path=path,index=index);curve.keyframe_points.add(len(frames))
   curve.keyframe_points.foreach_set('co',[v for i,f in enumerate(frames) for v in (f,values[i][index] if dimensions>1 else values[i])])
   for point in curve.keyframe_points:point.interpolation='LINEAR'
   curve.update()
 action.use_fake_user=True;action['soldier_facial']=True;action['review_status']='Pending';action['description']=description
 if asset:
  action.asset_mark();action.asset_data.description=description+' | Pending | Blender review only'
 return action

def face_action(name,ctrl,kind,key,duration,from_face=None):
 start=5 if from_face is not None else 1
 frames=list(range(1,round(duration*30)+start+1));channels={f'["{k}"]':[] for k in model.NEUTRAL}
 for frame in frames:
  t=max(0.,(frame-start)/30);c=model.evaluate_preset(key,t) if kind=='preset' else model.evaluate_situation(key,t) if kind=='situation' else model.evaluate_reel(t)
  if from_face is not None and frame<start:c=model.blend(from_face,c,model.smooth((frame-1)/4))
  for k,v in c.items():channels[f'["{k}"]'].append(v)
 a=action_channels(name,ctrl,channels,frames,'Original Soldier '+kind+': '+key,not name.endswith('Live_Face'))
 a['duration_s']=duration;a['preset']=key;a['kind']=kind;a['original_facial_animation']=True
 return a

def matrix(row):return Matrix([row[i:i+4] for i in range(0,16,4)])
def source_pose(mode,t):
 d=body_data()[mode];phase=max(0.,t)
 if mode in ['Jump','Landing']:phase=min(phase,d['length'])
 else:phase=phase%d['length']
 f=phase*30;i=min(int(f),len(d['frames'])-1);j=min(i+1,len(d['frames'])-1);w=f-int(f)
 result={}
 for key,row in d['frames'][i].items():
  if row is None:result[key]=None;continue
  result[key]=matrix(row).lerp(matrix(d['frames'][j][key]),w)
 # Existing gameplay's half-roll frame adapter, only on rigid whole arms.
 # Full blocks remain straight; weapon/global source pose is not rotated.
 if mode in ['Aim','Fire']:
  for key in ['Arm.L','Arm.R']:result[key]=result[key]@Matrix.Rotation(math.pi,4,'Y')
 return result

def mix_poses(a,b,w):
 return {k:(a[k].lerp(b[k],w) if a[k] is not None and b[k] is not None else (b[k] if w>.5 else a[k])) for k in a}

def _base_preview_pose(key,t,kind='situation'):
 if kind=='preset':
  mapping={'Move_Effort_Light':'Walk','Run_Effort':'Run','Focused_Aim':'Aim','Fire_Recoil_Face':'FirePreset','Enemy_Nearby':'Rifle Ready Idle','Jump_Focus':'Jump','Land_Impact':'Landing'}
  mode=mapping.get(key,'Idle')
 else:mode={'Hurt':'Aim','Low Health':'Idle'}.get(key,key)
 if mode=='FirePreset':
  phase=t-.5
  if 0<=phase<1/6:return source_pose('Fire',phase)
  return source_pose('Fire',0.)
 if mode=='Aim':return source_pose('Aim',t)
 if mode=='Jump':
  if t<.30:return source_pose('Idle',t)
  if t<1.50:return source_pose('Jump',t-.30)
  if t<2.50:return source_pose('Landing',t-1.50)
  return mix_poses(source_pose('Landing',1.),source_pose('Idle',t),model.smooth((t-2.50)/.30))
 if mode=='Landing':
  if t<.5:return source_pose('Idle',t)
  if t<1.5:return source_pose('Landing',t-.5)
  return mix_poses(source_pose('Landing',1.),source_pose('Idle',t),model.smooth((t-1.5)/.3))
 if mode=='Fire':return source_pose('Fire',t)
 return source_pose(mode,t)

def preview_pose(key,t,kind='situation'):
 if kind=='reel':
  k,n,local,previous=model.reel_position(t);poses=preview_pose(n,local,k)
  if previous and local<.14:
   pk,pn,pd=previous;poses=mix_poses(preview_pose(pn,pd,pk),poses,model.smooth(local/.14))
  return poses
 poses=_base_preview_pose(key,t,kind)
 if kind=='preset':
  c=model.evaluate_preset(key,t,False);head=poses['Head'];rot=Matrix.Rotation(math.radians(c['head_yaw']),4,'Z')@Matrix.Rotation(math.radians(c['head_pitch']),4,'X');m=rot@head;m.translation=head.translation;poses['Head']=m
 return poses

def body_action(rig,weapon,kind,key,duration,entry=False):
 scene=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];old_frame=scene.frame_current
 start=5 if entry else 1
 channels={};weapon_channels={'location':[],'rotation_quaternion':[],'scale':[]};frames=list(range(1,round(duration*30)+start+1));previous={}
 captured={bone.name:bone.matrix.copy() for bone in rig.pose.bones};captured['Weapon']=weapon.matrix_world.copy()
 # No action/constraint writer competes while native basis channels are sampled.
 rig.animation_data_create();rig.animation_data.action=None
 for p in rig.pose.bones:p.rotation_mode='QUATERNION'
 for frame in frames:
  t=max(0.,(frame-start)/30);poses=preview_pose(key,t,kind)
  # One-time entry lives BEFORE the canonical loop, not in every repetition.
  if entry and frame<start:poses=mix_poses(captured,poses,model.smooth((frame-1)/4))
  # Short preset reviews have different lengths from the source idle/gait.
  # Close only their preview seam; source pose sampling itself stays at1x.
  if kind=='preset' and t>duration-.16:poses=mix_poses(poses,preview_pose(key,0.,kind),model.smooth((t-duration+.16)/.16))
  for bone in rig.pose.bones:
   parent=bone.parent
   kw={"parent_matrix":poses[parent.name],"parent_matrix_local":parent.bone.matrix_local} if parent else {}
   basis=bone.bone.convert_local_to_pose(poses[bone.name],bone.bone.matrix_local,invert=True,**kw)
   loc,q,scale=basis.decompose()
   if bone.name in previous and q.dot(previous[bone.name])<0:q.negate()
   previous[bone.name]=q.copy()
   for suffix,value in [('location',list(loc)),('rotation_quaternion',list(q)),('scale',list(scale))]:channels.setdefault(f'pose.bones["{bone.name}"].{suffix}',[]).append(value)
  wm=poses.get('Weapon') or Matrix.Identity(4);p,q,s=wm.decompose()
  if kind=='reel':
   _,reel_key,_,_=model.reel_position(t)
   if reel_key not in ['Rifle Ready Idle','Aim','Fire','Focused_Aim','Fire_Recoil_Face','Enemy_Nearby','Hurt']:s=Vector((0,0,0))
  if 'Weapon' in previous and q.dot(previous['Weapon'])<0:q.negate()
  previous['Weapon']=q.copy()
  for path,value in [('location',p),('rotation_quaternion',q),('scale',s)]:weapon_channels[path].append(list(value))
 action=action_channels('SF_Preview_Live_Body',rig,channels,frames,'Read-only body compatibility preview; no source Action edits')
 action['preview_only']=True;assign(rig,action)
 action=action_channels('SF_Preview_Live_Weapon',weapon,weapon_channels,frames,'Actual Sand Block rifle compatibility preview')
 action['preview_only']=True;weapon.rotation_mode='QUATERNION';assign(weapon,action)
 weapon.hide_render=not (kind=='reel' or key in ['Rifle Ready Idle','Aim','Fire','Focused_Aim','Fire_Recoil_Face','Enemy_Nearby','Hurt'])
 weapon.hide_set(weapon.hide_render)
 for child in weapon.children_recursive:child.hide_render=weapon.hide_render
 scene.frame_set(old_frame)
