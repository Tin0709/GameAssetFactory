"""Recover a backed-up Pending registration using exact repo addon, not stale installed code."""
import bpy,sys,json,hashlib,importlib.util,array
from pathlib import Path
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());OUT=Path(__file__).resolve().parent.parent
# Background Blender may pre-load a stale installed addon before --python.
old=sys.modules.get('gaf_animation_library')
if old and hasattr(old,'unregister') and hasattr(bpy.types.Scene,'gaf_clips'):old.unregister()
spec=importlib.util.spec_from_file_location('gaf_animation_library',R/'blender/animation/showcase/gaf_animation_library.py');ui=importlib.util.module_from_spec(spec);sys.modules[spec.name]=ui;spec.loader.exec_module(ui);ui.register()
assert 'sword_sand_block_v1' in ui.PREVIEW_PROPS
P=R/'blender/animation/showcase/animation_manifest.json';V=P.parent/'Animation_Showcase.blend';D=json.loads((OUT/'design.json').read_text());manifest=json.loads(P.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
vs=sha(V);ms=sha(P)
for c in D['clips'].values():
 e=next(e for e in manifest['animations'] if e['action']==c['action']);assert e['status']=='pending' and e['action_sha256']==c['action_sha256'] and e['source_sha256']==D['source_sha256']
assert sha(R/D['source'])==D['source_sha256']
def content_digest(action):
 h=hashlib.sha256()
 h.update(repr([(slot.identifier,slot.target_id_type) for slot in action.slots]).encode())
 for c in ui.curves(action):
  h.update(repr((c.data_path,c.array_index,c.mute,c.extrapolation,len(c.keyframe_points))).encode())
  for prop in ['co','handle_left','handle_right']:
   data=array.array('f',[0])*(2*len(c.keyframe_points));c.keyframe_points.foreach_get(prop,data);h.update(data.tobytes())
 return h.hexdigest()
old_ids={a.name:a.as_pointer() for a in bpy.data.actions};before={a.name:content_digest(a) for a in bpy.data.actions}
print('SWORD_CURRENT_SIGNATURE_SNAPSHOT',len(before),flush=True)
home=next(s for s in bpy.data.scenes if s.get(ui.SCENE_TAG));bpy.context.window.scene=home
added=ui.refresh(home,True) # Fresh full registered Action/source/rest/slot validation.
assert added==8,added
print('SWORD_REFRESH_VALIDATED',added,flush=True)
for name,digest in before.items():assert bpy.data.actions[name].as_pointer()==old_ids[name] and content_digest(bpy.data.actions[name])==digest,name
assert sha(V)==vs and sha(P)==ms,'Concurrent central edit before save'
ui.select_registered_action(bpy.context,'Sword_Ready_Original_v001');ui.activate(home,home.gaf_active_index);assert not home.gaf_error
home['gaf_sword_combat_v001_pending']=True;bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(V),compress=True)
backup_root=R/'.validation/sword_combat_v001/animation_registration';backup=sorted(backup_root.iterdir())[-1];prior=json.loads((backup/P.name).read_text())
for e in prior['animations']:assert next(n for n in manifest['animations'] if n['action']==e['action'])==e
report={'passed':True,'pending_actions':[c['action'] for c in D['clips'].values()],'imported_actions':added,'prior_action_signatures_preserved':len(before),'prior_manifest_entries_preserved':len(prior['animations']),'fresh_full_manifest_validation':True,'exact_repo_addon':str(Path(ui.__file__).relative_to(R)),'original_combo_source_unchanged':sha(R/D['original_combo_source'])==D['original_combo_source_sha256'],'backup':str(backup.relative_to(R)),'manifest_before_sha256':sha(backup/P.name),'viewer_before_sha256':vs,'manifest_after_sha256':sha(P),'viewer_after_sha256':sha(V)}
(OUT/'registration_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('SWORD_PENDING_REGISTERED',json.dumps(report),flush=True)
