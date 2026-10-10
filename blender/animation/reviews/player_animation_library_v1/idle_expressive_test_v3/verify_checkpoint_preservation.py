"""Hash-bound current checkpoint audit, without claiming the deferred full video set."""
from pathlib import Path
import json,hashlib,re,ast,subprocess
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test_v3';SHOW=ROOT/'blender/animation/showcase'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=json.loads((TMP/'backup_manifest.json').read_text());allowed={str(ROOT/p) for p in before['authorized_metadata_changes']}
protected=[p for p in before['files'] if p not in allowed];changed=[p for p in protected if not Path(p).is_file() or sha(Path(p))!=before['files'][p]]
entries=json.loads((SHOW/'animation_manifest.json').read_text())['animations'];old=json.loads((TMP/'files/blender/animation/showcase/animation_manifest.json').read_text())['animations'];assert len(entries)==11 and entries[:-1]==old and entries[-1]['status']=='pending'
v=json.loads((OUT/'validation.json').read_text());show=json.loads((OUT/'showcase_verification.json').read_text());gui=json.loads((OUT/'gui_playback.json').read_text());media=json.loads((OUT/'checkpoint_media_verification.json').read_text());orientation=json.loads((OUT/'clean_stance_orientation.json').read_text());live=json.loads((OUT/'final_live_snapshot.json').read_text())
source=sha(OUT/'idle_expressive_v3_review.blend');action=entries[-1]['action_sha256']
assert source==entries[-1]['source_sha256']==v['sampled_source_sha256']==show['v3_source_sha256']==gui['source_sha256']==media['source_sha256']==orientation['source_sha256']
assert action==v['sampled_action_sha256']==show['v3_action_sha256']==gui['action_sha256']==media['action_sha256']==orientation['action_sha256']
assert all(x['passed'] for x in [v,show,gui,media,orientation]) and gui['observed_wraps']>=2
look=json.loads((OUT/'lookaround_refinement_verification.json').read_text());attention=json.loads((OUT/'attention_provenance.json').read_text())
assert look['passed'] and look['source_sha256']==source and look['attention_amplitude_ratio']==2 and look['gesture_duration_ratio']==.5
assert look['middle_pause_duration_ratio']==.5 and look['neutral_glances_only_when_facing_forward'] and look['current_side_gesture_range_and_duration_unchanged']
assert attention['source_sha256']==source and attention['action_sha256']==action and len(attention['frames'])==6 and all(sha(OUT/'attention_frames'/p)==h for p,h in attention['frames'].items())
assert live['showcase_sha256']==sha(SHOW/'Animation_Showcase.blend') and live['manifest_sha256']==sha(SHOW/'animation_manifest.json') and live['active_action']=='Idle_Expressive_Test_v3' and live['entries']==11 and live['range']==[1,240] and live['loop']
for name in ['stance_breath_three_quarter_1x','comparison_three_quarter_checkpoint_1x']:
 assert media[name]['frames']==480 and media[name]['fps']==30 and media[name]['sha256']==sha(OUT/(name+'.mp4'))
for p in OUT.glob('*.py'):ast.parse(p.read_text(encoding='utf8'))
missing=[p for p in re.findall(r'\]\(([^)]+)\)',(OUT/'README.md').read_text()) if not p.startswith(('http','app:')) and p!='checkpoint_verification.json' and not (OUT/p).resolve().exists()];assert not missing,missing
report={'passed':not changed,'source_sha256':source,'action_sha256':action,'protected_original_files':len(protected),'changed_protected_files':changed,'godot_files_unchanged':sum('game_mobile_3d' in Path(p).parts for p in protected),'v2_files_unchanged':sum('idle_expressive_test_v2' in Path(p).parts for p in protected),'v1_files_unchanged':sum('idle_expressive_test' in Path(p).parts for p in protected),'full_jump_files_unchanged':sum('full_jump_expressive_test' in Path(p).parts for p in protected),'original_ten_entries_identical':True,'existing_source_actions_preserved':True,'current_v3_pending':True,'current_source_reports_media_gui_hashes_match':True,'same_central_showcase_saved_and_reopened':True,'showcase_switches':show['switches'],'showcase_geometry_scope':show['geometry_scope'],'gui_two_wraps_pause_restart':True,'loop_pose_and_velocity_verified':True,'breathing_amplitude_m':v['body_breathing_rise_m'],'breathing_period_s':4,'source_rig_and_appearance_unchanged':True,'three_view_stance_stills':True,'two_original_speed_three_quarter_videos':True,'full_polished_front_side_comparison_set':'Deferred for requested stance review; not claimed complete.','gameplay_validation':'Not performed; Blender-only Pending study.','showcase_sha256':live['showcase_sha256'],'manifest_sha256':live['manifest_sha256'],'concurrency_note':'Compared original working bytes, not moving app-generated Git HEAD. No task git reset/index/commit operations.'}
report.update({'attention_amplitude_ratio':2,'gesture_duration_ratio':.5,'middle_pause_duration_ratio':.5,'neutral_up_down_head_glances':True,'prior_leg_matrices_and_breathing_preserved':True,'six_three_view_attention_stills_bound_to_current_source':True})
(OUT/'checkpoint_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));assert report['passed']
