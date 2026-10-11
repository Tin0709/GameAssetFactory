"""Replace only the current backed-up Pending walk in the existing central library."""
import bpy,json,sys,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/walk_expressive_test';SHOW=ROOT/'blender/animation/showcase'
sys.path.insert(0,str(SHOW));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();g=json.loads((TMP/'quieter_registration_guard.json').read_text())
assert Path(bpy.data.filepath).resolve()==(SHOW/'Animation_Showcase.blend').resolve()
assert sha(SHOW/'Animation_Showcase.blend')==g['showcase_before'] and sha(SHOW/'animation_manifest.json')==g['manifest_after'],'Concurrent library edit'
old=json.loads((TMP/'before_quieter_sway/files/blender/animation/showcase/animation_manifest.json').read_text())['animations']
assert len(bpy.data.actions)==12 and old[-1]['status']=='pending' and all(ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] for e in old)
r=bpy.data.objects[ui.RIG];r.animation_data.action=None;bpy.data.actions.remove(bpy.data.actions['Walk_Expressive_Test'])
s=bpy.context.scene;assert ui.refresh(s)==1 and len(s.gaf_clips)==len(bpy.data.actions)==12
assert all(ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] for e in old[:-1])
s.gaf_active_index=11;ui.activate(s,11);s.gaf_loop=True;ui.view(s,'THREE_QUARTER');s.frame_set(1)
assert sha(SHOW/'Animation_Showcase.blend')==g['showcase_before'] and sha(SHOW/'animation_manifest.json')==g['manifest_after']
bpy.ops.wm.save_as_mainfile(filepath=str(SHOW/'Animation_Showcase.blend'));print('SAVED SAME SHOWCASE / ONLY PENDING WALK REFINED',flush=True)
