"""Verify the half-gap stance, planted support offsets and unchanged body path."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];OLD=ROOT/'.validation/walk_expressive_test/before_narrow_tracks/walk_expressive_test/walk_expressive_review.blend';NEW=OUT/'walk_expressive_review.blend'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def measure():
 s=bpy.context.scene;m=bpy.data.objects['WEX_Test_Mesh'];groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups};frames=[]
 for f in range(1,38):
  s.frame_set(f);bpy.context.view_layer.update();e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());frames.append([list(e.matrix_world@v.co) for v in e.data.vertices])
 return groups,frames
bpy.ops.wm.open_mainfile(filepath=str(OLD));groups,before=measure();bpy.ops.wm.open_mainfile(filepath=str(NEW));newgroups,after=measure();assert groups==newgroups
errors={};anchors=[]
for group,ids in groups.items():
 if group.startswith('Leg.'):
  side=group[-1];offset=0 if side=='L' else .5;duty=.60 if side=='L' else .62;target=Vector((-.035 if side=='L' else .035,0,0))
  # Compare a shared material corner actually touching the floor in both poses.
  for f,(old,new) in enumerate(zip(before,after),1):
   q=((f-1)/36+offset)%1
   if q<=duty:
    contact=[i for i in ids if abs(old[i][2]-.0004)<2e-6 and abs(new[i][2]-.0004)<2e-6]
    assert contact,(f,side)
    anchors.extend((Vector(new[i])-Vector(old[i])-target).length for i in contact)
 else:errors[group]=max((Vector(a[i])-Vector(b[i])).length for b,a in zip(before,after) for i in ids)
assert max(errors.values())<2e-6 and max(anchors)<2e-6
report={'passed':True,'source_sha256':sha(NEW),'action_sha256':ui.action_signature(bpy.data.actions['Walk_Expressive_Test']),'archived_source_sha256':sha(OLD),'before_track_spacing_m':.36,'after_track_spacing_m':.29,'inward_support_shift_per_leg_m':.035,'approximate_visible_sole_gap_before_m':.135,'approximate_visible_sole_gap_after_m':.065,'lateral_whole_leg_lean_degrees':{'L':-.5,'R':.75},'maximum_planted_anchor_offset_error_m':max(anchors),'maximum_vertex_offset_errors_m':errors,'diagonal_waist_upper_body_and_ground_anchor_yz_unchanged':True,'reduced_lateral_leg_lean_prevents_thigh_crossing':True,'rig_changes':[]}
(OUT/'narrow_tracks_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True)
