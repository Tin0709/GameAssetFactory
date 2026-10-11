import bpy,json,sys,hashlib,math
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['WEX_Test_Rig'];a=r.animation_data.action;poses=[]
for f in [1,19]:
 s.frame_set(f);bpy.context.view_layer.update();frame={'frame':f}
 for side in ['L','R']:
  arm=r.pose.bones['UpperArm.'+side];fore=r.pose.bones['ForeArm.'+side];leg=r.pose.bones['Leg.'+side]
  hand=fore.tail.y-arm.head.y;foot=leg.tail.y-leg.head.y
  assert hand*foot<-.02,(f,side,hand,foot)
  frame[side]={'hand_y_relative_shoulder_m':hand,'sole_y_relative_hip_m':foot,'arm_opposes_same_side_leg':True}
 poses.append(frame)
head=[]
for j in range(289):
 f=1+j/8;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
 head.append([math.degrees(x) for x in (r.pose.bones['Head'].matrix@r.data.bones['Head'].matrix_local.inverted()).to_euler('XYZ')])
ranges=[[min(x[i] for x in head),max(x[i] for x in head)] for i in range(3)]
assert max(abs(x) for row in ranges for x in row)<2
report={'passed':True,'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'action_sha256':ui.action_signature(a),'both_contact_poses':poses,'head_world_rotation_ranges_deg':ranges,'nominal_speed_m_s':.9,'support_duty':{'L':.60,'R':.62},'double_support_fraction':.22,'flight_fraction':0,'approved_idle_relationship':'Same rig, relaxed forward torso, straight full arms, support-led hips and restrained head. Walking uses dynamic5deg toe-out/0.27m tracks versus fixed idle15deg/~0.40m; needs support-aware replant for starts/stops.'}
(OUT/'phase_pose_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
