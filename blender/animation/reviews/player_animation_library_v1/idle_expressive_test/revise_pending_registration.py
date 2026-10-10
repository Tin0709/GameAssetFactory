"""One explicitly requested refinement of the SAME Pending Idle; never approved Actions.

Run with the validated candidate. Guard latest source/viewer/manifest hashes, retain
backups, then promote the candidate and replace only the Pending manifest entry.
The ordinary registration helper intentionally refuses duplicate names.
"""
import bpy,json,hashlib,shutil,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

assert Path(bpy.data.filepath)==OUT/'idle_expressive_lookaround_candidate.blend'
assert json.loads((OUT/'lookaround_validation.json').read_text())['passed']
snapshot=json.loads((TMP/'quiet_pass/snapshot.json').read_text())['files']
manifest_path=ROOT/'blender/animation/showcase/animation_manifest.json'
viewer=manifest_path.with_name('Animation_Showcase.blend')
manifest=json.loads(manifest_path.read_text());old_manifest=json.loads((TMP/'quiet_pass/animation_manifest.json').read_text())
assert manifest==old_manifest,'Concurrent manifest change; inspect and preserve it before refining'
old=manifest['animations'][-1];assert old['action']=='Idle_Expressive_Test' and old['status']=='pending'
source=ROOT/old['source']
assert all(sha(p)==snapshot[str(p)] for p in [source,viewer,manifest_path]),'Concurrent source/viewer change'
a=bpy.data.actions[old['action']];r=bpy.data.objects['IE_Test_Rig']
assert ui.rest_signature(r.data)==manifest['rig_sha256']
assert all(ui.action_signature(bpy.data.actions[e['action']])==e['action_sha256'] for e in manifest['animations'][:-1])
entry=dict(old);entry.update(source_sha256=sha(Path(bpy.data.filepath)),action_sha256=ui.action_signature(a),action_frame_range=list(a.frame_range),end=144,closing_key=145,period_s=4.8,seamless_loop=True,
    refinement_note='Explicit user steering: keep this same Pending Action name; add head-led curious LookAround, observation/rest pauses and delayed body response. Earlier working passes backed up. Not an approved Action overwrite.')
ui.validate_action(a,entry,r)
backup=TMP/'before_lookaround_promotion';backup.mkdir(exist_ok=False)
for p in [source,viewer,manifest_path]:shutil.copy2(p,backup/p.name)
manifest['animations'][-1]=entry
temp=source.with_suffix('.blend.new');shutil.copy2(Path(bpy.data.filepath),temp);temp.replace(source)
temp_manifest=manifest_path.with_suffix('.json.tmp');temp_manifest.write_text(json.dumps(manifest,indent=2),encoding='utf8');temp_manifest.replace(manifest_path)
assert manifest['animations'][:-1]==old_manifest['animations'][:-1]
shutil.copy2(OUT/'lookaround_manifest.json',OUT/'manifest.json');shutil.copy2(OUT/'lookaround_validation.json',OUT/'validation.json')
(OUT/'pending_revision.json').write_text(json.dumps({'explicit_same_pending_name_refinement':True,'status':'pending','backup':str(backup.relative_to(ROOT)),'old_entry':old,'new_entry':entry,'all_previous_entries_identical':True},indent=2),encoding='utf8')
print('PROMOTED SAME PENDING IDLE LOOKAROUND / PREVIOUS EIGHT UNCHANGED',flush=True)
