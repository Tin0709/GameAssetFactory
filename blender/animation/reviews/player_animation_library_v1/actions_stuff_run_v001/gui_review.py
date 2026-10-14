"""Native playback in a separate GUI process. No blend save and no global preferences."""
import bpy,json,sys,time
from pathlib import Path
STAGE=Path(__file__).resolve().parent
state=json.loads((STAGE/'preservation_before.json').read_text());ROOT=Path(state['project']);OUT=Path(state['package_destination'])
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
ui.register();ui.loaded(None)
s=bpy.context.scene;name=state['action'];index=next(i for i,c in enumerate(s.gaf_clips)if c.action==name)
s.gaf_active_index=index;ui.activate(s,index);ui.view(s,'THREE_QUARTER');s.gaf_loop=False
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.show_region_ui=True
proof={'separate_gui_process':True,'candidate':name,'fps':s.render.fps,'range':[s.frame_start,s.frame_end],
 'continuous_source_take':True,'loop_disabled':True,'no_blend_save':True,'frames_seen':[]}
deadline=time.monotonic()+55;phase=['first'];started=[False]
def frame_changed(scene,*args):
 if phase[0]=='first':proof['frames_seen'].append(scene.frame_current)
bpy.app.handlers.frame_change_post.append(frame_changed)
def toggle():
 win=bpy.context.window;area=next(a for a in win.screen.areas if a.type=='VIEW_3D')
 with bpy.context.temp_override(window=win,screen=win.screen,area=area):bpy.ops.gaf.play_pause()
def finish(ok,error=None):
 if bpy.context.screen.is_animation_playing:toggle()
 proof['passed']=ok;proof['error']=error;proof['paused']=not bpy.context.screen.is_animation_playing
 ui.activate(s,index);s.frame_set(76)
 try:bpy.ops.screen.screenshot(filepath=str(OUT/'blender_gui_review.png'))
 except Exception as e:proof['screenshot_error']=str(e)
 proof['source_action_sha256']=ui.action_signature(bpy.data.actions[name])
 proof['maximum_frame_seen']=max(proof['frames_seen'],default=0)
 proof['observed_frame_count']=len(set(proof.pop('frames_seen')))
 for folder in [OUT,STAGE]:(folder/'gui_playback_validation.json').write_text(json.dumps(proof,indent=2))
 if frame_changed in bpy.app.handlers.frame_change_post:bpy.app.handlers.frame_change_post.remove(frame_changed)
 print('NATIVE_SOURCE_RUN_REVIEW',json.dumps(proof),flush=True)
def tick():
 try:
  if not started[0]:toggle();started[0]=True;return .2
  if time.monotonic()>deadline:finish(False,'Native playback did not complete the six-second take within55 seconds');return None
  if phase[0]=='first' and s.frame_current>=s.frame_end and not bpy.context.screen.is_animation_playing:
   proof['automatic_end_stop_pass']=True
   phase[0]='restart';toggle();proof['replay_returns_to_start_pass']=s.frame_current==1
   assert proof['replay_returns_to_start_pass'];return .2
  if phase[0]=='restart' and s.frame_current>=10:
   toggle();proof['pause_pass']=not bpy.context.screen.is_animation_playing
   assert proof['pause_pass'];finish(True);return None
  return .2
 except Exception as e:finish(False,str(e));return None
bpy.app.timers.register(tick,first_interval=3)
