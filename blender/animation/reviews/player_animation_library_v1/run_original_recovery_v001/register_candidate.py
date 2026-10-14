"""Append exactly one compatible Pending Action; retain all existing entries."""
import bpy,json,hashlib,sys,os
from pathlib import Path
STAGE=Path(__file__).resolve().parent
state=json.loads((STAGE/'preservation_before.json').read_text());ROOT=Path(state['project']);OUT=Path(state['package_destination']);LIB=ROOT/'blender/animation/showcase'
sys.path.insert(0,str(LIB));import gaf_animation_library as ui
from register_animation import register_entry
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
name=state['action'];validation=json.loads((OUT/'motion_validation.json').read_text())
assert validation['passed'] and validation['source_sha256']==sha(Path(bpy.data.filepath))
assert Path(bpy.data.filepath).resolve()==(OUT/'run_original_recovery_review.blend').resolve()
for rel in ['blender/animation/showcase/Animation_Showcase.blend','blender/animation/showcase/animation_manifest.json']:
 assert sha(ROOT/rel)==state['protected'][rel], 'Concurrent central-library edit: '+rel
old=json.loads((LIB/'animation_manifest.json').read_text());assert old['animations']==state['entries_before']
register_entry(name,state['baseline']['source_rig'],state['baseline']['source_mesh'],1,17,30)
manifest=json.loads((LIB/'animation_manifest.json').read_text());e=manifest['animations'][-1]
e.update(seamless_loop=True,closing_key=18,period_s=17/30,in_place=True,nominal_speed_m_s=2.5,
         contact_frames={'L':1,'R':9.5},support_duty={'L':.39,'R':.40},
         baseline_action='Run_Snappy_Test_v001',
         approval_note='Pending human artistic review. Original free-leg gather/exchange experiment from approved Snappy Run; body, arms, cadence and low sole envelope preserved. No proprietary animation inputs; no production promotion.',
         review_video=str((OUT/'candidate_three_views_1x.mp4').relative_to(ROOT)),
         gameplay_validation='Not tested or integrated in Godot; native Blender review only.',
         authoring_note='Independently authored recovery pitch events on our own approved Run. Source-derived reconstructions excluded.')
assert manifest['animations'][:-1]==old['animations'] and e['status']=='pending'
(LIB/'animation_manifest.json').write_text(json.dumps(manifest,indent=2));manifest_sha=sha(LIB/'animation_manifest.json')
bpy.ops.wm.open_mainfile(filepath=str(LIB/'Animation_Showcase.blend'),load_ui=False)
ui.register();scene=bpy.context.scene
before={a.name:ui.action_signature(a)for a in bpy.data.actions}
assert len(before)==len(old['animations'])
assert all(ui.action_signature(bpy.data.actions[x['action']])==x['action_sha256']for x in old['animations'])
assert ui.refresh(scene)==1
assert len(scene.gaf_clips)==len(bpy.data.actions)==len(before)+1
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
scene.gaf_active_index=len(before);ui.activate(scene,len(before));ui.view(scene,'THREE_QUARTER');scene.gaf_loop=True
stage=LIB/'Animation_Showcase.original_recovery_v001.staged.blend'
assert not stage.exists()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(stage),relative_remap=False,compress=True)
assert sha(LIB/'Animation_Showcase.blend')==state['protected']['blender/animation/showcase/Animation_Showcase.blend']
assert sha(LIB/'animation_manifest.json')==manifest_sha
os.replace(stage,LIB/'Animation_Showcase.blend')
report={'previous_count':len(before),'current_count':len(before)+1,'candidate_status':'pending',
        'previous_actions':before,'previous_entries_exact':True,'previous_action_signatures_exact':True,
        'showcase_sha256':sha(LIB/'Animation_Showcase.blend'),'manifest_sha256':manifest_sha}
(OUT/'registration.json').write_text(json.dumps(report,indent=2));(STAGE/'registration.json').write_text(json.dumps(report,indent=2))
print('REGISTERED_ONE_PENDING_ACTION_ALL_PREVIOUS_PRESERVED',flush=True)
