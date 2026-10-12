import bpy,json,sys,runpy,hashlib,subprocess
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/run_expressive_v3_test';S=R/'blender/animation/showcase';sys.path.insert(0,str(S));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();b=json.loads((T/'baseline.json').read_text());v=json.loads((O/'validation.json').read_text());c=json.loads((O/'refinement_comparison.json').read_text())
assert v['passed'] and c['passed'] and sha(Path(bpy.data.filepath))==v['source_sha256'] and ui.action_signature(bpy.data.actions['Run_Expressive_v3_Test'])==v['action_sha256']
assert sha(S/'Animation_Showcase.blend')==b['showcase_sha256'] and sha(S/'animation_manifest.json')==b['manifest_sha256'],'Concurrent library edit'
(T/'working_tree_before_registration.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=R,text=True),encoding='utf8')
runpy.run_path(str(S/'register_animation.py'))['register_entry']('Run_Expressive_v3_Test','RN3_Test_Rig','RN3_Test_Mesh',1,20,30)
p=S/'animation_manifest.json';m=json.loads(p.read_text());assert len(m['animations'])==14 and m['animations'][:13]==b['original_entries']
m['animations'][-1].update({'seamless_loop':True,'closing_key':21,'period_s':20/30,'in_place':True,'nominal_speed_m_s':2.31,'contact_frames':{'L':1,'R':11},'support_duty':{'L':.42,'R':.43},'flight_intervals_frames':[[9.4,11],[19.6,21]],'review_video':(O/'run_v3_three_views_1x.mp4').relative_to(R).as_posix(),'presentation_note':'Separate comparison refinement: cadence +10%, straight-arm pitch excursion +20% against saved Run v2. Same normalized hip/torso/head/leg poses, 0.27m tracks, saved L3/R5deg toe-out and controlled26mm lateral hip range. F1–20 at30FPS; closing21 excluded. Controller owns forward travel at nominal2.31m/s; preview travel is temporary only.','gameplay_validation':'Pending artistic review. Shared rig, LEFT phase0 / RIGHT phase0.5. Actual Godot transitions, speed-aware contact blending, input interruption, weapon layers and measured mobile30FPS remain outstanding.'})
temp=p.with_suffix('.json.tmp');temp.write_text(json.dumps(m,indent=2));temp.replace(p)
(T/'registration_guard.json').write_text(json.dumps({'showcase_before':sha(S/'Animation_Showcase.blend'),'manifest_after':sha(p)},indent=2));print('REGISTERED PENDING RUN V3 / THIRTEEN PRIOR ENTRIES UNCHANGED')
