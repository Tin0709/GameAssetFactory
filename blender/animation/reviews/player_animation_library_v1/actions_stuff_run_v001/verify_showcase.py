"""Fresh disk reopen: source transforms, registration, selection and scale reset."""
import bpy,json,sys,hashlib
from pathlib import Path
STAGE=Path(__file__).resolve().parent
state=json.loads((STAGE/'preservation_before.json').read_text());meta=json.loads((STAGE/'manifest.json').read_text())
ROOT=Path(state['project']);OUT=Path(state['package_destination']);LIB=ROOT/'blender/animation/showcase'
sys.path.insert(0,str(LIB));import gaf_animation_library as ui
ui.register();s=bpy.context.scene;ui.loaded(None)
manifest=ui.load_manifest();rig=bpy.data.objects[ui.RIG]
assert manifest['animations'][:-1]==state['entries_before']
assert len(bpy.data.actions)==len(s.gaf_clips)==len(manifest['animations'])==37
assert s.gaf_active_index==36 and not s.gaf_loop and not s.gaf_error
for name,h in meta['previous_action_signatures'].items():assert ui.action_signature(bpy.data.actions[name])==h,name
assert ui.refresh(s,import_missing=False)==0
for i,e in enumerate(manifest['animations']):
 ui.activate(s,i);a=bpy.data.actions[e['action']]
 assert rig.animation_data.action==a and rig.animation_data.action_slot==a.slots[0]
 assert [s.frame_start,s.frame_end,s.render.fps,s.render.fps_base]==[e['start'],e['end'],e['fps'],e['fps_base']]
 ui.validate_action(a,e,rig)
 assert ui.rest_signature(rig.data)==manifest['rig_sha256']
 assert abs(bpy.data.objects['Showcase_FixedFloor'].location.z-e.get('preview_floor_z_m',0.))<1e-7
s.gaf_active_index=36;ui.activate(s,36)
entry=manifest['animations'][-1]
assert entry['research_only'] is True and entry['production_eligible'] is False and entry['status']=='pending'
assert entry['seamless_loop'] is False and entry['endpoint_sample']==181
assert entry['research_scale_channels']==meta['research_scale_channels']
maximum=0.;expected=json.loads((STAGE/'expected_matrices.json').read_text())
for row in expected:
 f=row['frame'];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
 for n,target in row['matrices'].items():
  maximum=max(maximum,max(abs(rig.pose.bones[n].matrix[r][c]-target[r][c]) for r in range(4) for c in range(4)))
assert maximum<4e-5
a=bpy.data.actions[state['action']]
c=next(c for c in ui.curves(a) if c.data_path=='pose.bones["Leg.L"].scale' and c.array_index==1)
peak=max(c.keyframe_points,key=lambda k:k.co.y).co.x
reset_checks=[]
for target in ['Run_Snappy_Test_v001','Walk_ActionsStuff_Source_Test_v001','Idle_Expressive_Test_v3']:
 ui.activate(s,36);s.frame_set(int(peak),subframe=peak%1);bpy.context.view_layer.update()
 assert rig.pose.bones['Leg.L'].scale[1]>1.06
 index=next(i for i,e in enumerate(manifest['animations']) if e['action']==target)
 ui.activate(s,index);bpy.context.view_layer.update()
 assert max(abs(v-1.) for b in rig.pose.bones for v in b.scale)<1e-6,target
 reset_checks.append(target)
ui.activate(s,36);s.frame_set(1);bpy.context.view_layer.update()
first={p.name:p.matrix.copy() for p in rig.pose.bones}
rig.pose.bones['Head'].location.z+=.3
ui.activate(s,0);ui.activate(s,36);bpy.context.view_layer.update()
reset_error=max(abs(first[p.name][r][c]-p.matrix[r][c]) for p in rig.pose.bones for r in range(4) for c in range(4))
assert reset_error<1e-6
s.frame_set(181);bpy.context.view_layer.update()
boundary=max(abs(first[p.name][r][c]-p.matrix[r][c]) for p in rig.pose.bones for r in range(4) for c in range(4))
assert boundary>1e-4 # Independent source clocks: intentionally NOT a synthetic short loop.
for d in ['FRONT','THREE_QUARTER','SIDE']:
 ui.view(s,d);assert s.camera.name=='Showcase_'+d
report={'passed':True,'reopened_from_disk':True,'all_actions_selectable':37,
 'previous_action_signatures_exact':36,'old_manifest_entries_exact':36,'source_files_hash_checked':37,
 'active_slots_timing_rest_and_floor_pass':True,'saved_pending_selection_and_loop_disabled_pass':True,
 'source_matrix_samples':len(expected),'maximum_matrix_component_error':maximum,
 'scale_reset_targets':reset_checks,'pose_reset_maximum_error':reset_error,'three_cameras_pass':True,
 'full_take_seamless':False,'endpoint_matrix_difference':boundary,'no_fabricated_composite_seam':True,
 'candidate':state['action'],'candidate_status':'pending','no_gui_playback_claim':True}
for folder in [STAGE,OUT]:(folder/'showcase_validation.json').write_text(json.dumps(report,indent=2))
print('FRESH_SHOWCASE_REOPEN_PASSED',json.dumps(report),flush=True)
