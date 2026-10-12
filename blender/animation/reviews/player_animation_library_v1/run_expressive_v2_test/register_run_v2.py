"""Register a separate Pending Run and approve only the exact user-approved Walk."""
import bpy,json,sys,runpy,hashlib,subprocess
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/run_expressive_v2_test';S=R/'blender/animation/showcase';sys.path.insert(0,str(S));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();b=json.loads((T/'baseline.json').read_text());v=json.loads((O/'validation.json').read_text())
assert v['passed'] and sha(Path(bpy.data.filepath))==v['source_sha256'] and ui.action_signature(bpy.data.actions['Run_Expressive_v2_Test'])==v['action_sha256']
assert sha(S/'Animation_Showcase.blend')==b['showcase_sha256'] and sha(S/'animation_manifest.json')==b['manifest_sha256'],'Concurrent library edit'
(T/'working_tree_before_registration.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=R,text=True),encoding='utf8')
runpy.run_path(str(S/'register_animation.py'))['register_entry']('Run_Expressive_v2_Test','RN2_Test_Rig','RN2_Test_Mesh',1,22,30)
p=S/'animation_manifest.json';m=json.loads(p.read_text());assert len(m['animations'])==13
walk=m['animations'][11];assert walk['source_sha256']==b['approved_walk_source_sha256'] and walk['action_sha256']==b['approved_walk_action_sha256']
walk['status']='approved';walk['approval_note']='Explicit user approval2026-10-12 of the CURRENT refined version; preferred Walk baseline. Exact source/Action preserved. Blender artistic approval; actual Godot transition/mobile validation outstanding.'
run=m['animations'][-1];run.update({'seamless_loop':True,'closing_key':23,'period_s':22/30,'in_place':True,'nominal_speed_m_s':2.1,'contact_frames':{'L':1,'R':12},'support_duty':{'L':.42,'R':.43},'flight_intervals_frames':[[10.24,12],[21.46,23]],'review_video':(O/'run_v2_three_views_1x.mp4').relative_to(R).as_posix(),'presentation_note':'Separate22-frame Run v2,30FPS, closing23 excluded.0.27m tracks,3deg toe-out; loading/push/brief flight, restrained side sway, stronger fore/aft response, straight independent arms. Root/object static; controller owns forward -Y travel at nominal2.1m/s. Phase0LEFT receiving,0.5RIGHT receiving matches approved Walk phase; preview travel is temporary and is not registered.','gameplay_validation':'Blender-only Pending. Phase contract documented; contact-aware speed/phase blending, input interruption, idle replant, weapon masks, turns/slopes and measured30FPS phone validation remain unimplemented.'})
assert m['animations'][:11]==b['original_entries'][:11]
assert {k:x for k,x in walk.items() if k not in ['status','approval_note']}=={k:x for k,x in b['original_entries'][11].items() if k not in ['status','approval_note']}
temp=p.with_suffix('.json.tmp');temp.write_text(json.dumps(m,indent=2));temp.replace(p)
(T/'registration_guard.json').write_text(json.dumps({'showcase_before':sha(S/'Animation_Showcase.blend'),'manifest_after':sha(p),'source_sha256':v['source_sha256'],'action_sha256':v['action_sha256']},indent=2))
print('REGISTERED SEPARATE PENDING RUN V2 / CURRENT WALK APPROVED WITHOUT ACTION EDIT')
