"""Independent read-only v003/v004 motion comparison at 30/60FPS poses."""
import bpy,json,sys,hashlib,math
from pathlib import Path
from mathutils import Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
B='Rifle_Ready_Idle_ActionsStyle_v003';N='Rifle_Ready_Idle_ActionsStyle_v004'
a=bpy.data.actions[B];b=bpy.data.actions[N];rig=bpy.data.objects[ui.RIG];s=bpy.context.scene
expected='d803fbf8f04043c57e0eea3c9d98a6360af8be929b629d4a73eb4a629f8470ce'
assert ui.action_signature(a)==expected
allowed={(n,p) for n,p in [('UpperArm.L','location'),('UpperArm.L','rotation_quaternion'),('UpperArm.R','location'),('WeaponCarrier','location')]}
def curve_data(c):return repr((c.data_path,c.array_index,c.mute,c.extrapolation,c.auto_smoothing,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type,k.easing,k.back,k.amplitude,k.period) for k in c.keyframe_points],[(m.type,m.mode_before,m.mode_after,m.cycles_before,m.cycles_after) for m in c.modifiers]))
ca={(c.data_path,c.array_index):c for c in ui.curves(a)};cb={(c.data_path,c.array_index):c for c in ui.curves(b)};assert set(ca)==set(cb)
changed=[]
for key,c in ca.items():
 d=cb[key]
 assert [(k.co.x,k.interpolation) for k in c.keyframe_points]==[(k.co.x,k.interpolation) for k in d.keyframe_points]
 if curve_data(c)!=curve_data(d):
  assert (c.data_path.split('"')[1],c.data_path.split('.')[-1]) in allowed
  changed.append(list(key))
def sample(action,f):
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0];s['gaf_library_last_action']=action.name
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 return {p.name:(rig.matrix_world@p.matrix).copy() for p in rig.pose.bones}
def md(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
unaffected=[n for n in rig.pose.bones.keys() if n not in ['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']]
metrics={'unaffected_world_matrix_error':0.,'right_arm_rifle_drop_error_m':0.,'right_arm_rifle_orientation_scale_error':0.,'left_anchor_relative_motion_m':0.,'left_whole_arm_angle_degrees':0.,'left_shoulder_additive_m':0.,'left_30fps_additive_step_m':0.}
palm=Vector((0,rig.data.bones['ForeArm.L'].length*.78,0));offsets=[]
for j in range(649):
 f=1+j*.5;old=sample(a,f);new=sample(b,f)
 for n in unaffected:metrics['unaffected_world_matrix_error']=max(metrics['unaffected_world_matrix_error'],md(old[n],new[n]))
 for n in ['UpperArm.R','ForeArm.R','WeaponCarrier']:
  metrics['right_arm_rifle_drop_error_m']=max(metrics['right_arm_rifle_drop_error_m'],(new[n].translation-old[n].translation-Vector((0,0,-.018))).length)
  metrics['right_arm_rifle_orientation_scale_error']=max(metrics['right_arm_rifle_orientation_scale_error'],max(abs(old[n][i][k]-new[n][i][k]) for i in range(3) for k in range(3)))
 ref=old['WeaponCarrier'].inverted()@(old['ForeArm.L']@palm);cur=new['WeaponCarrier'].inverted()@(new['ForeArm.L']@palm);offset=cur-ref
 metrics['left_anchor_relative_motion_m']=max(metrics['left_anchor_relative_motion_m'],offset.length)
 q=old['UpperArm.L'].to_quaternion().rotation_difference(new['UpperArm.L'].to_quaternion());angle=2*math.atan2(Vector((q.x,q.y,q.z)).length,abs(q.w))*180/math.pi
 metrics['left_whole_arm_angle_degrees']=max(metrics['left_whole_arm_angle_degrees'],angle)
 metrics['left_shoulder_additive_m']=max(metrics['left_shoulder_additive_m'],(new['UpperArm.L'].translation-old['UpperArm.L'].translation-Vector((0,0,-.018))).length)
 if j%2==0:offsets.append(offset)
metrics['left_30fps_additive_step_m']=max((b-a).length for a,b in zip(offsets,offsets[1:]))
limits={'unaffected_world_matrix_error':1e-6,'right_arm_rifle_drop_error_m':1e-6,'right_arm_rifle_orientation_scale_error':1e-6,'left_anchor_relative_motion_m':.003,'left_whole_arm_angle_degrees':.151,'left_shoulder_additive_m':.004,'left_30fps_additive_step_m':.001}
failures=[k for k,v in metrics.items() if v>limits[k]]
assert metrics['left_anchor_relative_motion_m']>.0005,'No meaningful support motion'
source=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v003/rifle_ready_idle_actionsstyle_v003.blend'
assert hashlib.sha256(source.read_bytes()).hexdigest()=='b23fb544ee9ab74d325874cbea6b8d189cd582dd5bcee83fabef7ff769f645d1'
d={'passed':not failures,'failures':failures,'samples':649,'changed_curves':changed,'unaffected_curves_verbatim':True,'all_key_times_and_interpolation_retained':True,'v003_action_sha256':ui.action_signature(a),'v003_source_byte_exact':True,'metrics':metrics,'limits':limits}
(O/'refinement_validation.json').write_text(json.dumps(d,indent=2));print(json.dumps(d))
if failures:raise RuntimeError(str(failures))
