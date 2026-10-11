"""Observe actual GUI playback, three wraps, pause and restart after reopening."""
import bpy,json,time
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene;win=bpy.context.window
area=next(a for a in win.screen.areas if a.type=='VIEW_3D');region=next(r for r in area.regions if r.type=='WINDOW')
assert s.gaf_active_index==11 and [s.frame_start,s.frame_end,s.render.fps]==[1,36,30] and s.gaf_loop
e=json.loads(s.gaf_clips[11].entry_json);state={'passed':False,'fresh_reopen':True,'active_action':e['action'],'source_sha256':e['source_sha256'],'action_sha256':e['action_sha256'],'range':[1,36],'fps':30,'period_s':1.2,'loop':True,'observed_wraps':0,'samples':[]};start=time.perf_counter()
with bpy.context.temp_override(window=win,screen=win.screen,area=area,region=region):
 if win.screen.is_animation_playing:bpy.ops.gaf.play_pause()
 bpy.ops.gaf.restart();bpy.ops.gaf.play_pause()
def tick(state=state,start=start,s=s,win=win,area=area,region=region,OUT=OUT,time=time,json=json,bpy=bpy):
 elapsed=time.perf_counter()-start;f=s.frame_current
 if state['samples'] and f<state['samples'][-1]['frame']:state['observed_wraps']+=1
 state['samples'].append({'t_s':elapsed,'frame':f,'playing':win.screen.is_animation_playing})
 if (state['observed_wraps']>=3 and elapsed>3.65) or elapsed>20:
  with bpy.context.temp_override(window=win,screen=win.screen,area=area,region=region):
   if win.screen.is_animation_playing:bpy.ops.gaf.play_pause()
   bpy.ops.gaf.restart()
  state['elapsed_s']=elapsed;state['paused_restarted']=s.frame_current==1 and not win.screen.is_animation_playing
  state['passed']=state['observed_wraps']>=3 and state['paused_restarted'] and all(x['playing'] for x in state['samples'])
  (OUT/'gui_playback.json').write_text(json.dumps(state,indent=2));return None
 return .03
bpy.app.timers.register(tick,first_interval=.03)
