"""Record verified delivery and check protected assets without altering them."""
import json,hashlib,shutil,re,subprocess
from pathlib import Path
STAGE=Path(__file__).resolve().parent
state=json.loads((STAGE/'preservation_before.json').read_text());meta=json.loads((STAGE/'manifest.json').read_text())
ROOT=Path(state['project']);OUT=Path(state['package_destination']);LIB=ROOT/'blender/animation/showcase'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
for file in ['source_validation.json','showcase_validation.json','gui_playback_validation.json','media_validation.json','decoded_media_validation.json']:
 assert json.loads((STAGE/file).read_text())['passed'],file
publication=json.loads((STAGE/'publication_validation.json').read_text())
assert sha(LIB/'Animation_Showcase.blend')==publication['central_sha256']
assert sha(LIB/'animation_manifest.json')==publication['manifest_sha256']
assert sha(LIB/'gaf_animation_library.py')==publication['viewer_sha256']
intentional={'blender/animation/showcase/Animation_Showcase.blend','blender/animation/showcase/animation_manifest.json',
 'blender/animation/showcase/gaf_animation_library.py','docs/animation/ANIMATION_PROGRESS.md'}
bad=[p for p,h in state['protected'].items() if p not in intentional and (not (ROOT/p).is_file() or sha(ROOT/p)!=h)]
assert not bad,('Protected files changed',bad)
progress=ROOT/'docs/animation/ANIMATION_PROGRESS.md'
assert sha(progress)==state['protected']['docs/animation/ANIMATION_PROGRESS.md'],'Concurrent progress edit; merge required'
entry='''**Actions & Stuff Running source reconstruction — 2026-10-14, Pending research only:** Separate `Run_ActionsStuff_Source_Test_v001` in the existing central Showcase (37 entries). All 36 prior Actions, source files and manifest entries remain exact, including accepted Walking and approved `Run_Snappy_Test_v001`. Actual pack/member hashes verified: `animations/f2da1071.json` / `animation.oreville_ans.fngydr`, `animation_controllers/616f2ff7.json`, `entity/dtr.json`. Reconstruct Run rotation/translation/1.07 leg-scale pulse with native straight limbs, settled sprint, independent lifetime bob and declared generic main-hand holding attenuation; original source key times and linear interpolation retained in 2,996 dense samples. Explicit matrix convention and native hierarchy/entity-relative Head adaptation documented. Six-second continuous take F1–180/30FPS, endpoint181; no artificial short composite loop. Canonical 1.6Hz (.625s) differs from approximately17-frame recorded recurrence; unknown recording version/state prevents attributing the difference to a verified version change. Nine original-speed H264 videos: original/source/approved Run in front/3/4/side, source-only three views/full take and separately labelled video-cadence diagnostic. Saved source and fresh central reopen reproduce evaluated source/profile matrices at942 times (max component error1.67e-6); leg-scale error2.42e-7. Constant native display floor -33.674mm; no foot locking or trajectory correction, no Minecraft contact-certification claim. All37 slots/timing/rest/source hashes/cameras verified; source-scale→approved Run/accepted Walk/Idle resets pass. Separate native Blender reopen/playback reaches180, automatically stops, replays from1 and pauses; no GUI blend save. Narrow provenance-bound viewer scale exception retains ordinary Action restrictions and rejects modifiers on source scale. Research/non-production banner and Mac launcher provided. Pack's missing primary humanoid geometry, unknown held hand/bob/look, entity-relative Head composition and nonpositive directional-weight runtime semantics remain explicit limits. Player master library, all prior source studies, registration helper, protected Godot files and production assets preserved; no gameplay integration. Review: [source Running package](../../blender/animation/reviews/player_animation_library_v1/actions_stuff_run_v001/README.md). Stop for visual review.

'''
progress.write_text(entry+progress.read_text())
readme=(STAGE/'README.md').read_text()
readme=readme.replace('[Media checks](media_validation.json)', '[Media checks](media_validation.json) · [Decoded video samples](decoded_media_validation.json) · [Native playback checks](gui_playback_validation.json)')
(STAGE/'README.md').write_text(readme)
for file in ['README.md','progress.md','publication_validation.json','showcase_validation.json','gui_playback_validation.json','decoded_media_validation.json','finalize_research.py']:
 shutil.copy2(STAGE/file,OUT/file)
manifest=json.loads((LIB/'animation_manifest.json').read_text())
assert manifest['animations'][:-1]==state['entries_before']
assert manifest['animations'][-1]['action']==state['action'] and manifest['animations'][-1]['status']=='pending'
assert sha(OUT/'run_actions_stuff_review.blend')==meta['source_sha256']
for row in json.loads((OUT/'media_validation.json').read_text())['videos']:
 assert sha(OUT/row['path'])==row['sha256'],row['path']
assert sha(state['pack_path'])==state['pack_sha256'] and sha(state['reference_path'])==state['reference_sha256']
assert sha(LIB/'register_animation.py')==state['protected']['blender/animation/showcase/register_animation.py']
bad=[p for p,h in state['protected'].items() if p not in intentional and sha(ROOT/p)!=h]
assert not bad,bad
report={'passed':True,'protected_before':len(state['protected']),'protected_existing_files_exact':len(state['protected'])-len(intentional),
 'intentional_existing_changes':sorted(intentional),'all_36_old_manifest_entries_exact':True,
 'previous_36_action_signatures_verified_in_fresh_showcase':True,'accepted_walk_preserved':True,
 'approved_run_preserved':True,'player_master_preserved':True,'godot_protected_files_exact':True,
 'registration_helper_unchanged':True,'pack_hash_exact':True,'original_video_hash_exact':True,
 'published_source_sha256':meta['source_sha256'],'nine_video_hashes_exact':True,
 'independent_runtime_equivalence_claim':False,'research_only':True,'production_eligible':False,
 'git_after':subprocess.run(['git','-C',str(ROOT),'status','--short'],capture_output=True,text=True).stdout}
for folder in [STAGE,OUT]:(folder/'preservation_validation.json').write_text(json.dumps(report,indent=2))
for p in [OUT/'README.md',OUT/'RECONSTRUCTION_NOTES.md']:
 for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if not target.startswith(('http:','https:')):assert (p.parent/target.split('#')[0]).exists(),(p.name,target)
print('RESEARCH_DELIVERY_VALIDATED',json.dumps({k:v for k,v in report.items() if k!='git_after'}),flush=True)
