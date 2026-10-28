import bpy,runpy,json,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
runpy.run_path(str(ROOT/'scripts/load_showcase_ui.py'),run_name='__main__')
import gaf_animation_library as ui
ui.open_review_sequence(bpy.context,'hybrid_run_comparison_v001');s=bpy.context.scene;s.gaf_loop=True
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  space=area.spaces.active;space.show_region_ui=True;space.shading.type='MATERIAL';space.shading.use_scene_lights=True;space.shading.use_scene_world=True;space.overlay.show_overlays=False;space.region_3d.view_perspective='CAMERA'
start=time.perf_counter();samples=[]
def observe():
 samples.append({'elapsed':time.perf_counter()-start,'frame':s.frame_current,'playing':bpy.context.screen.is_animation_playing,'scene':s.name,'sync':s.sync_mode,'actors':[(o.name,o.animation_data.action.name)for o in s.objects if o.type=='ARMATURE']})
 (HERE/'gui_playback.json').write_text(json.dumps(samples,indent=2))
 return 2.5 if len(samples)<3 else None
bpy.ops.screen.animation_play();bpy.app.timers.register(observe,first_interval=2.5)
