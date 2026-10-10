"""Refresh and save the one permanent showcase under current-byte guards."""
import bpy,json,sys,hashlib,shutil,subprocess
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];SHOW=ROOT/'blender/animation/showcase';TMP=ROOT/'.validation/idle_expressive_test_v2'
sys.path.insert(0,str(SHOW));import gaf_animation_library as ui
hashfile=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
g=json.loads((TMP/'registration_guard.json').read_text())
assert Path(bpy.data.filepath).resolve()==(SHOW/'Animation_Showcase.blend').resolve()
assert hashfile(Path(bpy.data.filepath))==g['showcase_sha256_before'] and hashfile(SHOW/'animation_manifest.json')==g['manifest_sha256_after'],'Concurrent edit before save'
backup=TMP/'before_showcase_save';backup.mkdir();shutil.copy2(Path(bpy.data.filepath),backup/'Animation_Showcase.blend')
(backup/'working_tree.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT,text=True),encoding='utf8')
original={a.name:ui.action_signature(a) for a in bpy.data.actions};s=bpy.context.scene
assert len(original)==9 and ui.refresh(s)==1 and len(s.gaf_clips)==10
assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in original.items())
s.gaf_active_index=9;ui.activate(s,9);s.gaf_loop=True;ui.view(s,'THREE_QUARTER');s.frame_set(1)
assert ui.action_signature(bpy.data.actions['Idle_Expressive_Test_v2'])==g['action_sha256']
assert hashfile(Path(bpy.data.filepath))==g['showcase_sha256_before'] and hashfile(SHOW/'animation_manifest.json')==g['manifest_sha256_after']
bpy.ops.wm.save_as_mainfile(filepath=str(SHOW/'Animation_Showcase.blend'))
print('UPDATED EXISTING SHOWCASE / TEN INDEPENDENT ACTIONS',flush=True)
