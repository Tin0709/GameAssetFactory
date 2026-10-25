"""Append8 Pending originals; guarded backup, refresh existing Showcase, preserve signatures."""
import bpy,sys,json,hashlib,shutil
from pathlib import Path
from datetime import datetime,timezone
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());OUT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
P=R/'blender/animation/showcase/animation_manifest.json';V=P.parent/'Animation_Showcase.blend';D=json.loads((OUT/'design.json').read_text())
assert json.loads((OUT/'geometry_validation.json').read_text())['passed']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ms=sha(P);vs=sha(V);manifest=json.loads(P.read_text());prior=json.loads(json.dumps(manifest));source=R/D['source'];assert sha(source)==D['source_sha256'];rig=bpy.data.objects[D['source_rig']]
assert ui.rest_signature(rig.data)==manifest['rig_sha256']
weapon=R/'blender/weapons/sword_sand_block_v1/Sword_Sand_Block_V1.blend'
for kind,c in D['clips'].items():
 assert not any(e['action']==c['action'] for e in manifest['animations']),c['action']
 action=bpy.data.actions[c['action']];ui.validate_action(action,c,rig)
 e={**c,'source':D['source'],'source_sha256':D['source_sha256'],'source_rig':D['source_rig'],'source_mesh':D['source_mesh'],'source_armature':D['source_armature'],'status':'pending','approval_note':'Awaiting explicit human artistic review. Full playable review authorized; registration does not approve the Action.','seamless_loop':c['loop'],'duration_s':c['duration'],'endpoint_sample_frame':1+c['duration']*30,'research_only':True,'production_eligible':False,'original_custom_animation':True,'source_derived_reconstruction':False,'bake_hz':240,'preview_prop':'sword_sand_block_v1','preview_prop_source':str(weapon.relative_to(R)),'preview_prop_source_sha256':sha(weapon),'original_combo_source_sha256':D['original_combo_source_sha256'],'original_combo_action_sha256':D['original_combo_action_sha256'],'review_note':'Independent original combat family; gameplay integration authorized separately from artistic approval.','timing_provenance':'P original durations/contact timing; attacks are continuous slices of the project original combo.'}
 manifest['animations'].append(e)
 manifest['library_focus']['entries'].append({'kind':'action','id':c['action']})
backup=R/'.validation/sword_combat_v001/animation_registration'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');backup.mkdir(parents=True)
assert sha(P)==ms and sha(V)==vs,'Concurrent central edits detected'
shutil.copy2(P,backup/P.name);shutil.copy2(V,backup/V.name)
assert sha(P)==ms and sha(V)==vs,'Concurrent edits during backup'
P.with_suffix('.json.tmp').write_text(json.dumps(manifest,indent=2)+'\n');P.with_suffix('.json.tmp').replace(P)
bpy.ops.wm.open_mainfile(filepath=str(V),load_ui=False)
if not hasattr(bpy.types.Scene,'gaf_clips'):ui.register()
home=next(s for s in bpy.data.scenes if s.get(ui.SCENE_TAG));bpy.context.window.scene=home
old_signatures={a.name:ui.action_signature(a) for a in bpy.data.actions}
added=ui.refresh(home,True)
assert added==8,added
for name,sig in old_signatures.items():assert ui.action_signature(bpy.data.actions[name])==sig,name
for e in prior['animations']:assert next(n for n in manifest['animations'] if n['action']==e['action'])==e
assert sha(V)==vs,'Concurrent viewer edit detected before save'
ui.select_registered_action(bpy.context,'Sword_Ready_Original_v001');home['gaf_sword_combat_v001_pending']=True
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(V),compress=True)
report={'passed':True,'pending_actions':[c['action'] for c in D['clips'].values()],'imported_actions':added,'prior_action_signatures_preserved':len(old_signatures),'prior_manifest_entries_preserved':len(prior['animations']),'original_combo_source_unchanged':sha(R/D['original_combo_source'])==D['original_combo_source_sha256'],'backup':str(backup.relative_to(R)),'manifest_before_sha256':ms,'viewer_before_sha256':vs,'manifest_after_sha256':sha(P),'viewer_after_sha256':sha(V)}
(OUT/'registration_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('SWORD_PENDING_REGISTERED',json.dumps(report),flush=True)
