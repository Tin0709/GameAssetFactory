"""R5: author four new Actions in a new study file after measured remap-only review."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
SOURCE=BASE/'player_locomotion_turning_v2_study.blend'
DEV=BASE/'player_locomotion_turning_v3_study.blend'
OUT=BASE/'turning_study_r5_review';OUT.mkdir(exist_ok=True)
assert Path(bpy.data.filepath)==SOURCE
protected=preserve();protected['files'][SOURCE.name]=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
(OUT/'preservation_before.json').write_text(json.dumps(protected,indent=2))
s=bpy.data.scenes.new('R5_Turn_Authoring');s.use_fake_user=True;bpy.context.window.scene=s
r,mesh=copy_character(s,'R5_Author');points=mesh_points(mesh)
# Reuse the established periodic weight-acceptance shape; do not execute R3 authoring.
source=(BASE/'create_turning_r3.py').read_text();exec(source[source.index('def wave('):source.index('descriptions=[]')])
design=[]
for gait,period in PERIOD.items():
 base=bpy.data.actions[gait+'_ReferenceStudy_V2'];fast=gait=='Sprint'
 for direction,sign in [('Left',1),('Right',-1)]:
  poses=[];values=[];corrections=[]
  for i in range(128):
   t=i/128;ps=sample(r,s,base,1+period*t);clearance=floor_min(r,points);apply(r,ps)
   hip=(8.0 if fast else 4.7)+(1.0 if fast else .55)*wave(2*t)
   spine=(1.5 if fast else .9)+(.24 if fast else .15)*wave(2*t-.08)
   chest=(2.6 if fast else 1.4)+(.45 if fast else .26)*wave(2*t-.18)
   bank=hip+spine+chest
   def delta(n,y=0,z=0):
    p=r.pose.bones[n];p.rotation_euler.y+=math.radians(sign*y);p.rotation_euler.z+=math.radians(sign*z)
   delta('Hips',(.7 if fast else .4)*(1+.12*wave(2*t)),-hip)
   r.pose.bones['Hips'].location.x+=sign*(.016 if fast else .009)*(1+.15*wave(2*t))
   delta('Spine',(.7 if fast else .4)*(1+.16*wave(2*t-.08)),-spine)
   delta('Chest',(1.4 if fast else .8)*(1+.22*wave(2*t-.18)),-chest)
   # Small compensation only: the rigid head/chest seam cannot support leveling.
   counter=min(bank*.14,1.65)
   delta('Neck',.9 if fast else .55,counter*.45)
   delta('Head',1.1 if fast else .7,counter*.55)
   for side in ['L','R']:
    forward=max(0,min(1,(math.degrees(ps['Arm.'+side][1].x)-12)/(67 if fast else 44)))
    delta('Arm.'+side,0,(.8 if fast else .45)*(.55+.45*forward))
    if fast and side==('L' if sign>0 else 'R'):
     r.pose.bones['Arm.'+side].location.x+=(-1 if side=='L' else 1)*.008*forward**2
   bpy.context.view_layer.update()
   dy=clearance-floor_min(r,points)+.0015;r.pose.bones['Hips'].location.y+=dy;bpy.context.view_layer.update()
   poses.append({n:(r.pose.bones[n].location.copy(),r.pose.bones[n].rotation_euler.copy()) for n in BODY})
   values.append({'hip':hip,'spine':spine,'chest':chest,'total':bank,'counter':counter});corrections.append(dy)
  poses.append(poses[0]);name=gait+'_Turn'+direction+'_Reference_V3'
  assert name not in bpy.data.actions
  a=bpy.data.actions.new(name);a.use_fake_user=True
  for i,ps in enumerate(poses):key_pose(r,a,1+period*i/128,ps)
  periodic(a,period)
  a['fps']=24;a['cycle_frames']=period;a['cycle_seconds']=period/24;a['base']=base.name
  a['scope']='R5 isolated study only. Same-phase absolute pose; no root motion, scale, weapons or production cadence changes.'
  a['direction']='Character-relative '+direction.lower()+'; forward -Y, left +X.'
  a['design']='Phase-shaped Hips weight transfer; delayed smaller Spine, delayed Chest bank/yaw; limited Head/Neck counterbank; unchanged straight V2 leg and arm pitch/twist channels.'
  for m in base.pose_markers:a.pose_markers.new(m.name).frame=m.frame
  design.append({'action':name,'duration':period/24,'bank_degrees':{key:[min(v[key] for v in values),max(v[key] for v in values)] for key in values[0]},'hips_floor_correction_m':[min(corrections),max(corrections)]})
(OUT/'design.json').write_text(json.dumps(design,indent=2))
check_preserved(protected)
s.render.fps=24;s.render.fps_base=1;s.frame_start=1;s.frame_end=16;assign(r,bpy.data.actions['Walk_TurnLeft_Reference_V3']);s.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
print('R5_CREATED',json.dumps(design),flush=True)
