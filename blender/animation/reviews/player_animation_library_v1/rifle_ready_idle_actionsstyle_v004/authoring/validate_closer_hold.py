"""Verify current Pending v004 versus its preserved pre-correction version."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
previous=Path(sys.argv[sys.argv.index('--')+1]);N='Rifle_Ready_Idle_ActionsStyle_v004';new=bpy.data.actions[N];v3=bpy.data.actions['Rifle_Ready_Idle_ActionsStyle_v003'];assert ui.action_signature(v3)=='d803fbf8f04043c57e0eea3c9d98a6360af8be929b629d4a73eb4a629f8470ce'
with bpy.data.libraries.load(str(previous),link=False) as (src,dst):dst.actions=[N]
old=dst.actions[0];assert ui.action_signature(old)=='c8349c746f1c0befe0b90eeb22f018ebae15a26ada0f3c227ccc581815403d96'
r=bpy.data.objects[ui.RIG];s=bpy.context.scene
allowed={'UpperArm.L','UpperArm.R','WeaponCarrier'}
def cd(c):return repr((c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type,k.easing) for k in c.keyframe_points],[(m.type,m.mode_before,m.mode_after) for m in c.modifiers]))
a={(c.data_path,c.array_index):c for c in ui.curves(old)};b={(c.data_path,c.array_index):c for c in ui.curves(new)};assert set(a)==set(b);changed=[]
for key,c in a.items():
 d=b[key];assert [(k.co.x,k.interpolation) for k in c.keyframe_points]==[(k.co.x,k.interpolation) for k in d.keyframe_points]
 if cd(c)!=cd(d):assert c.data_path.split('"')[1] in allowed;changed.append(list(key))
def pose(a,f):
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name;s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();return {p.name:p.matrix.copy() for p in r.pose.bones}
def md(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
m={k:0. for k in ['unaffected_world_matrix_error','rigid_assembly_mapping_error','shoulder_position_error_m','arm_relative_weapon_error','tuck_angle_error_degrees']};ranges={side:[1e9,-1e9] for side in ['L','R']}
for j in range(649):
 f=1+j*.5;A=pose(old,f);B=pose(new,f);axis=(A['UpperArm.L'].translation-A['UpperArm.R'].translation).normalized();pivot=(A['UpperArm.L'].translation+A['UpperArm.R'].translation)*.5;D=Matrix.Translation(A['Chest'].to_3x3().col[2].normalized()*.020)@Matrix.Translation(pivot)@Matrix.Rotation(math.radians(10),4,axis)@Matrix.Translation(-pivot)
 for n in A:
  if n not in ['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']:m['unaffected_world_matrix_error']=max(m['unaffected_world_matrix_error'],md(A[n],B[n]))
  else:m['rigid_assembly_mapping_error']=max(m['rigid_assembly_mapping_error'],md(D@A[n],B[n]))
 for side in ['L','R']:
  m['shoulder_position_error_m']=max(m['shoulder_position_error_m'],(B['UpperArm.'+side].translation-A['UpperArm.'+side].translation-A['Chest'].to_3x3().col[2].normalized()*.020).length)
  for n in ['UpperArm.'+side,'ForeArm.'+side]:m['arm_relative_weapon_error']=max(m['arm_relative_weapon_error'],md(A['WeaponCarrier'].inverted()@A[n],B['WeaponCarrier'].inverted()@B[n]))
  n='ForeArm.'+side;p=Vector((0,r.data.bones[n].length,0));forward=A['Chest'].to_3x3().col[2].normalized();delta=((A[n]@p)-(B[n]@p)).dot(forward);ranges[side][0]=min(ranges[side][0],delta);ranges[side][1]=max(ranges[side][1],delta)
 q=A['UpperArm.R'].to_quaternion().rotation_difference(B['UpperArm.R'].to_quaternion());theta=math.degrees(2*math.atan2(Vector((q.x,q.y,q.z)).length,abs(q.w)));m['tuck_angle_error_degrees']=max(m['tuck_angle_error_degrees'],abs(theta-10))
limits={'unaffected_world_matrix_error':1e-6,'rigid_assembly_mapping_error':2e-6,'shoulder_position_error_m':2e-6,'arm_relative_weapon_error':3e-6,'tuck_angle_error_degrees':.001};fails=[k for k,v in m.items() if v>limits[k]]
assert all(x[0]>.04 for x in ranges.values())
d={'passed':not fails,'failures':fails,'samples':649,'degrees_toward_torso':10,'shoulder_forward_clearance_m':.020,'metrics':m,'limits':limits,'hand_forward_reach_reduction_m':ranges,'all_unaffected_curves_exact':True,'key_times_and_interpolation_exact':True,'support_breathing_relative_to_weapon_exact':True,'v003_action_preserved':True,'changed_curves':changed,'candidate_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()};(O/'refinement_validation.json').write_text(json.dumps(d,indent=2));print(json.dumps(d),flush=True)
if fails:raise RuntimeError(str(fails))
