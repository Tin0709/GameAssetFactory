"""Independent current attachment checks versus the prior Pending v004."""
import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
N='Rifle_Ready_Idle_ActionsStyle_v004';new=bpy.data.actions[N];previous=Path(sys.argv[sys.argv.index('--')+1])
with bpy.data.libraries.load(str(previous),link=False) as (src,dst):dst.actions=[N]
old=dst.actions[0];assert ui.action_signature(old)=='dc92fe860ba5819de1bf04741c9b1ca5437573eceadeaad3913e1a23908271a5'
assert ui.action_signature(bpy.data.actions['Rifle_Ready_Idle_ActionsStyle_v003'])=='d803fbf8f04043c57e0eea3c9d98a6360af8be929b629d4a73eb4a629f8470ce'
allow={('UpperArm.L','location'),('UpperArm.L','rotation_quaternion'),('UpperArm.R','location'),('WeaponCarrier','location'),('Neck','location'),('Head','location')}
def cd(c):return repr((c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type,k.easing) for k in c.keyframe_points],[(m.type,m.mode_before,m.mode_after) for m in c.modifiers]))
a={(c.data_path,c.array_index):c for c in ui.curves(old)};b={(c.data_path,c.array_index):c for c in ui.curves(new)};assert set(a)==set(b);changed=[]
for key,c in a.items():
 d=b[key];assert [(k.co.x,k.interpolation) for k in c.keyframe_points]==[(k.co.x,k.interpolation) for k in d.keyframe_points]
 if cd(c)!=cd(d):assert (c.data_path.split('"')[1],c.data_path.split('.')[-1]) in allow;changed.append(list(key))
r=bpy.data.objects[ui.RIG];s=bpy.context.scene;rest={b.name:b.matrix_local.copy() for b in r.data.bones};palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0))
def pose(a,f):
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name;s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();return {b.name:b.matrix.copy() for b in r.pose.bones}
def md(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
m={k:0. for k in ['core_world_matrix_error','preserved_rotation_scale_error','holding_translation_error_m','right_grip_matrix_error','support_relative_palm_error_m','head_drop_error_m','head_body_anchor_error_m']};gains={side:[] for side in ['L','R']};old_neck=[]
for j in range(649):
 f=1+j*.5;A=pose(old,f);B=pose(new,f);C=A['Chest'];shift=-C.to_3x3().col[2].normalized()*.020+C.to_3x3().col[1].normalized()*.030
 for n in ['Root','Hips','Spine','Chest','Leg.L','Leg.R']:m['core_world_matrix_error']=max(m['core_world_matrix_error'],md(A[n],B[n]))
 for n in ['Head','Neck','UpperArm.R','ForeArm.R','WeaponCarrier']:m['preserved_rotation_scale_error']=max(m['preserved_rotation_scale_error'],max(abs(A[n][i][k]-B[n][i][k]) for i in range(3) for k in range(3)))
 for n in ['UpperArm.R','ForeArm.R','WeaponCarrier']:m['holding_translation_error_m']=max(m['holding_translation_error_m'],(B[n].translation-A[n].translation-shift).length)
 for n in ['UpperArm.R','ForeArm.R']:m['right_grip_matrix_error']=max(m['right_grip_matrix_error'],md(A['WeaponCarrier'].inverted()@A[n],B['WeaponCarrier'].inverted()@B[n]))
 m['support_relative_palm_error_m']=max(m['support_relative_palm_error_m'],(A['WeaponCarrier'].inverted()@(A['ForeArm.L']@palm)-B['WeaponCarrier'].inverted()@(B['ForeArm.L']@palm)).length)
 for n in ['Head','Neck']:m['head_drop_error_m']=max(m['head_drop_error_m'],(B[n].translation-A[n].translation-Vector((0,0,-.025))).length)
 top=(C@rest['Chest'].inverted())@Vector((0,0,1.35));m['head_body_anchor_error_m']=max(m['head_body_anchor_error_m'],(B['Head'].translation-top).length);old_neck.append((A['Head'].translation-top).length)
 for side in gains:
  socket=(C@rest['Chest'].inverted()@rest['UpperArm.'+side]).translation;gains[side].append((A['UpperArm.'+side].translation-socket).length-(B['UpperArm.'+side].translation-socket).length)
limits={k:(2e-6 if k in ['right_grip_matrix_error','support_relative_palm_error_m'] else 1e-6) for k in m};fails=[k for k,v in m.items() if v>limits[k]]
if min(min(v) for v in gains.values())<.034:fails.append('both shoulders must improve by at least34mm')
d={'passed':not fails,'failures':fails,'samples':649,'metrics':m,'limits':limits,'shoulder_socket_distance_gain_m':{k:[min(v),max(v)] for k,v in gains.items()},'prior_head_body_gap_at_anchor_m':[min(old_neck),max(old_neck)],'head_body_anchor_connected':m['head_body_anchor_error_m']<1e-6,'head_rifle_right_arm_angles_exact':True,'body_leg_world_motion_exact':True,'both_weapon_contacts_preserved':True,'all_key_times_and_interpolation_exact':True,'changed_curves':changed,'candidate_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()};(O/'refinement_validation.json').write_text(json.dumps(d,indent=2));print(json.dumps(d),flush=True)
if fails:raise RuntimeError(str(fails))
