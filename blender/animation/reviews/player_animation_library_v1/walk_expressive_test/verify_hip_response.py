"""Compare measured rigid-body response against the safely archived first walk."""
import bpy,sys,json,math,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];OLD=ROOT/'.validation/walk_expressive_test/before_hip_response/walk_expressive_test/walk_expressive_review.blend';NEW=OUT/'walk_expressive_review.blend'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def measure():
 s=bpy.context.scene;r=bpy.data.objects['WEX_Test_Rig'];points={n:[] for n in ['Hips','Spine','Chest','Head']};hips=[];contacts=[]
 for j in range(289):
  f=1+j/8;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();hips.append(list(r.pose.bones['Hips'].head))
  for n in points:points[n].append([math.degrees(x) for x in (r.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted()).to_euler('XYZ')])
  if f in [1,19]:
   side='L' if f==1 else 'R';h=r.pose.bones['Hips'];leg=r.pose.bones['Leg.'+side];socket=h.matrix@(h.bone.matrix_local.inverted()@leg.bone.head_local)
   contacts.append({'frame':f,'lead_leg':side,'socket_y_relative_pelvis_m':socket.y-h.head.y,'sole_y_relative_leg_top_m':leg.tail.y-leg.head.y})
 return {'world_rotation_ranges_deg':{n:[[min(p[i] for p in rows),max(p[i] for p in rows)] for i in range(3)] for n,rows in points.items()},'hip_xyz_range_m':[[min(p[i] for p in hips),max(p[i] for p in hips)] for i in range(3)],'receiving_contacts':contacts}
bpy.ops.wm.open_mainfile(filepath=str(OLD));before=measure();bpy.ops.wm.open_mainfile(filepath=str(NEW));after=measure()
width=lambda data,bone,axis:data['world_rotation_ranges_deg'][bone][axis][1]-data['world_rotation_ranges_deg'][bone][axis][0]
assert width(after,'Hips',2)>1.9*width(before,'Hips',2) and width(after,'Hips',1)>1.7*width(before,'Hips',1)
assert width(after,'Chest',1)>2*width(before,'Chest',1)
assert max(abs(x) for row in after['world_rotation_ranges_deg']['Head'] for x in row)<2
assert all(x['socket_y_relative_pelvis_m']<0 and x['sole_y_relative_leg_top_m']<0 for x in after['receiving_contacts'])
report={'passed':True,'source_sha256':sha(NEW),'action_sha256':ui.action_signature(bpy.data.actions['Walk_Expressive_Test']),'archived_source_sha256':sha(OLD),'before':before,'after':after,'rigid_torso_inherits_support_led_sway':True,'pelvis_turns_with_leading_leg':True,'steady_head_orientation_preserved':True,'not_a_new_approved_action':True}
(OUT/'hip_response_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True)
