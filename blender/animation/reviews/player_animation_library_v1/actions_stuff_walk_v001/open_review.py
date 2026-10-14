"""Show the saved walk in a separate Blender window without saving over user work."""
import bpy,json,time
from pathlib import Path
HERE=Path(__file__).resolve().parent
exec(bpy.data.texts['START_HERE_review_controls.py'].as_string(),{'__name__':'asw_player_review_ui'})
master=bpy.data.scenes['PLAYER_ANIMATION_LIBRARY_V1'];master.player_review_group='Locomotion'
bpy.ops.player_review.select(clip_id='asw_walk_source_v001');bpy.ops.player_review.camera(direction='THREE_QUARTER')
s=bpy.context.scene;s.sync_mode='NONE'
state={'started':False,'previous':s.frame_current,'wraps':0,'observed_frames':set(),'start':time.monotonic()}
def tick():
 if not state['started']:
  bpy.ops.screen.animation_play();state['started']=True;return .05
 f=s.frame_current;state['observed_frames'].add(f)
 if f<state['previous']:state['wraps']+=1
 state['previous']=f
 if state['wraps']>=3:
  if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_play()
  paused=not bpy.context.screen.is_animation_playing;s.frame_set(1)
  result={'native_gui_playback':True,'observed_wraps':state['wraps'],'observed_frame_count':len(state['observed_frames']),'pause_verified':paused,'restart_frame':s.frame_current,'active_scene':s.name,'active_action':bpy.data.objects['ASW_Player_Rig_v001'].animation_data.action.name,'fps':s.render.fps,'playback':[s.frame_start,s.frame_end]}
  (HERE/'gui_playback_verification.json').write_text(json.dumps(result,indent=2))
  try:bpy.ops.screen.screenshot(filepath=str(HERE/'blender_review_screenshot.png'))
  except Exception:pass
  return None
 if time.monotonic()-state['start']>45:
  (HERE/'gui_playback_verification.json').write_text(json.dumps({'native_gui_playback':False,'reason':'timed out','wraps':state['wraps']}));return None
 return .05
bpy.app.timers.register(tick,first_interval=2)
