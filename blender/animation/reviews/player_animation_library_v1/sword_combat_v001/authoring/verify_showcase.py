"""Fresh-open verification of saved central registry and new independent Actions."""
import bpy,json,sys,hashlib,importlib.util
from pathlib import Path
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());OUT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('gaf_sword_native_verify',R/'blender/animation/showcase/gaf_animation_library.py');ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui)
manifest=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text());D=json.loads((OUT/'design.json').read_text());home=next(s for s in bpy.data.scenes if s.get(ui.SCENE_TAG));snapshot=json.loads(home['gaf_manifest_snapshot']);assert snapshot==manifest
rig=bpy.data.objects[ui.RIG];assert ui.rest_signature(rig.data)==manifest['rig_sha256'];entries=[]
for c in D['clips'].values():
 e=next(e for e in manifest['animations'] if e['action']==c['action']);a=bpy.data.actions[c['action']];assert e['status']=='pending';assert e['original_custom_animation'] and not e['source_derived_reconstruction'];assert ui.action_signature(a)==e['action_sha256']==c['action_sha256'];ui.validate_action(a,e,rig);entries.append(a.name)
canonical=next(e for e in manifest['animations'] if e['action']=='Sword_Combo_Original_v001');assert ui.action_signature(bpy.data.actions[canonical['action']])==canonical['action_sha256']==D['original_combo_action_sha256'];assert hashlib.sha256((R/canonical['source']).read_bytes()).hexdigest()==canonical['source_sha256']==D['original_combo_source_sha256']
assert rig.animation_data.action.name=='Sword_Ready_Original_v001';assert home.get('gaf_sword_combat_v001_pending')
report={'passed':True,'saved_manifest_snapshot_matches_disk':True,'reopened_pending_actions':entries,'canonical_original_signature_preserved':True,'rig_signature_preserved':True,'selected_action':rig.animation_data.action.name,'saved_central_action_count':len(bpy.data.actions)}
(OUT/'showcase_reopen_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('SWORD_SHOWCASE_REOPEN',json.dumps(report),flush=True)
