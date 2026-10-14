import bpy,json,sys,hashlib
from pathlib import Path
STAGE=Path(__file__).resolve().parent
state=json.loads((STAGE/'preservation_before.json').read_text());ROOT=Path(state['project']);OUT=Path(state['package_destination']);LIB=ROOT/'blender/animation/showcase'
sys.path.insert(0,str(LIB));import gaf_animation_library as ui
ui.register();scene=bpy.context.scene;manifest=json.loads((LIB/'animation_manifest.json').read_text())
assert manifest['animations'][:-1]==state['entries_before']
assert manifest['animations'][-1]['action']==state['action'] and manifest['animations'][-1]['status']=='pending'
assert len(bpy.data.actions)==len(manifest['animations'])==len(scene.gaf_clips)==36
checks=[]
for i,e in enumerate(manifest['animations']):
 ui.activate(scene,i);rig=bpy.data.objects[ui.RIG];a=bpy.data.actions[e['action']]
 assert rig.animation_data.action==a and rig.animation_data.action_slot==a.slots[0]
 assert scene.frame_start==e['start'] and scene.frame_end==e['end'] and scene.render.fps==e['fps']
 ui.validate_action(a,e,rig)
 assert ui.rest_signature(rig.data)==manifest['rig_sha256']
 checks.append(e['action'])
index=len(checks)-1;scene.gaf_active_index=index;ui.activate(scene,index)
for direction in ['FRONT','THREE_QUARTER','SIDE']:
 ui.view(scene,direction);assert scene.camera.name=='Showcase_'+direction
ui.view(scene,'THREE_QUARTER')
rig=bpy.data.objects[ui.RIG];e=manifest['animations'][-1]
def matrices():return {p.name:[list(r)for r in p.matrix]for p in rig.pose.bones}
scene.frame_set(1);bpy.context.view_layer.update();start=matrices()
scene.frame_set(18);bpy.context.view_layer.update();end=matrices()
assert max(abs(start[n][r][c]-end[n][r][c])for n in start for r in range(4)for c in range(4))<1e-6
# Dirty the pose, then switch back: activation must reset and bind the right slot.
rig.pose.bones['Head'].location.z+=.3
ui.activate(scene,0);ui.activate(scene,index);scene.frame_set(1);bpy.context.view_layer.update()
reset=matrices();assert max(abs(start[n][r][c]-reset[n][r][c])for n in start for r in range(4)for c in range(4))<1e-6
report={'passed':True,'reopened_from_disk':True,'all_actions_selectable':len(checks),'exact_source_signatures':len(checks),
        'slots_and_timing_pass':True,'pose_reset_pass':True,'three_cameras_pass':True,'loop_pose_seam_pass':True,
        'old_entries_exact':True,'candidate':state['action'],'candidate_status':'pending','no_gui_playback_claim':True}
(OUT/'showcase_validation.json').write_text(json.dumps(report,indent=2));(STAGE/'showcase_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2),flush=True)
