import bpy,json,sys,math,hashlib,importlib.util
from pathlib import Path
from mathutils import Matrix
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
from source_motion import RUN,channel,RATE
manifest=json.loads((HERE/'manifest.json').read_text());state=json.loads((HERE/'preservation_before.json').read_text())
spec=importlib.util.spec_from_file_location('run_research_viewer_validation',HERE/'gaf_animation_library.research.py');ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui)
rig=bpy.data.objects[manifest['source_rig']];mesh=bpy.data.objects[manifest['source_mesh']];scene=bpy.context.scene;a=bpy.data.actions[manifest['action']]
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==manifest['source_sha256']
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in manifest['previous_action_signatures'].items())
assert ui.rest_signature(rig.data)==manifest['rig_sha256']
entry=dict(manifest,slot_identifier=a.slots[0].identifier,action_sha256=ui.action_signature(a),action_frame_range=list(a.frame_range),fps_base=1.,rotation_modes={b.name:b.rotation_mode for b in rig.pose.bones})
ui.validate_action(a,entry,rig)
rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
expected=json.loads((HERE/'expected_matrices.json').read_text())
groups={side:[v.index for v in mesh.data.vertices if any(g.group==mesh.vertex_groups['Leg.'+side].index and g.weight>.99 for g in v.groups)]for side in ['L','R']}
maximum={n:0. for n in rig.pose.bones.keys()};max_scale_error=0.;minimum=10.;max_forearm=0.;geometry=[]
for row in expected:
 f=row['frame'];scene.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
 for n,target in row['matrices'].items():maximum[n]=max(maximum[n],max(abs(rig.pose.bones[n].matrix[i][j]-target[i][j])for i in range(4)for j in range(4)))
 for side in ['L','R']:
  actual=rig.pose.bones['Leg.'+side].scale[1];wanted=channel(RUN,'leftleg'if side=='L'else'rightleg','scale',(row['time_s']*RATE)%1)[1]
  max_scale_error=max(max_scale_error,abs(actual-wanted))
 for n in ['ForeArm.L','ForeArm.R']:max_forearm=max(max_forearm,max(abs(rig.pose.bones[n].matrix_basis[i][j]-Matrix.Identity(4)[i][j])for i in range(4)for j in range(4)))
 ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());verts=[ev.matrix_world@v.co for v in ev.data.vertices]
 item={'time_s':row['time_s'],'hip_z':rig.pose.bones['Hips'].matrix.translation.z}
 for side in ['L','R']:
  low=min(verts[j].z for j in groups[side]);item[side+'_lowest_z']=low;item[side+'_scale_y']=rig.pose.bones['Leg.'+side].scale[1]
  minimum=min(minimum,low-manifest['preview_floor_z_m'])
 geometry.append(item)
report={'source_file_sha256':manifest['source_sha256'],'action_sha256':ui.action_signature(a),'expected_transform_samples':len(expected),
 'maximum_matrix_component_error_by_bone':maximum,'maximum_matrix_component_error':max(maximum.values()),
 'maximum_original_scale_channel_error':max_scale_error,'maximum_forearm_basis_error':max_forearm,
 'minimum_clearance_over_display_floor_m':minimum,'display_floor_z_m':manifest['preview_floor_z_m'],
 'all_previous_action_signatures_exact':len(manifest['previous_action_signatures']),
 'research_only':True,'source_scale_retained':True,'original_key_times_retained':manifest['original_breakpoints'],
 'short_composite_loop_claim':False,'controller_profile':manifest['profile'],
 'geometry_is_native_retarget_not_original_minecraft':True,'runtime_semantics_not_fully_emulated':True}
report['passed']=report['maximum_matrix_component_error']<4e-5 and max_scale_error<8e-6 and max_forearm<2e-6 and minimum>-.00002
(HERE/'source_validation.json').write_text(json.dumps(report,indent=2));(HERE/'native_geometry_samples.research_only.json').write_text(json.dumps(geometry))
print(json.dumps(report,indent=2),flush=True)
assert report['passed'],'Saved source bake deviates from evaluated source/profile transforms'
