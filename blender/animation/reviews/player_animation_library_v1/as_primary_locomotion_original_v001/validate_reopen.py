import bpy,json,hashlib,runpy,sys
from pathlib import Path
from mathutils import Matrix
H=Path(__file__).resolve().parent;R=H.parents[4];LIB=R/'blender/animation/showcase'
runpy.run_path(str(R/'scripts/load_showcase_ui.py'),run_name='__main__');import gaf_animation_library as ui
B=R/'.validation/animation_showcase/as_primary_locomotion_original_v001'
old=json.loads((B/'animation_manifest.json').read_text(encoding='utf8'));data=json.loads((LIB/'animation_manifest.json').read_text(encoding='utf8'));base=json.loads((B/'baseline.json').read_text(encoding='utf8'))
assert data['animations'][:len(old['animations'])]==old['animations']
assert data['review_sequences'][:len(old['review_sequences'])]==old['review_sequences']
new=data['animations'][len(old['animations']):];assert len(new)==3 and all(e['status']=='pending'for e in new)
home=bpy.data.scenes['ANIMATION_SHOWCASE'];rig=bpy.data.objects[ui.RIG];checks=[]
for e in new:
 ui.validate_action(bpy.data.actions[e['action']],e,rig);ui.select_registered_action(bpy.context,e['action'])
 assert rig.animation_data.action.name==e['action'] and rig.animation_data.action_slot.identifier==e['slot_identifier']
 assert home.frame_start==e['start']and home.frame_end==e['end']and home.render.fps==60 and home.render.fps_base==1
 home.frame_set(17)
 assert max(abs(v-1)for b in rig.pose.bones for v in b.scale)<1e-6
 assert all(max(abs(b.matrix_basis[i][j]-Matrix.Identity(4)[i][j])for i in range(4)for j in range(4))<1e-5 for b in rig.pose.bones if b.name.startswith('ForeArm'))
 checks.append({'action':e['action'],'slot':e['slot_identifier'],'range':[e['start'],e['end']],'pending':True})
idle=next(e for e in old['animations']if e['action']=='Idle_ActionsStuff_Source_Test_v001');ui.select_registered_action(bpy.context,idle['action'])
assert idle['status']=='approved'and rig.animation_data.action.name==idle['action']
reviews=data['review_sequences'][len(old['review_sequences']):];assert len(reviews)==2
for e in reviews:
 ui.validate_review_sequence(e);ui.open_review_sequence(bpy.context,e['id']);s=bpy.context.scene
 for d in ['FRONT','SIDE','THREE_QUARTER']:ui.view(s,d);assert s.camera.name==e['cameras'][d]
 for actor in e['comparison_actors']:
  r=bpy.data.objects[actor['rig']];assert r.animation_data.action.name==actor['action']and ui.rest_signature(r.data)==data['rig_sha256']
 assert s.sync_mode=='FRAME_DROP'
changed=[]
for path,digest in base['godot'].items():
 p=R/path
 if not p.exists()or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:changed.append(path)
assert not changed,changed
ui.open_review_sequence(bpy.context,reviews[0]['id']);s=bpy.context.scene;s.gaf_loop=True;s.frame_set(1)
# Save only the selected review view; no authored curve or metadata mutation.
bpy.ops.wm.save_as_mainfile(filepath=str(LIB/'Animation_Showcase.blend'))
(H/'reopen_validation.json').write_text(json.dumps({'prior_registry_entries_preserved':len(old['animations']),'prior_review_entries_preserved':len(old['review_sequences']),'total_actions':len(bpy.data.actions),'new_pending_actions':checks,'review_cameras_checked':6,'unchanged_godot_files':len(base['godot']),'godot_changes':changed,'idle_approved_preserved':True,'native_rest_sha256':ui.rest_signature(rig.data)},indent=2),encoding='utf8')
print('REOPEN_AND_PRESERVATION_OK',len(checks),len(base['godot']),flush=True)
