"""Fresh GUI: one-shot end, restart, looping wrap, pause and reset."""
import bpy,json,time
from pathlib import Path
O=Path(__file__).resolve().parent;s=bpy.context.scene;win=bpy.context.window;area=next(a for a in win.screen.areas if a.type=='VIEW_3D');region=next(r for r in area.regions if r.type=='WINDOW')
assert s.gaf_active_index==14 and [s.frame_start,s.frame_end,s.render.fps]==[1,93,30] and not s.gaf_loop
e=json.loads(s.gaf_clips[14].entry_json);state={'passed':False,'fresh_reopen':True,'source_sha256':e['source_sha256'],'action_sha256':e['action_sha256'],'samples':[],'stage':'one_shot','observed_wraps':0};start=time.perf_counter()
with bpy.context.temp_override(window=win,screen=win.screen,area=area,region=region):bpy.ops.gaf.restart();bpy.ops.gaf.play_pause()
def tick(state=state,start=start,s=s,win=win,area=area,region=region,O=O,time=time,json=json,bpy=bpy):
 elapsed=time.perf_counter()-start;f=s.frame_current;playing=win.screen.is_animation_playing
 state['samples'].append({'t_s':elapsed,'frame':f,'playing':playing,'stage':state['stage']})
 if state['stage']=='one_shot' and f==93 and not playing:
  state['one_shot_stopped_at_end']=True;s.gaf_loop=True
  with bpy.context.temp_override(window=win,screen=win.screen,area=area,region=region):bpy.ops.gaf.restart();bpy.ops.gaf.play_pause()
  state['stage']='loop';state['previous_frame']=1
 elif state['stage']=='loop':
  if f<state['previous_frame']:state['observed_wraps']+=1
  state['previous_frame']=f
  if state['observed_wraps']>=1:
   with bpy.context.temp_override(window=win,screen=win.screen,area=area,region=region):bpy.ops.gaf.play_pause();bpy.ops.gaf.restart()
   s.gaf_loop=False;state['paused_restarted']=not win.screen.is_animation_playing and s.frame_current==1;state['passed']=state['one_shot_stopped_at_end'] and state['paused_restarted'];state['elapsed_s']=elapsed;(O/'gui_playback.json').write_text(json.dumps(state,indent=2));return None
 if elapsed>25:
  if playing:
   with bpy.context.temp_override(window=win,screen=win.screen,area=area,region=region):bpy.ops.gaf.play_pause()
  s.gaf_loop=False;(O/'gui_playback.json').write_text(json.dumps(state,indent=2));return None
 return .03
bpy.app.timers.register(tick,first_interval=.03)
