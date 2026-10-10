"""Read-only fresh-process verification of the standalone study blend."""
import bpy,json,runpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve()==(OUT/'expressive_arm_motion_review.blend').resolve()
result=runpy.run_path(str(OUT/'validate_test.py'))['run']()
assert result['unexpected_original_changes']==[]
assert result['old_action_count']==326 and result['total_actions']==327
assert result['original_library_hash_unchanged']
assert result['same_mesh_datablock'] and result['same_rest_matrices'] and result['no_nla_or_drivers']
assert result['action_range']==[1,24]
assert result['neutral_return_error_m']<1e-6 and result['max_foot_drift_m']<1e-6
assert result['max_segment_distance_error_m']<1e-6
full=json.loads((OUT/'validation.json').read_text())
assert not [x for x in full['new_nonadjacent_overlaps'] if x[0] in [1,7,14,24]]
result['fresh_saved_file_verified']=True
(OUT/'saved_file_verification.json').write_text(json.dumps(result,indent=2))
print('SAVED STUDY VERIFIED: 326 old Actions preserved, 24-frame new Action, unchanged original source.')
