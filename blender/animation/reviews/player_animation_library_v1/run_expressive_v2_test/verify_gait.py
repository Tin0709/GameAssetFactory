import bpy,json,math,sys,hashlib,runpy
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[4];sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
B=runpy.run_path(str(O/'build_run_v2.py'));s=bpy.context.scene;r=bpy.data.objects['RN2_Test_Rig'];a=r.animation_data.action;head=[];poses=[];support_counts={'L':0,'R':0,'both':0,'flight':0}
for j in range(440):
 u=(j+.5)/440;supports=[B['foot'](u,side)[0]<=B['foot'](u,side)[1] for side in ['L','R']]
 support_counts['L']+=supports[0];support_counts['R']+=supports[1];support_counts['both']+=all(supports);support_counts['flight']+=not any(supports)
 f=1+22*u;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();head.append([math.degrees(x) for x in (r.pose.bones['Head'].matrix@r.data.bones['Head'].matrix_local.inverted()).to_euler('XYZ')])
for f in [1,12]:
 s.frame_set(f);bpy.context.view_layer.update();p={'frame':f}
 for side in ['L','R']:
  arm=r.pose.bones['UpperArm.'+side];fore=r.pose.bones['ForeArm.'+side];leg=r.pose.bones['Leg.'+side];hand=fore.tail.y-arm.head.y;foot=leg.tail.y-leg.head.y
  assert hand*foot<-.02,(f,side,hand,foot);p[side]={'hand_y_relative_shoulder_m':hand,'sole_y_relative_hip_m':foot,'opposition':True}
 poses.append(p)
assert support_counts['both']==0 and .14<support_counts['flight']/440<.16
ranges=[[min(p[i] for p in head),max(p[i] for p in head)] for i in range(3)];assert max(abs(x) for row in ranges for x in row)<4
v=json.loads((O/'validation.json').read_text());assert v['passed']
report={'passed':True,'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'action_sha256':ui.action_signature(a),'contact_poses':poses,'head_world_rotation_ranges_deg':ranges,'support_fractions':{k:v/440 for k,v in support_counts.items()},'walk_to_run_phase':{'left_contact':{'walk_frame':1,'run_frame':1,'normalized_phase':0},'right_contact':{'walk_frame':19,'run_frame':12,'normalized_phase':.5}},'walk_nominal_speed_m_s':.9,'run_nominal_speed_m_s':2.1,'blend_readiness':'Shared rig and contact phase; not runtime-proven. Walk double support22% versus Run flight15% needs contact-aware phase/speed blending, replant and interruption checks.'}
(O/'gait_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
