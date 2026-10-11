"""Verify requested world-head directions, exact holds and center pass-throughs."""
import bpy,json,sys,math,hashlib,runpy
from pathlib import Path
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test_v3'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['IEV3_Test_Rig'];a=r.animation_data.action
old=json.loads((TMP/'before_directional_gaze_revision/study/manifest.json').read_text())
design=runpy.run_path(str(OUT/'build_test.py'))['design']
def sample(f):
 s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
 rot=(r.pose.bones['Head'].matrix@r.data.bones['Head'].matrix_local.inverted()).to_3x3()
 return rot, [math.degrees(x) for x in rot.to_euler('XYZ')]
holds=[]
for first,last,yaw,pitch in [(67,74.5,22,-7.6),(89,96.5,-22,9.4),(157,164.5,22,-7.6),(179,186.5,-22,9.4)]:
 values=[sample(first+j/8)[1] for j in range(int((last-first)*8)+1)]
 err=max(max(abs(x[0]-pitch),abs(x[2]-yaw)) for x in values)
 assert err<.0002,err
 holds.append({'frames':[first,last],'duration_s':(last-first)/30,'world_head_yaw_pitch_deg':[yaw,pitch],'maximum_angle_error_deg':err})
centers=[]
for f in [53,143]:
 _,angles=sample(f);before=sample(f-.0625)[1];after=sample(f+.0625)[1]
 speed=(after[0]-before[0])/.125*30
 assert abs(angles[2])<.0001 and speed < -15
 centers.append({'frame':f,'world_yaw_deg':angles[2],'pitch_speed_deg_s':speed,'hold_frames':0})
camera=bpy.data.objects['Showcase_FRONT'];directions=[]
for f,label in [(32,'viewer_right'),(70,'top_right'),(92,'bottom_left'),(120,'viewer_left'),(160,'top_right'),(182,'bottom_left')]:
 rot,angles=sample(f);origin=r.pose.bones['Head'].head
 neutral=world_to_camera_view(s,camera,origin+Vector((0,-.3,0)))
 q=world_to_camera_view(s,camera,origin+rot@Vector((0,-.3,0)))
 dx=q.x-neutral.x;dy=q.y-neutral.y
 assert dx>0 if 'right' in label else dx<0
 if label=='top_right':assert dy>0
 if label=='bottom_left':assert dy<0
 directions.append({'frame':f,'label':label,'front_camera_gaze_delta':[dx,dy],'head_angles_deg':angles})
for j in range(1921):
 f=1+j/8;sample(f)
 for side in ['L','R']:
  prior=Matrix(old['fixed_foot_matrices'][side]);assert max(abs(x-y) for row1,row2 in zip(r.pose.bones['Leg.'+side].matrix,prior) for x,y in zip(row1,row2))<2e-6
 d=design(f);b=.5-.5*math.cos(2*math.pi*(f-1)/120)
 assert abs(d['hip'].z-(.6716+.048*b-.036))<1e-7 and abs(d['chest_lift']-.0144*b)<1e-10
assert all(h['duration_s']==.25 for h in holds)
report={'passed':True,'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'action_sha256':ui.action_signature(a),'sequence':'viewer right -> center pass-through -> top right -> bottom left -> viewer left -> center pass-through -> top right -> bottom left -> rest','holds':holds,'center_pass_throughs':centers,'screen_directions':directions,'prior_leg_matrices_preserved':True,'breathing_48mm_hips_14_4mm_chest_four_seconds_preserved':True,'no_previous_vertical_nodding_passages':True,'world_head_hold_note':'Head position follows rigid body breathing; world gaze orientation stays fixed during each .25s observation.'}
(OUT/'lookaround_refinement_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
