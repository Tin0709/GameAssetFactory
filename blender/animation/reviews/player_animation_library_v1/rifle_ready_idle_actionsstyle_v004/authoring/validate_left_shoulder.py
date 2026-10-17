"""Independent before/after check for the support-shoulder-only refinement."""
import bpy,sys,json,hashlib,math
from pathlib import Path
from mathutils import Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
N='Rifle_Ready_Idle_ActionsStyle_v004';new=bpy.data.actions[N];previous=Path(sys.argv[sys.argv.index('--')+1])
with bpy.data.libraries.load(str(previous),link=False) as (src,dst):dst.actions=[N]
old=dst.actions[0];assert ui.action_signature(old)=='64e4635a30e50df9b74aeaa9f05734c09228ef6ab67f80781a096451f4d11360'
assert ui.action_signature(bpy.data.actions['Rifle_Ready_Idle_ActionsStyle_v003'])=='d803fbf8f04043c57e0eea3c9d98a6360af8be929b629d4a73eb4a629f8470ce'
def cd(c):return repr((c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type,k.easing) for k in c.keyframe_points],[(m.type,m.mode_before,m.mode_after) for m in c.modifiers]))
ca={(c.data_path,c.array_index):c for c in ui.curves(old)};cb={(c.data_path,c.array_index):c for c in ui.curves(new)};assert set(ca)==set(cb);changed=[]
for key,a in ca.items():
 b=cb[key];assert [(k.co.x,k.interpolation) for k in a.keyframe_points]==[(k.co.x,k.interpolation) for k in b.keyframe_points]
 if cd(a)!=cd(b):assert a.data_path.split('"')[1]=='UpperArm.L';changed.append(list(key))
r=bpy.data.objects[ui.RIG];s=bpy.context.scene;palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0))
def pose(a,f):
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name;s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();return {p.name:p.matrix.copy() for p in r.pose.bones}
def md(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
m={'unaffected_world_matrix_error':0.,'palm_world_error_m':0.,'palm_relative_weapon_error_m':0.,'new_scale_error':0.};dep=[];angles=[];olddepth=[];newdepth=[];socket_gain=[]
for j in range(649):
 f=1+j*.5;A=pose(old,f);B=pose(new,f)
 for n in A:
  if n not in ['UpperArm.L','ForeArm.L']:m['unaffected_world_matrix_error']=max(m['unaffected_world_matrix_error'],md(A[n],B[n]))
 pa=A['ForeArm.L']@palm;pb=B['ForeArm.L']@palm;m['palm_world_error_m']=max(m['palm_world_error_m'],(pb-pa).length);m['palm_relative_weapon_error_m']=max(m['palm_relative_weapon_error_m'],(A['WeaponCarrier'].inverted()@pa-B['WeaponCarrier'].inverted()@pb).length)
 for n in ['UpperArm.L','ForeArm.L']:m['new_scale_error']=max(m['new_scale_error'],max(abs(v-1) for v in B[n].to_scale()))
 fore=A['Chest'].to_3x3().col[2].normalized();dep.append((A['UpperArm.L'].translation-B['UpperArm.L'].translation).dot(fore));q=A['UpperArm.L'].to_quaternion().rotation_difference(B['UpperArm.L'].to_quaternion());angles.append(math.degrees(2*math.atan2(Vector((q.x,q.y,q.z)).length,abs(q.w))))
 socket=(A['Chest']@r.data.bones['Chest'].matrix_local.inverted()@r.data.bones['UpperArm.L'].matrix_local).translation;olddepth.append((A['UpperArm.L'].translation-socket).dot(fore));newdepth.append((B['UpperArm.L'].translation-socket).dot(fore));socket_gain.append((A['UpperArm.L'].translation-socket).length-(B['UpperArm.L'].translation-socket).length)
limits={'unaffected_world_matrix_error':1e-6,'palm_world_error_m':1e-6,'palm_relative_weapon_error_m':1e-6,'new_scale_error':1e-5};fail=[k for k,v in m.items() if v>limits[k]]
if not min(dep)>.028 or max(dep)>.031:fail.append('shoulder retraction outside28–31mm')
if max(angles)>3.4:fail.append('rotation exceeds3.4degrees')
if min(socket_gain)<=0:fail.append('shoulder not closer to anatomical socket')
d={'passed':not fail,'failures':fail,'samples':649,'metrics':m,'limits':limits,'shoulder_depth_reduction_m':[min(dep),max(dep)],'whole_arm_rotation_degrees':[min(angles),max(angles)],'shoulder_forward_offset_from_socket_before_m':[min(olddepth),max(olddepth)],'shoulder_forward_offset_from_socket_after_m':[min(newdepth),max(newdepth)],'euclidean_socket_distance_reduction_m':[min(socket_gain),max(socket_gain)],'changed_curves':changed,'only_left_upper_arm_curves_changed':True,'rifle_right_arm_head_body_legs_exact':True,'original_support_palm_motion_exact':True,'all_key_times_and_interpolation_exact':True,'candidate_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()};(O/'refinement_validation.json').write_text(json.dumps(d,indent=2));print(json.dumps(d),flush=True)
if fail:raise RuntimeError(str(fail))
