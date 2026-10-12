"""Fresh reopen: twelve independent Actions, slots/timing/reset/source geometry."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/run_expressive_v2_test';SHOW=ROOT/'blender/animation/showcase'
sys.path.insert(0,str(SHOW));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert Path(bpy.data.filepath).resolve()==(SHOW/'Animation_Showcase.blend').resolve() and hasattr(bpy.types,'GAF_PT_animation_library')
entries=json.loads((SHOW/'animation_manifest.json').read_text())['animations'];old=json.loads((TMP/'files/blender/animation/showcase/animation_manifest.json').read_text())['animations']
assert len(entries)==len(s.gaf_clips)==len(bpy.data.actions)==13 and len(bpy.data.armatures)==1 and len(bpy.data.meshes)==2
for before,after in zip(old,entries):
 if before['action']=='Walk_Expressive_Test':
  assert after['status']=='approved' and {k:v for k,v in before.items() if k not in ['status','approval_note']}=={k:v for k,v in after.items() if k not in ['status','approval_note']}
 else:assert before==after
 assert ui.action_signature(bpy.data.actions[before['action']])==before['action_sha256']
walk=entries[-1];assert walk['action']=='Run_Expressive_v2_Test' and walk['status']=='pending' and walk['seamless_loop'] and walk['closing_key']==23
baseline=json.loads((ROOT/'.validation/animation_showcase/source_audit.json').read_text())
for action,folder in [('Jump_Takeoff_Test','jump_takeoff_test'),('Jump_AirPose_Test','jump_airpose_test'),('Jump_Landing_Test','jump_landing_test'),('Jump_Landing_Impact_Test','jump_landing_impact_test'),('Full_Jump_Expressive_Test','full_jump_expressive_test'),('Idle_Expressive_Test','idle_expressive_test'),('Idle_Expressive_Test_v2','idle_expressive_test_v2'),('Idle_Expressive_Test_v3','idle_expressive_test_v3'),('Walk_Expressive_Test','walk_expressive_test'),('Run_Expressive_v2_Test','run_expressive_v2_test')]:
 baseline[action]={'samples':json.loads((OUT.parent/folder/'validation.json').read_text())['frames']}
maximum=0.;geometry_samples=0;order=[12]+list(range(12))+[12,11,12,1,12,0,12]
for index in order:
 if s.gaf_active_index==index:ui.activate(s,index)
 else:s.gaf_active_index=index
 assert not s.gaf_error,s.gaf_error
 e=entries[index];a=r.animation_data.action
 assert a.name==e['action'] and r.animation_data.action_slot.identifier==e['slot_identifier']
 assert [s.frame_start,s.frame_end,s.render.fps,s.render.fps_base]==[e['start'],e['end'],e['fps'],e['fps_base']]
 assert ui.action_signature(a)==e['action_sha256'] and r.matrix_world==Matrix.Identity(4)
 assert abs(bpy.data.objects['Showcase_FixedFloor'].location.z-e.get('preview_floor_z_m',0))<1e-6
 samples=baseline[e['action']]['samples'];indices=[0,len(samples)//2,len(samples)-1] if index!=12 else [0,2,5,10,11,16,21,22]
 for n in indices:
  sample=samples[n];f=sample['frame'];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();obj=m.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[obj.matrix_world@v.co for v in obj.data.vertices]
  maximum=max(maximum,max((p-Vector(q)).length for p,q in zip(points,sample['vertices'])));geometry_samples+=1
 assert sha(ROOT/e['source'])==e['source_sha256']
assert maximum<2e-6
report={'passed':True,'fresh_reopen':True,'entries':[(e['action'],e['status']) for e in entries],'switches':len(order),'geometry_samples':geometry_samples,'max_source_vertex_error_m':maximum,'all_twelve_previous_actions_and_sources_preserved':True,'only_walk_approval_metadata_changed':True,'one_rig_one_character_mesh':True,'slots_ranges_fps_and_pose_reset':True,'preview_floor_reset':True,'loop_enabled':s.gaf_loop,'source_sha256':walk['source_sha256'],'action_sha256':walk['action_sha256'],'showcase_sha256':sha(SHOW/'Animation_Showcase.blend'),'manifest_sha256':sha(SHOW/'animation_manifest.json')}
(OUT/'showcase_verification.json').write_text(json.dumps(report,indent=2));print('THIRTEEN ACTIONS REOPEN/SWITCH VERIFIED',json.dumps(report),flush=True)
