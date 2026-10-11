"""Measure the requested half sway against the immediately preceding saved walk."""
import bpy,sys,json,math,hashlib,runpy
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];BACK=ROOT/'.validation/walk_expressive_test/before_quieter_sway/walk_expressive_test';NEW=OUT/'walk_expressive_review.blend'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def measure(path):
 bpy.ops.wm.open_mainfile(filepath=str(path));s=bpy.context.scene;r=bpy.data.objects['WEX_Test_Rig'];hip=[];roll={n:[] for n in ['Hips','Spine','Chest']}
 for j in range(289):
  f=1+j/8;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();hip.append(list(r.pose.bones['Hips'].head))
  for n in roll:roll[n].append(math.degrees((r.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted()).to_euler('XYZ').y))
 return {'hip_xyz_ranges_m':[[min(p[i] for p in hip),max(p[i] for p in hip)] for i in range(3)],'world_lateral_roll_span_deg':{n:max(a)-min(a) for n,a in roll.items()}}
before=measure(BACK/'walk_expressive_review.blend');after=measure(NEW)
span=lambda d,i:d['hip_xyz_ranges_m'][i][1]-d['hip_xyz_ranges_m'][i][0]
assert abs(span(after,0)/span(before,0)-.5)<1e-4
for n in after['world_lateral_roll_span_deg']:assert abs(after['world_lateral_roll_span_deg'][n]/before['world_lateral_roll_span_deg'][n]-.5)<.01
assert max(abs(after['hip_xyz_ranges_m'][i][j]-before['hip_xyz_ranges_m'][i][j]) for i in [1,2] for j in [0,1])<1e-6
old=runpy.run_path(str(BACK/'build_walk.py'));new=runpy.run_path(str(OUT/'build_walk.py'))
for j in range(289):
 for side in ['L','R']:
  o=old['foot'](j/288,side);n=new['foot'](j/288,side)
  assert o[:2]==n[:2] and abs(o[3]-n[3])<1e-12
  assert abs(n[2].x-o[2].x-(-.01 if side=='L' else .01))<1e-7 and abs(n[2].y-o[2].y)<1e-8
v=json.loads((OUT/'validation.json').read_text());assert v['passed'] and v['source_sha256']==sha(NEW)
report={'passed':True,'source_sha256':sha(NEW),'action_sha256':ui.action_signature(bpy.data.actions['Walk_Expressive_Test']),'archived_source_sha256':sha(BACK/'walk_expressive_review.blend'),'before':before,'after':after,'lateral_hip_and_body_roll_halved':True,'before_track_spacing_m':.29,'after_track_spacing_m':.27,'inward_anchor_shift_per_leg_m':.01,'fore_aft_vertical_contact_timing_preserved':True,'support_and_intersections_pass_saved_source_checks':True,'rig_changes':[]}
(OUT/'quieter_refinement_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
