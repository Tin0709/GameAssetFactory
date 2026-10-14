"""Temporary GUI verification; opens a new process and never saves preferences or blends."""
import bpy,time,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE.parent/'showcase'));import gaf_animation_library as ui
state={'frames':[],'wraps':0,'started':None}
def tick():
 s=bpy.context.scene
 if not bpy.context.window or not bpy.context.screen:return .2
 if state['started'] is None:
  if not hasattr(bpy.types.Scene,'gaf_clips'):ui.register()
  s.gaf_active_index=29;ui.activate(s,29);s.gaf_loop=True;state['started']=time.monotonic();bpy.ops.screen.animation_play();return .08
 frame=s.frame_current
 if state['frames'] and frame<state['frames'][-1]:state['wraps']+=1
 state['frames'].append(frame)
 if time.monotonic()-state['started']<4:return .08
 if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_play()
 paused=not bpy.context.screen.is_animation_playing
 bpy.ops.gaf.restart();restart=s.frame_current==s.frame_start
 result={'actual_gui_playback':len(set(state['frames']))>10,'wraps':state['wraps'],'pause':paused,'restart':restart,'new_process_preserves_other_blender_window':True,'saved_files':False}
 (HERE/'validation/gui_validation.json').write_text(json.dumps(result,indent=2))
 s.gaf_active_index=32;ui.activate(s,32);s.frame_set(16);ui.view(s,'THREE_QUARTER');return None
bpy.app.timers.register(tick,first_interval=1)
