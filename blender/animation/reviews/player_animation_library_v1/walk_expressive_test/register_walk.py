"""Guarded registration of Walk Pending and explicit Idle v3 approval metadata."""
import bpy,json,sys,hashlib,runpy,subprocess
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/walk_expressive_test';SHOW=ROOT/'blender/animation/showcase'
sys.path.insert(0,str(SHOW));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();b=json.loads((TMP/'baseline.json').read_text());v=json.loads((OUT/'validation.json').read_text())
assert v['passed'] and v['source_sha256']==sha(Path(bpy.data.filepath)) and v['action_sha256']==ui.action_signature(bpy.data.actions['Walk_Expressive_Test'])
assert sha(SHOW/'Animation_Showcase.blend')==b['showcase_sha256'] and sha(SHOW/'animation_manifest.json')==b['manifest_sha256'],'Concurrent library edit'
(TMP/'working_tree_before_registration.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT,text=True),encoding='utf8')
helper=runpy.run_path(str(SHOW/'register_animation.py'))
helper['register_entry']('Walk_Expressive_Test','WEX_Test_Rig','WEX_Test_Mesh',1,36,30)
path=SHOW/'animation_manifest.json';manifest=json.loads(path.read_text());assert len(manifest['animations'])==12
idle=next(e for e in manifest['animations'] if e['action']=='Idle_Expressive_Test_v3');assert idle['status']=='pending' and idle['source_sha256']==b['approved_idle_source_sha256']
idle['status']='approved';idle['approval_note']='Explicit user approval2026-10-11: current Idle v3 is the preferred idle baseline; earlier idle versions remain preserved for comparison. Blender artistic approval only; Godot gameplay validation outstanding.'
walk=manifest['animations'][-1];walk.update({'seamless_loop':True,'closing_key':37,'nominal_speed_m_s':.9,'contact_frames':{'L':1,'R':19},'support_duty':{'L':.60,'R':.62},'presentation_note':'In-place 36-frame/30FPS expressive walk, closing37 excluded. Nominal speed0.9m/s; controller owns travel. Approved Idle v3 posture anchor; support-aware replants required for start/stop. Full-body absolute tracks, straight arms; weapon-layer/runtime transition validation outstanding.'})
ui.validate_action(bpy.data.actions['Walk_Expressive_Test'],walk,bpy.data.objects['WEX_Test_Rig'])
assert sha(SHOW/'Animation_Showcase.blend')==b['showcase_sha256']
temp=path.with_suffix('.json.tmp');temp.write_text(json.dumps(manifest,indent=2));temp.replace(path)
(TMP/'registration_guard.json').write_text(json.dumps({'showcase_before':b['showcase_sha256'],'manifest_after':sha(path),'source_sha256':v['source_sha256'],'walk_action_sha256':v['action_sha256']},indent=2))
print('REGISTERED WALK PENDING / IDLE V3 EXPLICITLY APPROVED',flush=True)
