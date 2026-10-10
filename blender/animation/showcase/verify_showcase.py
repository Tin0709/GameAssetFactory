"""Fresh-process viewer verification: real slotted Actions and evaluated vertices."""
import bpy,json,hashlib,itertools
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2];TMP=ROOT/'.validation/animation_showcase'
TARGET=OUT/'Animation_Showcase.blend'
assert TARGET.exists(),'Animation_Showcase.blend has not been created'
assert Path(bpy.data.filepath).resolve()==TARGET.resolve(),'Open the saved showcase before verification'
assert hasattr(bpy.types,'GAF_PT_animation_library'),'Installed Animation Library sidebar did not register at Blender startup'
import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['Showcase_Player_Rig'];m=bpy.data.objects['Showcase_Player_Mesh']
manifest=json.loads((OUT/'animation_manifest.json').read_text());expected=['Expressive_Arm_Motion_Test','Run_Expressive_Test','LowerBody_Recovery_Test']
assert [e['action'] for e in manifest['animations']]==expected
assert sorted(a.name for a in bpy.data.actions)==sorted(expected),'Unexpected or missing Actions'
assert len([o for o in bpy.data.objects if o.type=='ARMATURE'])==1
assert not r.animation_data.nla_tracks and not r.animation_data.drivers
assert len(s.gaf_clips)==3
baseline=json.loads((TMP/'source_audit.json').read_text())
max_error=0;switches=0
for order in itertools.permutations(range(3)):
    for index in order:
        s.gaf_active_index=index;ui.activate(s,index)
        e=manifest['animations'][index];a=r.animation_data.action
        assert a.name==e['action'] and r.animation_data.action_slot.identifier==e['slot_identifier']
        assert [s.frame_start,s.frame_end,s.render.fps,s.render.fps_base]==[e['start'],e['end'],e['fps'],e['fps_base']]
        assert ui.action_signature(a)==e['action_sha256']
        assert list(a.frame_range)==e['action_frame_range']
        for sample in baseline[e['action']]['samples']:
            f=sample['frame'];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
            obj=m.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[obj.matrix_world@v.co for v in obj.data.vertices]
            from mathutils import Vector
            max_error=max(max_error,max((v-Vector(p)).length for v,p in zip(points,sample['vertices'])))
        switches+=1
assert max_error<2e-6,max_error
protected=json.loads((TMP/'backup_manifest.json').read_text())
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in protected['files'].items()),'Protected source or runtime file changed'
assert bpy.context.preferences.filepaths.use_scripts_auto_execute==protected['autoexec_before']
assert set(protected['installed_addons_before'])<=set(bpy.context.preferences.addons.keys())
assert all(e['status']=='approved' for e in manifest['animations'])
report={'passed':True,'actions':expected,'selection_switches':switches,'max_source_vertex_error_m':max_error,'sources_and_godot_unchanged':True,'automatic_addon_registration':True,'autoexec_unchanged':True,'version':bpy.app.version_string}
(OUT/'verification.json').write_text(json.dumps(report,indent=2))
print('SHOWCASE VERIFIED',json.dumps(report),flush=True)
