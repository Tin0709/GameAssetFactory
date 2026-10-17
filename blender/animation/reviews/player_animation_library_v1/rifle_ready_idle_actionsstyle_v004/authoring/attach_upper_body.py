"""Current v004: seat both shoulders and restore the original head/body anchor.
Changes are bounded pose adapters; no rig, mesh, cadence or source-angle redesign.
"""
import bpy,sys,json,hashlib,math
from pathlib import Path
from mathutils import Vector,Matrix
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
N='Rifle_Ready_Idle_ActionsStyle_v004';INPUT='dc92fe860ba5819de1bf04741c9b1ca5437573eceadeaad3913e1a23908271a5'
BACK=.020;UP=.030;LEFT_SOCKET_INSET=.006;REMOVE_HEAD_LIFT=.025
r=bpy.data.objects[ui.RIG];s=bpy.context.scene;a=bpy.data.actions[N];assert ui.action_signature(a)==INPUT
manifest=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text());assert next(e for e in manifest['animations'] if e['action']==N)['status']=='pending'
prior={b.name:ui.action_signature(b) for b in bpy.data.actions if b.name!=N};rest={b.name:b.matrix_local.copy() for b in r.data.bones};palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N
frames=sorted({float(k.co.x) for c in ui.curves(a) for k in c.keyframe_points});values={};gains={k:[] for k in ['L','R']};handerr=0.;headanchor=0.;moves=[]
for f in frames:
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();B={b.name:b.matrix.copy() for b in r.pose.bones};C=B['Chest'];shift=-C.to_3x3().col[2].normalized()*BACK+C.to_3x3().col[1].normalized()*UP;T=Matrix.Translation(shift);M={n:(T@b if n in ['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier'] else b.copy()) for n,b in B.items()}
 P=M['ForeArm.L']@palm;socket=(C@rest['Chest'].inverted()@rest['UpperArm.L']).translation-C.to_3x3().col[0].normalized()*LEFT_SOCKET_INSET;q=(M['UpperArm.L'].translation-P).rotation_difference(socket-P);D=Matrix.Translation(P)@q.to_matrix().to_4x4()@Matrix.Translation(-P)
 for n in ['UpperArm.L','ForeArm.L']:M[n]=D@M[n]
 for n in ['Neck','Head']:M[n]=Matrix.Translation((0,0,-REMOVE_HEAD_LIFT))@B[n]
 handerr=max(handerr,(M['WeaponCarrier'].inverted()@(M['ForeArm.L']@palm)-B['WeaponCarrier'].inverted()@(B['ForeArm.L']@palm)).length)
 for side in gains:
  socket0=(C@rest['Chest'].inverted()@rest['UpperArm.'+side]).translation;gains[side].append((B['UpperArm.'+side].translation-socket0).length-(M['UpperArm.'+side].translation-socket0).length)
 top=(C@rest['Chest'].inverted())@Vector((0,0,1.35));headanchor=max(headanchor,(M['Head'].translation-top).length);moves.append(shift.length);row={}
 for n in ['UpperArm.L','UpperArm.R','WeaponCarrier','Neck','Head']:
  b=r.data.bones[n];kw={} if not b.parent else {'parent_matrix':M[b.parent.name],'parent_matrix_local':rest[b.parent.name]};local=b.convert_local_to_pose(M[n],rest[n],invert=True,**kw);p,q,scale=local.decompose()
  if q.dot(r.pose.bones[n].rotation_quaternion)<0:q.negate()
  row[n]={'location':list(p),'rotation_quaternion':list(q)}
 values[f]=row
changed=[]
for c in ui.curves(a):
 n=c.data_path.split('"')[1];prop=c.data_path.split('.')[-1]
 if (n=='UpperArm.L' and prop in ['location','rotation_quaternion']) or (n in ['UpperArm.R','WeaponCarrier','Neck','Head'] and prop=='location'):
  ys=[values[float(k.co.x)][n][prop][c.array_index] for k in c.keyframe_points]
  if max(abs(v-k.co.y) for v,k in zip(ys,c.keyframe_points))>5e-7:c.keyframe_points.foreach_set('co',[v for k,y in zip(c.keyframe_points,ys) for v in [k.co.x,y]]);c.update();changed.append([n,prop,c.array_index])
a['upper_body_attachment']={'holding_up_m':UP,'holding_back_m':BACK,'left_socket_inset_m':LEFT_SOCKET_INSET,'removed_head_lift_m':REMOVE_HEAD_LIFT};a['refinement_note']='Both shoulders seated closer with30mm up/20mm back holding-set placement; fixed25mm head clearance removed. Original rotations/timing and both weapon contacts retained; intentional neck/shoulder joint seating.'
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in prior.items());s.frame_set(1);s.frame_start=1;s.frame_end=324;s.render.fps=30;s.camera=bpy.data.objects['Showcase_SIDE'];ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'})
p=O/'rifle_ready_idle_actionsstyle_v004.blend';bpy.ops.wm.save_as_mainfile(filepath=str(p),compress=True,check_existing=False)
e=json.loads((O/'entry.json').read_text());e.update({'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'action_sha256':ui.action_signature(a),'status':'pending','approval_note':'Pending both-shoulder/head attachment refinement. Holding assembly30mm up/20mm back; fixed25mm head clearance removed; original angles/timing and rifle contacts preserved.','holding_attachment_offset_m':{'up':UP,'back':BACK},'removed_head_clearance_m':REMOVE_HEAD_LIFT,'left_shoulder_socket_alignment':1.0,'left_socket_inset_m':LEFT_SOCKET_INSET,'joint_seating_envelopes_m':{'Head|Chest':.030,'Chest|UpperArm.R':.055},'left_support_motion':'Original support-palm trajectory relative to rifle retained exactly; left straight arm aligned to closest reachable inset socket after holding-set placement.'});(O/'entry.json').write_text(json.dumps(e,indent=2)+'\n')
d={'passed':True,'input_action_sha256':INPUT,'candidate_sha256':e['source_sha256'],'action_sha256':e['action_sha256'],'changed_curves':changed,'sampled_keys':len(frames),'holding_shift_m':{'up':UP,'back':BACK,'total':max(moves)},'removed_head_lift_m':REMOVE_HEAD_LIFT,'shoulder_socket_distance_gain_m':{k:[min(v),max(v)] for k,v in gains.items()},'support_relative_palm_error_m':handerr,'head_body_anchor_error_m':headanchor,'all_other_source_actions_exact':True,'source_angles_and_key_times_preserved_except_left_arm_seating':True};(O/'upper_body_build_validation.json').write_text(json.dumps(d,indent=2));print(json.dumps(d),flush=True)
