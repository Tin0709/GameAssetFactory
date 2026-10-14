"""Record final scope/preservation evidence; update only required Progress notes."""
import json,hashlib,subprocess,re,shutil
from pathlib import Path
from datetime import datetime,timezone
STAGE=Path(__file__).resolve().parent
state=json.loads((STAGE/'preservation_before.json').read_text());ROOT=Path(state['project']);OUT=Path(state['package_destination'])
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
show=json.loads((OUT/'showcase_validation.json').read_text());assert show['passed']
gui=json.loads((OUT/'gui_playback_validation.json').read_text());assert gui['passed'] and gui['pause_pass'] and gui['restart_frame_pass'] and gui['wraps']>=3 and gui['restart_wraps']>=1
for filename in ['README.md','gui_review.py','finalize_package.py','progress.md']:
 shutil.copy2(STAGE/filename,OUT/filename)
manifest=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text());assert manifest['animations'][:-1]==state['entries_before']
assert manifest['animations'][-1]['status']=='pending' and manifest['animations'][-1]['action']==state['action']
allowed={'blender/animation/showcase/Animation_Showcase.blend','blender/animation/showcase/animation_manifest.json','docs/animation/ANIMATION_PROGRESS.md'}
protected=[]
for rel,h in state['protected'].items():
 if rel in allowed:continue
 assert sha(ROOT/rel)==h,'Unexpected protected edit: '+rel
 protected.append(rel)
doc=ROOT/'docs/animation/ANIMATION_PROGRESS.md'
assert sha(doc)==state['protected']['docs/animation/ANIMATION_PROGRESS.md'],'Concurrent progress edit'
entry='''**Original Run Recovery v001 — 2026-10-14, Pending:** one separate `Run_Original_Recovery_Test_v001` from approved `Run_Snappy_Test_v001`. Independently authored free-leg pitch/gather/opening curves; source pack keys and source-derived poses excluded. Same17frames/30FPS, body/arms/world support exact, sole-height envelope within.00474mm. Passing7.03/10.42ms earlier; native30FPS max leg step26.18→23.97deg over64 starting offsets. Improvement is modest and requires artistic review; no gameplay-quality claim. Dense2177 geometry checks pass; existing adjacent torso/leg overlap and raw first-order seam flag explicitly retained. Front/3q/side and approved/candidate media: seven102frame/30FPS videos, six continuous cycles. SAME existing Showcase now36entries/all35 prior entries and Action signatures exact; saved/reopened selection/slots/reset/range/cameras/loop checked. Separate nativeGUI four wraps/pause/restart/two further wraps passed. Approved Run/Walking, player master library, previous Run sources, rig and Godot preserved. Review: blender/animation/reviews/player_animation_library_v1/run_original_recovery_v001/README.md. Stop at Blender review; no Godot integration or production promotion.\n\n'''
doc.write_text(entry+doc.read_text())
registration=json.loads((OUT/'registration.json').read_text())
assert sha(ROOT/'blender/animation/showcase/Animation_Showcase.blend')==registration['showcase_sha256']
assert sha(ROOT/'blender/animation/showcase/animation_manifest.json')==registration['manifest_sha256']
motion=json.loads((OUT/'motion_validation.json').read_text());assert motion['passed'] and sha(OUT/'run_original_recovery_review.blend')==motion['source_sha256']
media=json.loads((OUT/'media_validation.json').read_text());assert media['passed']
for v in media['videos']:assert sha(OUT/v['path'])==v['sha256']
links=[]
for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)',(OUT/'README.md').read_text()):
 if target=='preservation_validation.json':continue
 assert (OUT/target).exists(),target
 links.append(target)
result={'passed':True,'verified_at_utc':datetime.now(timezone.utc).isoformat(),'protected_files_exact':len(protected),
        'protected_files':protected,'intentional_existing_changes':sorted(allowed),
        'old_manifest_entries_exact':len(state['entries_before']),'showcase_count':len(manifest['animations']),
        'all_previous_approved_actions_preserved':True,'no_godot_writes':True,'no_production_asset_writes':True,
        'candidate':state['action'],'status':'pending','candidate_source_sha256':motion['source_sha256'],
        'action_sha256':motion['action_sha256'],'media_files_verified':len(media['videos']),
        'decoded_video_frames_verified':json.loads((OUT/'decoded_video_validation.json').read_text())['passed'],
        'native_gui_playback_verified':gui['passed'],'native_gui_wraps':[gui['wraps'],gui['restart_wraps']],
        'readme_links_verified':len(links),
        'backup':str(ROOT/'.validation/run_original_recovery_v001/before'),
        'git_status_after':subprocess.check_output(['git','-C',str(ROOT),'status','--short','--untracked-files=normal'],text=True)}
(OUT/'preservation_validation.json').write_text(json.dumps(result,indent=2));(STAGE/'preservation_validation.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items()if k not in ['protected_files','git_status_after']},indent=2))
