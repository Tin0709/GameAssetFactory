"""Read-only fresh-process check; never saves a Blender file."""
import bpy,runpy,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve()==(OUT/'run_expressive_review.blend').resolve()
result=runpy.run_path(str(OUT/'validate_run.py'))['run'](preservation=True)
assert result['changed_originals']==[],result['changed_originals']
assert result['old_actions']==327 and result['actions_now']==328
assert result['source_hash_unchanged'] and result['same_mesh'] and result['same_rest']
assert result['max_rigid_distance_error_m']<1e-6
assert result['min_floor_z_m']>=-1e-5 and result['max_contact_height_error_m']<.001
assert result['max_contact_world_y_drift_m']<.001
assert not result['overlaps']
assert result['loop_vertex_error_m']<1e-6 and result['repeat_error_m']<1e-6
h=runpy.run_path(str(OUT/'build_run.py'))
a=bpy.data.actions['Run_Expressive_Test'];assert list(a.frame_range)==[1,19]
assert not any(c.data_path.endswith('scale') for c in h['H']['curves'](a))
values=[];tangents=[]
for c in h['H']['curves'](a):
    first,last=c.keyframe_points[0],c.keyframe_points[-1]
    values.append(abs(first.co.y-last.co.y))
    ta=(first.handle_right.y-first.co.y)/(first.handle_right.x-first.co.x)
    tb=(last.co.y-last.handle_left.y)/(last.co.x-last.handle_left.x)
    tangents.append(abs(ta-tb))
assert max(values)<1e-7 and max(tangents)<1e-4
result['endpoint_channel_error']=max(values);result['endpoint_tangent_error']=max(tangents)
result['verified_saved_file']=True
(OUT/'saved_file_verification.json').write_text(json.dumps(result,indent=2))
print('RUN SAVED FILE VERIFIED: 327 protected Actions, rigid geometry, support drift <1 mm, no nonadjacent intersections, periodic endpoints/tangents.')
