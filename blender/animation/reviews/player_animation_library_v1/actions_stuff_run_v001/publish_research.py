"""Publish one immutable research source and append it to the existing Showcase."""
import bpy,json,sys,hashlib,shutil,os,importlib.util
from pathlib import Path
STAGE=Path(__file__).resolve().parent
state=json.loads((STAGE/'preservation_before.json').read_text())
ROOT=Path(state['project']);OUT=Path(state['package_destination']);LIB=ROOT/'blender/animation/showcase'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
changed=[p for p,h in state['protected'].items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h]
assert not changed,('Concurrent protected changes; publication cancelled',changed)
assert sha(state['pack_path'])==state['pack_sha256'] and sha(state['reference_path'])==state['reference_sha256']
assert not OUT.exists(), 'Do not overwrite a published study'
meta=json.loads((STAGE/'manifest.json').read_text())
assert sha(STAGE/'run_actions_stuff_review.blend')==meta['source_sha256']
backup=ROOT/'.validation/actions_stuff_run_source_v001/before';backup.mkdir(parents=True,exist_ok=False)
for p in ['Animation_Showcase.blend','animation_manifest.json','gaf_animation_library.py','register_animation.py']:
 shutil.copy2(LIB/p,backup/p)
shutil.copy2(ROOT/'docs/animation/ANIMATION_PROGRESS.md',backup/'ANIMATION_PROGRESS.md')
shutil.copy2(STAGE/'preservation_before.json',backup/'preservation_before.json')
OUT.mkdir(parents=True)
for p in STAGE.iterdir():
 if p.is_file() and p.suffix in {'.blend','.py','.json','.md','.mp4','.png','.jpg'}:
  shutil.copy2(p,OUT/p.name)
for name in ['source','controller_research','video_research','viewer_tests']:
 shutil.copytree(STAGE/name,OUT/name,ignore=shutil.ignore_patterns('native_frames','__pycache__','*.log'))
launcher=OUT/'Open_Source_Run_Research.command'
launcher.write_text('#!/bin/zsh\nscript_dir="${0:A:h}"\nexec /Applications/Blender.app/Contents/MacOS/Blender --factory-startup --disable-autoexec "${script_dir}/../../../showcase/Animation_Showcase.blend" --python "${script_dir}/open_research.py"\n')
launcher.chmod(0o755)
assert sha(LIB/'gaf_animation_library.py')==state['protected']['blender/animation/showcase/gaf_animation_library.py']
shutil.copy2(STAGE/'gaf_animation_library.research.py',LIB/'gaf_animation_library.py')
sys.path.insert(0,str(LIB));import gaf_animation_library as ui
bpy.ops.wm.open_mainfile(filepath=str(OUT/'run_actions_stuff_review.blend'))
spec=importlib.util.spec_from_file_location('private_research_registration',STAGE/'register_animation.research.py')
reg=importlib.util.module_from_spec(spec);spec.loader.exec_module(reg);reg.OUT=LIB;reg.ROOT=ROOT
research={k:meta[k] for k in ['research_only','production_eligible','source_animation','source_pack_sha256','research_scale_channels']}
reg.register_entry(state['action'],meta['source_rig'],meta['source_mesh'],meta['start'],meta['end'],meta['fps'],research_metadata=research)
mp=LIB/'animation_manifest.json';manifest=json.loads(mp.read_text())
assert manifest['animations'][:-1]==state['entries_before']
entry=manifest['animations'][-1]
entry.update({k:meta[k] for k in ['preview_floor_z_m','seamless_loop','duration_s','core_period_s','endpoint_sample','profile','rotation_convention','head_convention']})
entry.update({'in_place':True,'research_notes':str((OUT/'RECONSTRUCTION_NOTES.md').relative_to(ROOT)),
 'review_sequence':str((OUT/'reference_source_approved_front_1x.mp4').relative_to(ROOT)),
 'research_clock_note':'Six-second continuous take; no fabricated short composite loop. Replay resets declared clocks.',
 'approval_note':'Source-derived research only. Pending visual review; never eligible for commercial production.'})
temp=mp.with_suffix('.json.tmp');temp.write_text(json.dumps(manifest,indent=2));temp.replace(mp)
manifest_sha=sha(mp)
bpy.ops.wm.open_mainfile(filepath=str(LIB/'Animation_Showcase.blend'))
ui.register();s=bpy.context.scene
assert {a.name:ui.action_signature(a) for a in bpy.data.actions}==meta['previous_action_signatures']
assert ui.refresh(s)==1
assert len(bpy.data.actions)==len(s.gaf_clips)==len(manifest['animations'])==37
for name,h in meta['previous_action_signatures'].items():assert ui.action_signature(bpy.data.actions[name])==h,name
assert ui.action_signature(bpy.data.actions[state['action']])==meta['action_sha256']
s.gaf_active_index=36;ui.activate(s,36);ui.view(s,'THREE_QUARTER');s.gaf_loop=False;s.frame_set(1)
assert abs(bpy.data.objects['Showcase_FixedFloor'].location.z-meta['preview_floor_z_m'])<1e-8
assert ui.rest_signature(bpy.data.objects[ui.RIG].data)==meta['rig_sha256']
bpy.context.preferences.filepaths.save_version=0
tempblend=LIB/'Animation_Showcase.source_run_v001.staged.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(tempblend),relative_remap=False)
assert sha(LIB/'Animation_Showcase.blend')==state['protected']['blender/animation/showcase/Animation_Showcase.blend']
assert sha(mp)==manifest_sha
os.replace(tempblend,LIB/'Animation_Showcase.blend')
assert sha(OUT/'run_actions_stuff_review.blend')==meta['source_sha256']
assert sha(LIB/'register_animation.py')==state['protected']['blender/animation/showcase/register_animation.py']
proof={'published':True,'entries':37,'old_entries_exact':True,'old_action_signatures_exact':36,
 'source_sha256':meta['source_sha256'],'action_sha256':meta['action_sha256'],
 'central_sha256':sha(LIB/'Animation_Showcase.blend'),'manifest_sha256':manifest_sha,
 'viewer_sha256':sha(LIB/'gaf_animation_library.py'),'registration_helper_unchanged':True,
 'correct_preview_floor_z_m':meta['preview_floor_z_m'],'backup':str(backup)}
for folder in [STAGE,OUT]:(folder/'publication_validation.json').write_text(json.dumps(proof,indent=2))
print('PUBLISHED_SOURCE_RUN_RESEARCH',json.dumps(proof),flush=True)
