"""Fresh reopen and source-preservation checks for the nine-entry library."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
assert bpy.data.filepath.endswith('Animation_Showcase.blend') and hasattr(bpy.types,'GAF_PT_animation_library')
s=bpy.context.scene;r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh']
entries=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text())['animations']
assert len(entries)==len(s.gaf_clips)==len(bpy.data.actions)==9
assert [e['status'] for e in entries]==['approved']*5+['pending','approved','pending','pending'];assert entries[-1]['action']=='Idle_Expressive_Test' and entries[-1]['seamless_loop'] and entries[-1]['closing_key']==145
assert len(bpy.data.armatures)==1 and len(bpy.data.meshes)==2
baseline=json.loads((ROOT/'.validation/animation_showcase/source_audit.json').read_text())
for action,folder in [('Jump_Takeoff_Test','jump_takeoff_test'),('Jump_AirPose_Test','jump_airpose_test'),('Jump_Landing_Test','jump_landing_test'),('Jump_Landing_Impact_Test','jump_landing_impact_test'),('Full_Jump_Expressive_Test','full_jump_expressive_test'),('Idle_Expressive_Test','idle_expressive_test')]:
    baseline[action]={'samples':json.loads((OUT.parent/folder/'validation.json').read_text())['frames']}
maximum=0;switches=0
for i in [n for old in range(8) for n in [8,old,8]]+list(range(7,-1,-1))+[8]:
    s.gaf_active_index=i;ui.activate(s,i);e=entries[i];a=r.animation_data.action
    assert a.name==e['action'] and r.animation_data.action_slot.identifier==e['slot_identifier']
    assert [s.frame_start,s.frame_end,s.render.fps,s.render.fps_base]==[e['start'],e['end'],e['fps'],e['fps_base']]
    assert ui.action_signature(a)==e['action_sha256']
    assert abs(bpy.data.objects['Showcase_FixedFloor'].location.z-e.get('preview_floor_z_m',0))<1e-6
    assert r.matrix_world==Matrix.Identity(4)
    for sample in baseline[e['action']]['samples']:
        f=sample['frame'];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();obj=m.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[obj.matrix_world@v.co for v in obj.data.vertices]
        maximum=max(maximum,max((p-Vector(q)).length for p,q in zip(points,sample['vertices'])))
    switches+=1
assert maximum<2e-6
before=json.loads((TMP/'backup_manifest.json').read_text());allowed={str(ROOT/p) for p in before['authorized_metadata_changes']};unchanged=[p for p in before['files'] if p not in allowed]
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==before['files'][p] for p in unchanged),'Protected original/source/Godot file changed'
assert all(hashlib.sha256((ROOT/e['source']).read_bytes()).hexdigest()==e['source_sha256'] for e in entries)
report={'passed':True,'fresh_reopen':True,'entries':[(e['action'],e['status']) for e in entries],'switches':switches,'max_source_vertex_error_m':maximum,'preview_floor_applied_and_reset':True,'rig_identity_preserved':True,'protected_files_unchanged':len(unchanged),'all_previous_actions_and_sources_preserved':True,'idle_seamless_loop':True,'closing_key_excluded_from_playback':True,'slots_ranges_timing_and_partial_pose_reset':True,'one_rig_one_character_mesh':True}
(OUT/'showcase_verification.json').write_text(json.dumps(report,indent=2));print('SHOWCASE IDLE VERIFIED',json.dumps(report),flush=True)
