import bpy,json,sys,hashlib,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE));import gaf_mobs_animation_library as lib
PROJECT=Path('/Users/tin/Desktop/Game Dev/GameAssetFactory');SUPPORT=PROJECT/'blender/animation/showcase/mobs_library';TARGET=SUPPORT.parent/'Mobs_Animation_Library.blend'
SOURCE=PROJECT/'blender/animation_v2/zombie_animation_v2.blend'
def appearance():
    r=bpy.data.objects['Zombie_Cuboid_Rig'];m=bpy.data.objects['Zombie_Cuboid_Base'];image=bpy.data.images['Zombie_Original_Atlas_64']
    return {'rest':[(b.name,b.parent.name if b.parent else None,[list(x) for x in b.matrix_local]) for b in r.data.bones],
            'mesh':[(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in m.data.vertices],
            'uvs':[[tuple(v.uv) for v in layer.data] for layer in m.data.uv_layers],
            'groups':[g.name for g in m.vertex_groups],
            'packed_atlas_sha256':hashlib.sha256(image.packed_file.data).hexdigest()}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));base=appearance()
bpy.ops.wm.open_mainfile(filepath=str(TARGET));assert appearance()==base
records=lib.registry(bpy.context.scene)['clips'];assert len(records)==4
assert all(c['status']=='Pending' and bpy.data.actions[c['action']]['review_status']=='Pending' for c in records)
assert sum(bool(c.get('research_only')) for c in records)==2
assert sum(bool(a.get('source_derived')) for a in bpy.data.actions)==2
info=json.loads((HERE/'source_research/central_registration.json').read_text())
for n,sig in info['original_action_signatures'].items():assert lib.action_signature(bpy.data.actions[n])==sig
signatures={a.name:lib.action_signature(a) for a in bpy.data.actions}
for i,c in enumerate(records):
    bpy.context.scene.mobs_active_index=i;lib.activate(bpy.context.scene)
    assert not bpy.context.scene.mobs_error
    r=bpy.data.objects['Zombie_Cuboid_Rig'];a=bpy.data.actions[c['action']]
    assert r.animation_data.action is a and r.animation_data.action_slot.identifier==c['slot']
    assert bpy.context.scene.render.fps==30 and bpy.context.scene.frame_end==c['end']
    assert a.get('research_only',False)==c.get('research_only',False)
tracked=subprocess.run(['git','-C',str(PROJECT),'ls-files','--error-unmatch',str(TARGET)],capture_output=True).returncode==0
assert subprocess.run(['git','-C',str(PROJECT),'check-ignore','--no-index','-q',str(TARGET)]).returncode==0
assert subprocess.run(['git','-C',str(PROJECT),'check-ignore','-q',str(SUPPORT/'research/actions_stuff_zombie_v001/zombie_actions_stuff_review.blend')]).returncode==0
installation=json.loads((HERE/'installation.json').read_text())
protected={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in installation['protected_file_hashes']}
assert protected==installation['protected_file_hashes'],'A protected file changed after mob installation; inspect concurrent work'
result={'delivered_file':str(TARGET),'original_mesh_rest_uv_weights_and_packed_atlas_preserved':True,'four_actions_pending':True,'source_research_count':2,'original_signatures_preserved':True,'native_bindings_and_timing':True,'research_folder_ignored':True,'central_ignore_rule_exists':True,'central_library_already_git_tracked':tracked,'git_note':'Ignore rules do not untrack a file. An external checkpoint tracked the central library during this session; this task made no commits and did not rewrite Git history. Keep source-derived clips out of shipping exports.','action_signatures':signatures,'protected_files':protected,'library_sha256':hashlib.sha256(TARGET.read_bytes()).hexdigest()}
(HERE/'validation_final.json').write_text(json.dumps(result,indent=2));print('FINAL_AUDIT_PASS',json.dumps(result),flush=True)
