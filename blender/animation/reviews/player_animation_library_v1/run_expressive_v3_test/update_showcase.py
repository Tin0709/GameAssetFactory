import bpy,json,sys,hashlib
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/run_expressive_v3_test';S=R/'blender/animation/showcase';sys.path.insert(0,str(S));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();g=json.loads((T/'registration_guard.json').read_text());b=json.loads((T/'baseline.json').read_text())
assert sha(S/'Animation_Showcase.blend')==g['showcase_before'] and sha(S/'animation_manifest.json')==g['manifest_after'],'Concurrent library edit'
assert len(bpy.data.actions)==13 and all(ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] for e in b['original_entries'])
s=bpy.context.scene;assert ui.refresh(s)==1 and len(s.gaf_clips)==len(bpy.data.actions)==14
assert all(ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] for e in b['original_entries'])
s.gaf_active_index=13;ui.activate(s,13);ui.view(s,'THREE_QUARTER');s.gaf_loop=True;s.frame_set(1)
assert sha(S/'Animation_Showcase.blend')==g['showcase_before'] and sha(S/'animation_manifest.json')==g['manifest_after']
bpy.ops.wm.save_as_mainfile(filepath=str(S/'Animation_Showcase.blend'));print('SAVED EXISTING SHOWCASE / FOURTEEN INDEPENDENT ACTIONS')
