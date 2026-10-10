"""Final task audit against pre-existing working-tree bytes, not a moving Git HEAD."""
from pathlib import Path
import json,hashlib,subprocess
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
before=json.loads((TMP/'backup_manifest.json').read_text())
allowed={str(ROOT/p) for p in before['authorized_metadata_changes']}
protected=[Path(p) for p in before['files'] if p not in allowed]
changed=[str(p) for p in protected if not p.is_file() or sha(p)!=before['files'][str(p)]]
assert not changed,changed
manifest=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text())
original=json.loads((TMP/'files/blender/animation/showcase/animation_manifest.json').read_text())
assert manifest['animations'][:-1]==original['animations']
e=manifest['animations'][-1];assert e['action']=='Idle_Expressive_Test' and e['status']=='pending'
source=ROOT/e['source'];validation=json.loads((OUT/'validation.json').read_text())
assert validation['passed'] and validation['sampled_source_sha256']==sha(source)==e['source_sha256']
assert validation['sampled_action_sha256']==e['action_sha256']
old=json.loads((OUT/'old_idle_baseline.json').read_text());assert sha(ROOT/old['source'])==old['source_sha256']
showcase=json.loads((OUT/'showcase_verification.json').read_text())
assert showcase['passed'] and showcase['idle_source_sha256']==e['source_sha256'] and showcase['idle_action_sha256']==e['action_sha256']
gui=json.loads((OUT/'gui_playback.json').read_text());assert gui['passed'] and gui['range']==[1,144] and gui['observed_wraps']>=2 and gui['source_sha256']==e['source_sha256'] and gui['action_sha256']==e['action_sha256']
media=json.loads((OUT/'media_verification.json').read_text());videos={n:d for n,d in media.items() if isinstance(d,dict)}
assert len(videos)==6 and all(d['frames']==288 and d['fps']==30 and d['closing_key_excluded'] and sha(OUT/(n+'.mp4'))==d['sha256'] for n,d in videos.items())
report={'passed':True,'protected_files':len(protected),'changed_protected_files':changed,
 'godot_files_unchanged':sum('game_mobile_3d' in p.parts for p in protected),
 'full_jump_files_unchanged':sum('full_jump_expressive_test' in p.parts for p in protected),
 'original_idle_source_unchanged':True,'original_eight_manifest_entries_identical':True,
 'idle_status':'pending','source_and_action_hashes_bound_to_validation_and_showcase':True,
 'gui_reopening_and_two_loops_passed':True,'six_original_speed_videos_decoded':True,
 'git_head_now':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 'concurrency_note':'External Updates commits occurred during work; preserved them. Audit uses original working bytes, including pre-existing Full Jump work. No Git reset, checkout, commit or index mutation was performed by this task.'}
(OUT/'preservation_verification.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report,indent=2))
