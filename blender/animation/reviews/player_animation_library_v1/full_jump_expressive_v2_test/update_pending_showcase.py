import bpy,json,sys,hashlib
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/full_jump_expressive_v2_test';S=R/'blender/animation/showcase';sys.path.insert(0,str(S));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();g=json.loads((T/'pending_refresh_guard.json').read_text());oldguard=json.loads((T/'steering_guard.json').read_text());b=json.loads((T/'baseline.json').read_text());assert sha(S/'Animation_Showcase.blend')==g['showcase_before'] and sha(S/'animation_manifest.json')==g['manifest_after']
NAME='Full_Jump_Expressive_v2_Test';old=bpy.data.actions[NAME];assert ui.action_signature(old)==oldguard['action_sha256']
assert (T/'before_wider_legs_heavier_landing/metadata/blender/animation/showcase/Animation_Showcase.blend').is_file()
assert all(ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] for e in b['original_entries'])
with bpy.data.libraries.load(str(O/'full_jump_expressive_v2_review.blend'),link=False) as (src,dst):dst.actions=[NAME]
a=dst.actions[0];assert ui.action_signature(a)==g['action_sha256'];bpy.data.actions.remove(old,do_unlink=True);a.name=NAME;a.use_fake_user=True
s=bpy.context.scene;assert ui.refresh(s,import_missing=False)==0 and len(s.gaf_clips)==len(bpy.data.actions)==15
s.gaf_active_index=14;ui.activate(s,14);ui.view(s,'THREE_QUARTER');s.gaf_loop=False;s.frame_set(1)
assert all(ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] for e in b['original_entries'])
assert sha(S/'Animation_Showcase.blend')==g['showcase_before'] and sha(S/'animation_manifest.json')==g['manifest_after'];bpy.ops.wm.save_as_mainfile(filepath=str(S/'Animation_Showcase.blend'));print('REFRESHED ONLY PENDING V2;14 EXISTING ACTIONS PRESERVED')
