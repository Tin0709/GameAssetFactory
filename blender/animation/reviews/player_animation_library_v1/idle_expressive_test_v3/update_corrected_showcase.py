"""Replace only explicitly corrected current Pending v3, with archived candidate."""
import bpy,json,sys,hashlib,shutil,subprocess
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];SHOW=ROOT/'blender/animation/showcase';TMP=ROOT/'.validation/idle_expressive_test_v3'
sys.path.insert(0,str(SHOW));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
g=json.loads((TMP/'clean_registration_guard.json').read_text())
assert Path(bpy.data.filepath).resolve()==(SHOW/'Animation_Showcase.blend').resolve() and sha(Path(bpy.data.filepath))==g['showcase_sha256_before'] and sha(SHOW/'animation_manifest.json')==g['manifest_sha256_after']
old=json.loads((TMP/'before_sideways_revision/animation_manifest.json').read_text())['animations'];assert len(old)==11 and old[-1]['action']=='Idle_Expressive_Test_v3' and old[-1]['status']=='pending'
original={a.name:ui.action_signature(a) for a in bpy.data.actions};assert original['Idle_Expressive_Test_v3']==g['previous_v3_action_sha256']
assert all(original[e['action']]==e['action_sha256'] for e in old)
backup=TMP/'before_sideways_showcase_save';backup.mkdir();shutil.copy2(Path(bpy.data.filepath),backup/'Animation_Showcase.blend')
(backup/'working_tree.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT,text=True),encoding='utf8')
r=bpy.data.objects[ui.RIG];r.animation_data.action=None
bpy.data.actions.remove(bpy.data.actions['Idle_Expressive_Test_v3'])
s=bpy.context.scene;assert ui.refresh(s)==1 and len(s.gaf_clips)==len(bpy.data.actions)==11
assert all(ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] for e in old[:-1])
assert ui.action_signature(bpy.data.actions['Idle_Expressive_Test_v3'])==g['new_action_sha256']
s.gaf_active_index=10;ui.activate(s,10);s.gaf_loop=True;ui.view(s,'THREE_QUARTER');s.frame_set(1)
assert sha(Path(bpy.data.filepath))==g['showcase_sha256_before'] and sha(SHOW/'animation_manifest.json')==g['manifest_sha256_after']
bpy.ops.wm.save_as_mainfile(filepath=str(SHOW/'Animation_Showcase.blend'))
print('SAVED CORRECTED PENDING V3 / ALL TEN EARLIER ACTIONS PRESERVED',flush=True)
