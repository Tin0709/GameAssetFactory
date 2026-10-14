"""Check native playback in a separate GUI process; never save any .blend."""
import bpy,json,sys,time,hashlib
from pathlib import Path
STAGE=Path(__file__).resolve().parent
state=json.loads((STAGE/'preservation_before.json').read_text());ROOT=Path(state['project']);OUT=Path(state['package_destination'])
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
ui.register();ui.loaded(None)
s=bpy.context.scene;name=state['action'];index=next(i for i,c in enumerate(s.gaf_clips)if c.action==name)
s.gaf_active_index=index;ui.activate(s,index);ui.view(s,'THREE_QUARTER');s.gaf_loop=True
proof={'separate_gui_process':True,'candidate':name,'fps':s.render.fps,'range':[s.frame_start,s.frame_end],'wraps':0,'restart_wraps':0,'no_blend_save':True}
deadline=time.monotonic()+55;last=[None];phase=['first'];started=[False]
def frame_changed(scene,*args):
 f=scene.frame_current
 if last[0] is not None and f<last[0]:proof['wraps'if phase[0]=='first'else'restart_wraps']+=1
 last[0]=f
bpy.app.handlers.frame_change_post.append(frame_changed)
def toggle():
 win=bpy.context.window;area=next(a for a in win.screen.areas if a.type=='VIEW_3D')
 with bpy.context.temp_override(window=win,screen=win.screen,area=area):bpy.ops.screen.animation_play()
def finish(ok,error=None):
 if bpy.context.screen.is_animation_playing:toggle()
 proof['passed']=ok;proof['error']=error;proof['paused']=not bpy.context.screen.is_animation_playing
 ui.activate(s,index);s.frame_set(11)
 try:bpy.ops.screen.screenshot(filepath=str(OUT/'blender_gui_review.png'))
 except Exception as e:proof['screenshot_error']=str(e)
 proof['source_action_sha256']=ui.action_signature(bpy.data.actions[name])
 (OUT/'gui_playback_validation.json').write_text(json.dumps(proof,indent=2));(STAGE/'gui_playback_validation.json').write_text(json.dumps(proof,indent=2))
 if frame_changed in bpy.app.handlers.frame_change_post:bpy.app.handlers.frame_change_post.remove(frame_changed)
 print('NATIVE_GUI_REVIEW',json.dumps(proof),flush=True)
def tick():
 try:
  if not started[0]:toggle();started[0]=True;return .25
  if time.monotonic()>deadline:finish(False,'Native playback did not reach wrap target within55 seconds');return None
  if phase[0]=='first'and proof['wraps']>=3:
   toggle();proof['pause_pass']=not bpy.context.screen.is_animation_playing
   ui.activate(s,index);proof['restart_frame_pass']=s.frame_current==1
   last[0]=None;phase[0]='restart';toggle();return .25
  if phase[0]=='restart'and proof['restart_wraps']>=1:finish(True);return None
  return .25
 except Exception as e:finish(False,str(e));return None
bpy.app.timers.register(tick,first_interval=3)
