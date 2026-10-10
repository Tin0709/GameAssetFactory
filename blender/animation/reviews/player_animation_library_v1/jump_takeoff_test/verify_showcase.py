"""Fresh-process selection/reset/slot checks for takeoff and approved references."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/jump_takeoff_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
assert bpy.data.filepath.endswith('Animation_Showcase.blend')
assert hasattr(bpy.types,'GAF_PT_animation_library')
s=bpy.context.scene;r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh']
manifest=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text());entries=manifest['animations']
assert len(entries)==len(s.gaf_clips)==len(bpy.data.actions)==4
assert len(bpy.data.armatures)==1 and len(bpy.data.meshes)==2
assert entries[-1]['action']=='Jump_Takeoff_Test' and entries[-1]['status']=='pending'
assert all(e['status']=='approved' for e in entries[:3])
baseline=json.loads((ROOT/'.validation/animation_showcase/source_audit.json').read_text())
source=json.loads((OUT/'validation.json').read_text())
baseline['Jump_Takeoff_Test']={'samples':[{'frame':x['frame'],'vertices':x['vertices']} for x in source['frames']]}
maximum=0;switches=0
for i in [3,0,3,1,3,2,0,2,1,3]:
    s.gaf_active_index=i;ui.activate(s,i);e=entries[i];a=r.animation_data.action
    assert a.name==e['action'] and r.animation_data.action_slot.identifier==e['slot_identifier']
    assert [s.frame_start,s.frame_end,s.render.fps,s.render.fps_base]==[e['start'],e['end'],e['fps'],e['fps_base']]
    assert ui.action_signature(a)==e['action_sha256']
    for sample in baseline[e['action']]['samples']:
        f=sample['frame'];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();obj=m.evaluated_get(bpy.context.evaluated_depsgraph_get())
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        maximum=max(maximum,max((v-Vector(p)).length for v,p in zip(points,sample['vertices'])))
    switches+=1
assert maximum<2e-6
before=json.loads((TMP/'backup_manifest.json').read_text())['files']
allowed={str(ROOT/p) for p in ['AGENTS.md','docs/graphics/RESEARCH.md','docs/animation/ANIMATION_STYLE_GUIDE.md','docs/animation/ANIMATION_WORKFLOW.md','blender/animation/showcase/Animation_Showcase.blend','blender/animation/showcase/animation_manifest.json','blender/animation/showcase/README.md']}
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in before.items() if p not in allowed)
report={'passed':True,'fresh_reopen':True,'selection_switches':switches,'max_source_vertex_error_m':maximum,'slots_ranges_timing_match':True,'pending_status_preserved':True,'approved_actions_sources_and_godot_unchanged':True,'one_rig_one_character_plus_floor':True}
(OUT/'showcase_verification.json').write_text(json.dumps(report,indent=2));print('SHOWCASE TAKEOFF VERIFIED',json.dumps(report),flush=True)
