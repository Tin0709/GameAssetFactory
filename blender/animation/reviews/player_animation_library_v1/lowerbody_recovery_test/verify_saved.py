"""Fresh-process read-only validation of the actual saved study."""
import bpy,json,runpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve()==(OUT/'lowerbody_recovery_review.blend').resolve()
r=runpy.run_path(str(OUT/'validate_test.py'))['run']()
assert r['old_actions']==328 and r['actions_now']==329
assert r['changed_originals']==[] and r['source_files_unchanged']
assert r['same_mesh'] and r['same_rest'] and r['no_scale_tracks'] and r['root_static']
assert r['max_rigid_distance_error_m']<1e-6
assert r['min_sole_z_m']>=0 and r['max_support_height_error_m']<.001
assert r['max_contact_corner_xy_error_m']<.0001
assert r['unsupported_samples']==0 and not r['overlaps']
assert .12<r['hip_compression_from_ready_m']<.13
assert list(bpy.data.actions['LowerBody_Recovery_Test'].frame_range)==[1,48]
r['verified_saved_file']=True
(OUT/'saved_file_verification.json').write_text(json.dumps(r,indent=2))
print('SAVED STUDY VERIFIED: 328 protected Actions; 329 total; rigid geometry; fixed support corners; no new nonadjacent intersections; original source files unchanged.',flush=True)
