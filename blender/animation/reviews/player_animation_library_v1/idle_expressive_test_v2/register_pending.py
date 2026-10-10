"""Task-local guarded use of the established registration workflow; never replace."""
import bpy,json,sys,hashlib,shutil,subprocess
from pathlib import Path
from datetime import datetime,timezone
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];SHOW=ROOT/'blender/animation/showcase';TMP=ROOT/'.validation/idle_expressive_test_v2'
sys.path.insert(0,str(SHOW));import register_animation as registration
hashfile=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=json.loads((TMP/'backup_manifest.json').read_text());guard=[SHOW/'Animation_Showcase.blend',SHOW/'animation_manifest.json']
assert all(hashfile(p)==before['files'][str(p)] for p in guard),'Concurrent library changes; rebase registration against latest files first'
validation=json.loads((OUT/'validation.json').read_text());assert validation['passed'] and validation['sampled_source_sha256']==hashfile(Path(bpy.data.filepath))
assert validation['sampled_action_sha256']==registration.ui.action_signature(bpy.data.actions['Idle_Expressive_Test_v2'])
old=json.loads(guard[1].read_text());assert len(old['animations'])==9
backup=TMP/'before_registration';backup.mkdir()
for p in guard:shutil.copy2(p,backup/p.name)
(backup/'working_tree.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT,text=True),encoding='utf8')
e=registration.register_entry('Idle_Expressive_Test_v2','IEV2_Test_Rig','IEV2_Test_Mesh',1,240,30)
manifest=json.loads(guard[1].read_text());assert manifest['animations'][:-1]==old['animations']
manifest['animations'][-1].update({'seamless_loop':True,'closing_key':241,'period_s':8.0,'in_place':True,'review_video':str(OUT.relative_to(ROOT)/'idle_v2_all_views_1x.mp4').replace('\\','/'),'comparison_video':str(OUT.relative_to(ROOT)/'comparison_three_quarter_1x.mp4').replace('\\','/'),'presentation_note':'Both full soles fixed 28 mm farther outward per side; static root; playback1–240, closing key241 excluded. No travel. Separate v2; original Idle preserved.','gameplay_validation':'Not production-ready. Requires stance/replant transitions, interruption response, weapon-layer ownership and actual Godot/mobile validation.'})
temp=guard[1].with_suffix('.json.tmp');temp.write_text(json.dumps(manifest,indent=2),encoding='utf8');temp.replace(guard[1])
(TMP/'registration_guard.json').write_text(json.dumps({'showcase_sha256_before':hashfile(guard[0]),'manifest_sha256_after':hashfile(guard[1]),'source_sha256':e['source_sha256'],'action_sha256':e['action_sha256'],'original_entries_identical':True,'pending':True},indent=2),encoding='utf8')
print('REGISTERED V2 PENDING; retained nine entries',flush=True)
