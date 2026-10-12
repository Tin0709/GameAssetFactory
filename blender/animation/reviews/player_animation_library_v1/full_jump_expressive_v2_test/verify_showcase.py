"""Fresh reopen; all fourteen entries, action slots, reset and evaluated geometry."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/full_jump_expressive_v2_test';S=R/'blender/animation/showcase';sys.path.insert(0,str(S));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert Path(bpy.data.filepath).resolve()==(S/'Animation_Showcase.blend').resolve() and hasattr(bpy.types,'GAF_PT_animation_library')
entries=json.loads((S/'animation_manifest.json').read_text())['animations'];old=json.loads((T/'baseline.json').read_text())['original_entries']
assert len(entries)==len(s.gaf_clips)==len(bpy.data.actions)==15 and len(bpy.data.armatures)==1 and len(bpy.data.meshes)==2 
for e in entries:assert ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] and sha(R/e['source'])==e['source_sha256']
assert entries[-1]['status']=='pending' and not entries[-1]['seamless_loop']
for before,after in zip(old,entries):
 if before['action']=='Run_Expressive_v3_Test':
  assert after['status']=='approved' and after['preferred_run_baseline'] and {k:v for k,v in before.items() if k not in ['status','approval_note','preferred_run_baseline']}=={k:v for k,v in after.items() if k not in ['status','approval_note','preferred_run_baseline']}
 else:assert before==after
baseline=json.loads((R/'.validation/animation_showcase/source_audit.json').read_text())
for action,folder in [('Jump_Takeoff_Test','jump_takeoff_test'),('Jump_AirPose_Test','jump_airpose_test'),('Jump_Landing_Test','jump_landing_test'),('Jump_Landing_Impact_Test','jump_landing_impact_test'),('Full_Jump_Expressive_Test','full_jump_expressive_test'),('Idle_Expressive_Test','idle_expressive_test'),('Idle_Expressive_Test_v2','idle_expressive_test_v2'),('Idle_Expressive_Test_v3','idle_expressive_test_v3'),('Walk_Expressive_Test','walk_expressive_test'),('Run_Expressive_v2_Test','run_expressive_v2_test'),('Run_Expressive_v3_Test','run_expressive_v3_test'),('Full_Jump_Expressive_v2_Test','full_jump_expressive_v2_test')]:baseline[action]={'samples':json.loads((O.parent/folder/'validation.json').read_text())['frames']}
maximum=0.;count=0;order=[14]+list(range(14))+[14,7,14,13,14,0,14]
for index in order:
 if s.gaf_active_index==index:ui.activate(s,index)
 else:s.gaf_active_index=index
 e=entries[index];assert not s.gaf_error and r.animation_data.action.name==e['action'] and r.animation_data.action_slot.identifier==e['slot_identifier']
 assert [s.frame_start,s.frame_end,s.render.fps,s.render.fps_base]==[e['start'],e['end'],e['fps'],e['fps_base']] and r.matrix_world==Matrix.Identity(4)
 assert abs(bpy.data.objects['Showcase_FixedFloor'].location.z-e.get('preview_floor_z_m',0))<1e-6
 samples=baseline[e['action']]['samples'];indices=[0,len(samples)//2,len(samples)-1] if index!=14 else [0,17,23,31,32,37,44,45,50,66,92]
 for n in indices:
  item=samples[n];f=item['frame'];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();obj=m.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[obj.matrix_world@v.co for v in obj.data.vertices];maximum=max(maximum,max((p-Vector(q)).length for p,q in zip(points,item['vertices'])));count+=1
assert maximum<2e-6
e=entries[-1];report={'passed':True,'fresh_reopen':True,'entries':15,'switches':len(order),'geometry_samples':count,'maximum_source_geometry_error_m':maximum,'all_fourteen_existing_actions_unchanged_only_run_v3_approval_metadata_updated':True,'one_rig_one_character_mesh':True,'slots_ranges_fps_reset_and_loop':True,'source_sha256':e['source_sha256'],'action_sha256':e['action_sha256'],'showcase_sha256':sha(S/'Animation_Showcase.blend'),'manifest_sha256':sha(S/'animation_manifest.json')}
(O/'showcase_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
