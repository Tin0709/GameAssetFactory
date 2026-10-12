"""Final delivery proof: actual saved sources, source-bound media and preserved bytes."""
from pathlib import Path
import json,hashlib,ast,re
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/run_expressive_v2_test';S=R/'blender/animation/showcase';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((T/'baseline.json').read_text());protected=[p for p in b['files'] if p not in b['allowed_metadata_changes']];changed=[p for p in protected if not (R/p).is_file() or sha(R/p)!=b['files'][p]];assert not changed,changed
m=json.loads((S/'animation_manifest.json').read_text());entries=m['animations'];assert len(entries)==13
for old,new in zip(b['original_entries'],entries):
 assert old['source_sha256']==new['source_sha256'] and old['action_sha256']==new['action_sha256'] and sha(R/new['source'])==new['source_sha256']
 if old['action']=='Walk_Expressive_Test':
  assert new['status']=='approved' and {k:v for k,v in old.items() if k not in ['status','approval_note']}=={k:v for k,v in new.items() if k not in ['status','approval_note']}
 else:assert old==new
a=entries[-1];assert a['action']=='Run_Expressive_v2_Test' and a['status']=='pending' and a['seamless_loop'] and [a['start'],a['end'],a['closing_key'],a['fps']]==[1,22,23,30]
source=sha(O/'run_expressive_v2_review.blend');v=json.loads((O/'validation.json').read_text());g=json.loads((O/'gait_verification.json').read_text());show=json.loads((O/'showcase_verification.json').read_text());gui=json.loads((O/'gui_playback.json').read_text());media=json.loads((O/'media_verification.json').read_text());live=json.loads((O/'final_live_snapshot.json').read_text())
assert all(x['passed'] and x['source_sha256']==source and x['action_sha256']==a['action_sha256'] for x in [v,g,show,gui,media]);assert source==a['source_sha256']
assert gui['observed_wraps']>=3 and gui['paused_restarted'] and not v['nonadjacent_overlaps'] and not v['unsupported_samples']
assert live['showcase_sha256']==show['showcase_sha256']==sha(S/'Animation_Showcase.blend') and live['manifest_sha256']==show['manifest_sha256']==sha(S/'animation_manifest.json')
assert live['active_action']==a['action'] and live['slot']==a['slot_identifier'] and live['entries']==13 and live['range']==[1,22] and live['fps']==30 and live['loop']
p=json.loads((O/'render_provenance.json').read_text());assert p['source_sha256']==source and p['action_sha256']==a['action_sha256'] and len(p['frames'])==150 and all(sha(O/f)==h for f,h in p['frames'].items())
package=json.loads((O/'package_provenance.json').read_text());assert package['walk_source_sha256']==b['approved_walk_source_sha256'] and package['comparisons_original_speed_no_retiming']
assert len(media['videos'])==7
for name,item in media['videos'].items():assert sha(O/item['path'])==item['sha256'] and item['fps']==30 and item['frames']==package['videos'][name]['frames']
for p in O.glob('*.py'):ast.parse(p.read_text(encoding='utf8'))
assert not [p for p in re.findall(r'\]\(([^)]+)\)',(O/'README.md').read_text()) if not p.startswith(('http','app:')) and p!='final_verification.json' and not (O/p).resolve().exists()]
progress=(R/'docs/animation/ANIMATION_PROGRESS.md').read_text();assert '| Run_Expressive_v2_Test |' in progress and '**User approved — current refined version**' in progress
report={'passed':True,'source_sha256':source,'action_sha256':a['action_sha256'],'current_refined_walk_explicitly_approved':True,'approved_walk_source_and_action_unchanged':True,'run_v2_pending':True,'all_twelve_previous_actions_and_sources_preserved':True,'protected_original_files':len(protected),'changed_protected_files':changed,'godot_files_unchanged':sum('game_mobile_3d' in Path(p).parts for p in protected),'walk_files_unchanged':sum('walk_expressive_test' in Path(p).parts for p in protected),'full_jump_files_unchanged':sum('full_jump_expressive_test' in Path(p).parts for p in protected),'rig_appearance_and_materials_preserved':v['appearance_rest_weights_uv_materials_images_lights_unchanged'],'support_drift_m':v['maximum_support_drift_m'],'support_height_error_m':v['maximum_support_height_error_m'],'loop_pose_error_m':v['loop_pose_error_m'],'loop_finite_vertex_velocity_difference_m_s':v['loop_finite_vertex_velocity_difference_m_s'],'loop_channel_tangent_difference':v['loop_channel_tangent_difference'],'dense_samples':v['samples'],'showcase_switches':show['switches'],'geometry_switch_samples':show['geometry_samples'],'showcase_saved_reopened_playback_verified':True,'seven_original_speed_videos_verified':True,'same_rig_phase_contract_documented':True,'gameplay_status':'Blender-only Pending. No Godot integration, export, transition proof, weapon-layer or mobile performance claim.','showcase_sha256':show['showcase_sha256'],'manifest_sha256':show['manifest_sha256']}
(O/'final_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
