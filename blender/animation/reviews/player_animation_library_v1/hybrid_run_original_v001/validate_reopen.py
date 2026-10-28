import bpy,runpy,json,sys,math
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4];LIB=ROOT/'blender/animation/showcase'
runpy.run_path(str(ROOT/'scripts/load_showcase_ui.py'),run_name='__main__');import gaf_animation_library as ui
manifest=json.loads((LIB/'animation_manifest.json').read_text());old=json.loads((ROOT/'.validation/animation_showcase/hybrid_run_original_v001/animation_manifest.json').read_text())
assert manifest['animations'][:66]==old['animations'] and manifest['review_sequences'][:2]==old['review_sequences']
new=manifest['animations'][66:];assert len(new)==3
for e in new:e['playback_sync']='FRAME_DROP';ui.validate_action(bpy.data.actions[e['action']],e,bpy.data.objects[ui.RIG])
entry=manifest['review_sequences'][-1];entry['playback_sync']='FRAME_DROP'
home=bpy.data.scenes['ANIMATION_SHOWCASE'];home['gaf_manifest_snapshot']=json.dumps(manifest)
for clip in home.gaf_clips:
 for e in new:
  if clip.action==e['action']:clip.entry_json=json.dumps(e)
scene=bpy.data.scenes[entry['scene']];scene['gaf_review_entry_json']=json.dumps(entry)
(LIB/'animation_manifest.json').write_text(json.dumps(manifest,indent=2))
# Reopened saved Actions: seam, half-cycle repetition, rigid helpers, slots.
results=[]
for e in new:
 ui.select_registered_action(bpy.context,e['action']);rig=bpy.data.objects[ui.RIG]
 assert rig.animation_data.action.name==e['action'] and rig.animation_data.action_slot.identifier==e['slot_identifier']
 home.frame_set(1);first={b.name:b.matrix.copy()for b in rig.pose.bones}
 home.frame_set(33);err=max(abs(first[b.name][i][j]-b.matrix[i][j])for b in rig.pose.bones for i in range(4)for j in range(4));assert err<1e-5,err
 for c in ui.curves(rig.animation_data.action):
  if '.scale' in c.data_path:assert all(abs(k.co.y-1)<1e-6 for k in c.keyframe_points)
  if 'ForeArm.' in c.data_path:
   neutral=1 if c.data_path.endswith('rotation_quaternion') and c.array_index==0 else 0
   if '.scale'not in c.data_path:assert all(abs(k.co.y-neutral)<1e-6 for k in c.keyframe_points)
 assert home.frame_start==1 and home.frame_end==128 and abs(home.render.fps/home.render.fps_base/32-1.888)<1e-7
 results.append({'action':e['action'],'pose_cycle_error':err,'selected_slot':rig.animation_data.action_slot.identifier})
ui.open_review_sequence(bpy.context,entry['id']);scene.gaf_loop=True;assert scene.sync_mode=='FRAME_DROP'
for direction in ['FRONT','SIDE','THREE_QUARTER']:ui.view(scene,direction);assert scene.camera.name==entry['cameras'][direction]
for actor in entry['comparison_actors']:assert bpy.data.objects[actor['rig']].animation_data.action.name==actor['action']
scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(LIB/'Animation_Showcase.blend'))
(HERE/'reopen_validation.json').write_text(json.dumps({'old_entries_preserved':66,'old_review_entries_preserved':2,'total_actions':len(bpy.data.actions),'new_pending':results,'comparison_cameras':3,'synchronized_actors':3,'gait_hz':1.888,'frame_bounds':[1,128],'fps_base':scene.render.fps_base,'sync_mode':scene.sync_mode},indent=2));print('HYBRID_REOPEN_VALIDATED',results,flush=True)
