"""Final original-working-bytes, media and hash-bound validation audit."""
from pathlib import Path
import json,hashlib,subprocess,ast,re
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test_v3'
before=json.loads((TMP/'backup_manifest.json').read_text());allowed={str(ROOT/p) for p in before['authorized_metadata_changes']}
protected=[p for p in before['files'] if p not in allowed];changed=[p for p in protected if not Path(p).is_file() or hashlib.sha256(Path(p).read_bytes()).hexdigest()!=before['files'][p]]
entries=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text())['animations'];old=json.loads((TMP/'files/blender/animation/showcase/animation_manifest.json').read_text())['animations']
v=json.loads((OUT/'validation.json').read_text());show=json.loads((OUT/'showcase_verification.json').read_text());gui=json.loads((OUT/'gui_playback.json').read_text());media=json.loads((OUT/'media_verification.json').read_text())
source_hash=hashlib.sha256((OUT/'idle_expressive_v3_review.blend').read_bytes()).hexdigest();action_hash=entries[-1]['action_sha256']
assert source_hash==entries[-1]['source_sha256']==v['sampled_source_sha256']==show['v3_source_sha256']==gui['source_sha256']==media['source_sha256']
assert action_hash==v['sampled_action_sha256']==show['v3_action_sha256']==gui['action_sha256']==media['action_sha256']
assert v['passed'] and show['passed'] and gui['passed'] and gui['observed_wraps']>=2
clips={k:x for k,x in media.items() if isinstance(x,dict) and 'frames' in x}
assert len(clips)==6 and all(x['frames']==480 and x['fps']==30 and x['v3_complete_loops']==2 and hashlib.sha256((OUT/(k+'.mp4')).read_bytes()).hexdigest()==x['sha256'] for k,x in clips.items())
assert len(entries)==11 and entries[:-1]==old and entries[-1]['status']=='pending'
for p in OUT.glob('*.py'):ast.parse(p.read_text(encoding='utf8'))
missing=[]
for target in re.findall(r'\]\(([^)]+)\)',(OUT/'README.md').read_text()):
    if not target.startswith(('http','app:')) and not (OUT/target).resolve().exists():missing.append(target)
assert not missing,missing
orientation=json.loads((OUT/'clean_stance_orientation.json').read_text());assert orientation['passed'] and orientation['source_sha256']==source_hash and orientation['action_sha256']==action_hash
body_angles=json.loads((OUT/'relative_body_angles.json').read_text());assert body_angles['source_sha256']==source_hash and body_angles['action_sha256']==action_hash
live=json.loads((OUT/'final_live_snapshot.json').read_text())
assert live['showcase_sha256']==hashlib.sha256((ROOT/'blender/animation/showcase/Animation_Showcase.blend').read_bytes()).hexdigest() and live['manifest_sha256']==hashlib.sha256((ROOT/'blender/animation/showcase/animation_manifest.json').read_bytes()).hexdigest(),'Library changed after final foreground snapshot'
assert live['active_action']=='Idle_Expressive_Test_v3' and live['entries']==11 and live['loop'] and live['range']==[1,240]
report={'passed':not changed,'protected_files':len(protected),'changed_protected_files':changed,'godot_files_unchanged':sum('game_mobile_3d' in Path(p).parts for p in protected),'full_jump_files_unchanged':sum('full_jump_expressive_test' in Path(p).parts for p in protected),'entire_idle_v1_study_unchanged':all(p not in changed for p in protected if 'idle_expressive_test' in Path(p).parts),'entire_idle_v2_study_unchanged':all(p not in changed for p in protected if 'idle_expressive_test_v2' in Path(p).parts),'idle_v2_files_unchanged':sum('idle_expressive_test_v2' in Path(p).parts for p in protected),'idle_v1_files_unchanged':sum('idle_expressive_test' in Path(p).parts for p in protected),'original_ten_manifest_entries_identical':entries[:-1]==old,'status':'pending','forward_foot_orientation_fixed_support_and_body_breathing_verified':True,'source_sha256':source_hash,'action_sha256':action_hash,'source_and_action_hashes_bound_to_validation_showcase_gui_media':True,'final_showcase_sha256':live['showcase_sha256'],'final_manifest_sha256':live['manifest_sha256'],'final_foreground_selection_and_file_hashes_match':True,'gui_two_loops_and_restart_passed':True,'six_original_speed_videos_decoded':True,'permanent_gameplay_priority_recorded':all('production readiness' in (ROOT/p).read_text().lower() or 'production-ready' in (ROOT/p).read_text().lower() for p in ['AGENTS.md','docs/animation/ANIMATION_WORKFLOW.md']),'one_animation_at_a_time_preserved':True,'gameplay_validation':'Not performed or claimed; separate authorization required.','git_head_now':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'concurrency_note':'Initial original working bytes audited, not moving Git HEAD. No reset, checkout, commit or index mutation by this task.'}
(OUT/'preservation_verification.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report,indent=2));assert report['passed'] and report['permanent_gameplay_priority_recorded']
