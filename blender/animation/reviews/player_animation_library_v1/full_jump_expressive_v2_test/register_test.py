import bpy,json,sys,runpy,hashlib,subprocess
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/full_jump_expressive_v2_test';S=R/'blender/animation/showcase';sys.path.insert(0,str(S));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();b=json.loads((T/'baseline.json').read_text());v=json.loads((O/'validation.json').read_text());assert v['passed'] and sha(Path(bpy.data.filepath))==v['source_sha256']
assert sha(S/'Animation_Showcase.blend')==b['showcase_sha256'] and sha(S/'animation_manifest.json')==b['manifest_sha256'],'Concurrent library edit'
(T/'working_tree_before_registration.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=R,text=True),encoding='utf8')
runpy.run_path(str(S/'register_animation.py'))['register_entry']('Full_Jump_Expressive_v2_Test','FJ2_Test_Rig','FJ2_Test_Mesh',1,93,30)
p=S/'animation_manifest.json';m=json.loads(p.read_text());assert len(m['animations'])==15 and m['animations'][:14]==b['original_entries']
run=m['animations'][13];assert run['action']=='Run_Expressive_v3_Test';run['status']='approved';run['approval_note']='Explicit user approval2026-10-12; preferred run baseline. Preserve original Run and v2 for comparison. Blender artistic approval; actual Godot transition/mobile validation outstanding.';run['preferred_run_baseline']=True
m['animations'][-1].update({'seamless_loop':False,'in_place':True,'review_video':(O/'full_jump_v2_three_views_1x.mp4').relative_to(R).as_posix(),'presentation_note':'Separate arm-only refinement. Hands slightly above head at airborne peak; original93-frame30FPS timing, all non-arm channels and landing fromF45 unchanged.0.72m elevation used only for review pixels, never baked into rig Action. Original Full Jump and previews preserved.','gameplay_validation':'Pending artistic review. No Godot changes/export; actual physics/controller/transition/mobile validation still outstanding.'})
temp=p.with_suffix('.json.tmp');temp.write_text(json.dumps(m,indent=2));temp.replace(p)
(T/'registration_guard.json').write_text(json.dumps({'showcase_before':sha(S/'Animation_Showcase.blend'),'manifest_after':sha(p)},indent=2));print('RUN V3 APPROVED PREFERRED / ARM-ONLY FULL JUMP V2 PENDING')
