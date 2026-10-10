"""Explicit in-task user correction of this Pending v3 only; never approved Actions."""
import bpy,json,sys,hashlib,shutil,subprocess
from pathlib import Path
from mathutils import Matrix
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];SHOW=ROOT/'blender/animation/showcase';TMP=ROOT/'.validation/idle_expressive_test_v3'
sys.path.insert(0,str(SHOW));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
previous=json.loads((TMP/'before_sideways_revision/animation_manifest.json').read_text());guard=json.loads((TMP/'before_sideways_revision/current_guard.json').read_text())
assert all(sha(Path(p))==h for p,h in guard.items()),'Concurrent library change before correction'
manifest=json.loads((SHOW/'animation_manifest.json').read_text());assert manifest==previous
entry=manifest['animations'][-1];assert entry['action']=='Idle_Expressive_Test_v3' and entry['status']=='pending'
r=bpy.data.objects['IEV3_Test_Rig'];m=bpy.data.objects['IEV3_Test_Mesh'];a=bpy.data.actions[entry['action']]
v=json.loads((OUT/'validation.json').read_text());assert v['passed'] and v['sampled_source_sha256']==sha(Path(bpy.data.filepath)) and v['sampled_action_sha256']==ui.action_signature(a)
assert ui.rest_signature(r.data)==manifest['rig_sha256'] and {b.name:b.rotation_mode for b in r.pose.bones}==manifest['rotation_modes']
assert m.parent==r and any(x.type=='ARMATURE' and x.object==r for x in m.modifiers) and r.matrix_world==Matrix.Identity(4)
assert not any(b.constraints for b in r.pose.bones) and not r.animation_data.nla_tracks and not r.animation_data.drivers
entry.update({'source_sha256':v['sampled_source_sha256'],'action_sha256':v['sampled_action_sha256'],'slot_identifier':a.slots[0].identifier,'action_frame_range':list(a.frame_range),'presentation_note':'Latest correction: SIDEWAYS whole-leg opening L3/R8deg; zero forward pitch or toe-out yaw, no running stagger. Fixed outer sole edges; slow6mm body breathing rise over4s. Static root, playback1-240, closing241 excluded. V2 unchanged.','revision_note':'Explicit latest user sideways-leg/breathing correction within unapproved v3; whole previous candidate and viewer archived. No approved Action replaced.'})
ui.validate_action(a,entry,r)
backup=TMP/'before_sideways_registration';backup.mkdir()
for name in ['Animation_Showcase.blend','animation_manifest.json']:shutil.copy2(SHOW/name,backup/name)
(backup/'working_tree.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT,text=True),encoding='utf8')
assert manifest['animations'][:-1]==previous['animations'][:-1]
p=SHOW/'animation_manifest.json';temp=p.with_suffix('.json.tmp');temp.write_text(json.dumps(manifest,indent=2));temp.replace(p)
(TMP/'clean_registration_guard.json').write_text(json.dumps({'showcase_sha256_before':sha(SHOW/'Animation_Showcase.blend'),'manifest_sha256_after':sha(p),'previous_v3_action_sha256':previous['animations'][-1]['action_sha256'],'new_action_sha256':entry['action_sha256']},indent=2))
print('CORRECTED CURRENT PENDING V3 METADATA; PREVIOUS TEN ENTRIES UNCHANGED',flush=True)
