"""First-pass turning V2: evaluate straight V2, then author bounded turn response."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'turning_study_r3_review';DEV=BASE/'player_locomotion_turning_v2_study.blend';assert Path(bpy.data.filepath)==DEV
OUT.mkdir(exist_ok=True);revise=globals().get('REVISE_R3',False)
names=[g+'_Turn'+d+'_Reference_V2' for g in PERIOD for d in ['Left','Right']]
if not revise:
 assert all(n not in bpy.data.actions for n in names)
 protected=preserve()
 for n in ['player_locomotion_turning_study.blend','player_locomotion_straight_v2_study.blend']:protected['files'][n]=hashlib.sha256((BASE/n).read_bytes()).hexdigest()
 (OUT/'preservation_before.json').write_text(json.dumps(protected,indent=2))
 s=bpy.data.scenes.new('R3_Turn_Authoring');s.use_fake_user=True;bpy.context.window.scene=s;r,mesh=copy_character(s,'R3_Author')
else:
 protected=json.loads((OUT/'preservation_before.json').read_text());check_preserved(protected);s=bpy.data.scenes['R3_Turn_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_R3_Author_Rig'];mesh=bpy.data.objects['R2_R3_Author_Mesh']
points=mesh_points(mesh)
def wave(t):
 # Shaped acceptance/rise, repeated per step, not a constant bank.
 vals=[.25,1,.7,-.15,-1,-.65,-.15,.1];x=(t%1)*8;i=int(x);u=x-i
 p0,p1,p2,p3=[vals[j%8] for j in [i-1,i,i+1,i+2]]
 return .5*(2*p1+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)
descriptions=[]
for gait,period in PERIOD.items():
 base=bpy.data.actions[gait+'_ReferenceStudy_V2'];fast=gait=='Sprint'
 for direction,sign in [('Left',1),('Right',-1)]:
  poses=[];banks=[];corrections=[]
  for i in range(128):
   t=i/128;ps=sample(r,s,base,1+period*t);clearance=floor_min(r,points);apply(r,ps)
   hip=(7.5 if fast else 4.4)+(1.1 if fast else .6)*wave(2*t)
   spine=.25+.07*wave(2*t-.07);chest=.20+.05*wave(2*t-.18);bank=hip+spine+chest
   def delta(n,y=0,z=0):
    p=r.pose.bones[n];p.rotation_euler.y+=math.radians(sign*y);p.rotation_euler.z+=math.radians(sign*z)
   # Character forward -Y, left +X; positive world-Z yaw is local left.
   delta('Hips',(.65 if fast else .35)*(1+.1*wave(2*t)),-hip)
   r.pose.bones['Hips'].location.x+=sign*(.010 if fast else .006)*(1+.12*wave(2*t))
   delta('Spine',(.4 if fast else .25)*(1+.12*wave(2*t-.09)),-spine)
   delta('Chest',(.6 if fast else .35)*(1+.1*wave(2*t-.2)),-chest)
   # The cuboid neck seam cannot support strong independent head counter-bank.
   delta('Neck',.8 if fast else .5,bank*.09);delta('Head',1 if fast else .7,bank*.11)
   for side in ['L','R']:
    # Small gait-weighted balance roll; preserve V2 pitch, twist and root path.
    forward=max(0,min(1,(math.degrees(ps['Arm.'+side][1].x)-12)/(67 if fast else 44)))
    delta('Arm.'+side,0,(.45 if fast else .30)*(.6+.4*forward))
    if fast and side==('L' if sign>0 else 'R'):
     # Four millimetres of forward-weighted inside-shoulder clearance prevents
     # the banked head corner meeting the raised arm; no change to pitch/twist.
     r.pose.bones['Arm.'+side].location.x+=(-1 if side=='L' else 1)*.004*forward**2
   bpy.context.view_layer.update();dy=clearance-floor_min(r,points)+.0015;r.pose.bones['Hips'].location.y+=dy;bpy.context.view_layer.update()
   poses.append({n:(r.pose.bones[n].location.copy(),r.pose.bones[n].rotation_euler.copy()) for n in BODY});banks.append(bank);corrections.append(dy)
  poses.append(poses[0]);name=gait+'_Turn'+direction+'_Reference_V2';a=bpy.data.actions[name] if revise else bpy.data.actions.new(name);a.use_fake_user=True
  for i,ps in enumerate(poses):key_pose(r,a,1+period*i/128,ps)
  periodic(a,period)
  a['fps']=24;a['cycle_frames']=period;a['cycle_seconds']=period/24
  a['base']=base.name;a['composition']='Absolute full-pose crossfade at shared normalized V2 gait phase; never add full poses. Separate PREVIEW parents own world translation/yaw.'
  a['phase']='phi=((f-1)/period)%1. phi0 right reach, left arm forward; phi.5 opposite. Same clock as straight V2. Author labels are not source foot-contact claims.'
  a['direction']='Character-relative '+direction.lower()+': forward -Y, left +X; left world-Z yaw positive regardless of camera.'
  a['scope']='Sustained curve body language; not a one-shot turn; no scale/weapon keys or accumulated Root.'
  if not revise:
   for m in base.pose_markers:a.pose_markers.new(m.name).frame=m.frame
  descriptions.append({'action':name,'seconds':period/24,'signed_direction':sign,'added_axial_bank_deg_range':[min(banks),max(banks)],'hips_floor_correction_m_range':[min(corrections),max(corrections)],'head_turn_bank_retained_fraction':.80})
(OUT/'design_values.json').write_text(json.dumps(descriptions,indent=2));s.render.fps=24;s.render.fps_base=1;s.frame_start=1;s.frame_end=16;assign(r,bpy.data.actions[names[0]]);s.frame_set(1)
check_preserved(protected);bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={'file':str(DEV),'new_actions':names,'preserved_actions':len(protected['actions']),'design':descriptions}
