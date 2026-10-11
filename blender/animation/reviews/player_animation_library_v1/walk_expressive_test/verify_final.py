"""Hash-bound delivery audit including prior dirty-worktree bytes and all media."""
from pathlib import Path
import json,hashlib,ast,re
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/walk_expressive_test';SHOW=ROOT/'blender/animation/showcase';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
base=json.loads((TMP/'baseline.json').read_text());allowed={str(ROOT/p) for p in base['allowed_metadata_changes']};protected=[p for p in base['files'] if p not in allowed]
changed=[p for p in protected if not Path(p).is_file() or sha(Path(p))!=base['files'][p]];assert not changed,changed
entries=json.loads((SHOW/'animation_manifest.json').read_text())['animations'];old=json.loads((TMP/'files/blender/animation/showcase/animation_manifest.json').read_text())['animations'];assert len(entries)==12 and len(old)==11
for before,after in zip(old,entries):
 assert before['action_sha256']==after['action_sha256'] and before['source_sha256']==after['source_sha256']
 if before['action']=='Idle_Expressive_Test_v3':assert after['status']=='approved' and {k:v for k,v in before.items() if k not in ['status','approval_note']}=={k:v for k,v in after.items() if k not in ['status','approval_note']}
 else:assert before==after
walk=entries[-1];assert walk['action']=='Walk_Expressive_Test' and walk['status']=='pending' and walk['seamless_loop'] and walk['closing_key']==37
v=json.loads((OUT/'validation.json').read_text());phase=json.loads((OUT/'phase_pose_verification.json').read_text());show=json.loads((OUT/'showcase_verification.json').read_text());gui=json.loads((OUT/'gui_playback.json').read_text());media=json.loads((OUT/'media_verification.json').read_text());live=json.loads((OUT/'final_live_snapshot.json').read_text());source=sha(OUT/'walk_expressive_review.blend')
assert all(x['passed'] for x in [v,phase,show,gui,media])
assert source==walk['source_sha256']==v['source_sha256']==phase['source_sha256']==show['walk_source_sha256']==gui['source_sha256']==media['source_sha256']
assert walk['action_sha256']==v['action_sha256']==phase['action_sha256']==show['walk_action_sha256']==gui['action_sha256']==media['action_sha256']
assert gui['observed_wraps']>=3 and gui['paused_restarted'] and not v['unsupported_samples'] and not v['nonadjacent_overlaps']
assert live['showcase_sha256']==show['showcase_sha256']==sha(SHOW/'Animation_Showcase.blend') and live['manifest_sha256']==show['manifest_sha256']==sha(SHOW/'animation_manifest.json')
assert live['active_action']=='Walk_Expressive_Test' and live['slot']==walk['slot_identifier'] and live['entries']==12 and live['range']==[1,36] and live['fps']==30 and live['loop']
for filename,count in [('render_provenance.json',108),('travel_provenance.json',108)]:
 proof=json.loads((OUT/filename).read_text());assert proof['source_sha256']==source and proof['action_sha256']==walk['action_sha256'] and len(proof['frames'])==count
 assert all(sha(OUT/p)==h for p,h in proof['frames'].items())
assert len(media['videos'])==5
for name,item in media['videos'].items():assert sha(OUT/item['path'])==item['sha256'] and item['fps']==30 and item['frames']==(108 if name=='travel' else 144)
for p in OUT.glob('*.py'):ast.parse(p.read_text(encoding='utf8'))
missing=[p for p in re.findall(r'\]\(([^)]+)\)',(OUT/'README.md').read_text()) if not p.startswith(('http','app:')) and p!='final_verification.json' and not (OUT/p).resolve().exists()];assert not missing,missing
progress=(ROOT/'docs/animation/ANIMATION_PROGRESS.md').read_text();assert '**User approved; preferred idle baseline**' in progress and '| Walk_Expressive_Test |' in progress
report={'passed':True,'source_sha256':source,'action_sha256':walk['action_sha256'],'approved_idle_source_sha256':base['approved_idle_source_sha256'],'approved_idle_and_all_previous_action_source_bytes_preserved':True,'idle_v3_explicitly_approved_preferred_baseline':True,'walk_pending':True,'previous_eleven_entries_preserved_except_explicit_idle_approval':True,'protected_original_files':len(protected),'changed_protected_files':changed,'godot_files_unchanged':sum('game_mobile_3d' in Path(p).parts for p in protected),'idle_v3_files_unchanged':sum('idle_expressive_test_v3' in Path(p).parts for p in protected),'full_jump_files_unchanged':sum('full_jump_expressive_test' in Path(p).parts for p in protected),'rig_and_appearance_unchanged':True,'support_drift_m':v['maximum_support_drift_m'],'support_height_error_m':v['maximum_support_height_error_m'],'loop_pose_error_m':v['loop_pose_error_m'],'loop_velocity_finite_difference_m_s':v['loop_finite_vertex_velocity_difference_m_s'],'loop_tangent_difference':v['loop_channel_tangent_difference'],'dense_samples':v['samples'],'source_geometry_switch_samples':show['geometry_samples'],'showcase_switches':show['switches'],'gui_three_wraps_pause_restart':True,'same_showcase_saved_and_reopened':True,'review_views':['front','three_quarter','side'],'five_original_speed_review_videos_verified':True,'gameplay_status':'Blender-only Pending walk. No Godot integration, export, weapon-layer or phone-performance validation. Idle/start/stop/replant and Walk/Run phase compatibility documented, not proven runtime transitions.','showcase_sha256':live['showcase_sha256'],'manifest_sha256':live['manifest_sha256']}
(OUT/'final_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
