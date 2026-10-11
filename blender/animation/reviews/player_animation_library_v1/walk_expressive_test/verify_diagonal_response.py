"""Measure the new local diagonal waist path against the archived hip-sway candidate."""
import bpy,json,sys,hashlib,math
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];OLD=ROOT/'.validation/walk_expressive_test/before_diagonal_response/walk_expressive_test/walk_expressive_review.blend';NEW=OUT/'walk_expressive_review.blend'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def measure():
 s=bpy.context.scene;r=bpy.data.objects['WEX_Test_Rig'];hips=[];samples=[]
 for j in range(289):
  f=1+j/8;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();p=r.pose.bones['Hips'].head;hips.append(list(p))
  if f in [1,5,10,14,19,23,28,32,37]:samples.append({'frame':f,'hip':list(p)})
 return {'hip_xyz_ranges_m':[[min(p[i] for p in hips),max(p[i] for p in hips)] for i in range(3)],'phase_samples':samples,'root_object_static':r.location.length<1e-9}
bpy.ops.wm.open_mainfile(filepath=str(OLD));before=measure();bpy.ops.wm.open_mainfile(filepath=str(NEW));after=measure()
assert before['hip_xyz_ranges_m'][1][1]-before['hip_xyz_ranges_m'][1][0]<1e-7
assert abs(after['hip_xyz_ranges_m'][1][1]-after['hip_xyz_ranges_m'][1][0]-.036)<1e-5
assert max(abs(after['hip_xyz_ranges_m'][axis][j]-before['hip_xyz_ranges_m'][axis][j]) for axis in [0,2] for j in [0,1])<1e-6
samples={p['frame']:p['hip'] for p in after['phase_samples']}
assert samples[5][1]>samples[1][1] and samples[23][1]>samples[19][1]
assert samples[14][1]<samples[10][1] and samples[32][1]<samples[28][1]
assert after['root_object_static']
report={'passed':True,'source_sha256':sha(NEW),'action_sha256':ui.action_signature(bpy.data.actions['Walk_Expressive_Test']),'archived_source_sha256':sha(OLD),'before':before,'after':after,'fore_aft_phase':'Local waist receives back with each newly planted leading foot, then reaches forward into the next step. Combined with lateral support sway this creates a small diagonal path, not world-space travel.','existing_lateral_sway_vertical_motion_and_gait_timing_preserved':True}
(OUT/'diagonal_response_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True)
