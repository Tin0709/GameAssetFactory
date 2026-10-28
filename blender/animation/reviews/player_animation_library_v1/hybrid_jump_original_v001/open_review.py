import bpy,runpy,json,time
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parents[4]
runpy.run_path(str(R/'scripts/load_showcase_ui.py'),run_name='__main__');import gaf_animation_library as ui
ui.open_review_sequence(bpy.context,'hybrid_jump_original_v001');s=bpy.context.scene;s.gaf_loop=True;ui.view(s,'THREE_QUARTER')
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  sp=area.spaces.active;sp.show_region_ui=True;sp.shading.type='MATERIAL';sp.shading.use_scene_lights=True;sp.shading.use_scene_world=True;sp.overlay.show_overlays=False;sp.region_3d.view_perspective='CAMERA'
samples=[];start=time.perf_counter()
def observe():
 samples.append({'elapsed_s':time.perf_counter()-start,'frame':s.frame_current,'playing':bpy.context.screen.is_animation_playing,'scene':s.name,'sync_mode':s.sync_mode})
 (H/'gui_playback.json').write_text(json.dumps(samples,indent=2),encoding='utf8')
 return .7 if len(samples)<5 else None
bpy.ops.screen.animation_play();bpy.app.timers.register(observe,first_interval=2.5)
