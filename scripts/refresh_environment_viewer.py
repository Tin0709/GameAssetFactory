"""Run in the current Blender console to refresh this SAME window safely."""
import bpy,sys,importlib,time,json
from pathlib import Path
_R=Path.home()/'Desktop/Game Dev/GameAssetFactory';_P=_R/'blender/environment/studies/dungeons_ground_style_v2/dungeons_ground_style_v2.blend'
assert Path(bpy.data.filepath).name==_P.name,'Only the environment viewer is supported; other libraries are not touched.'
_E=_R/'.validation/grass_md2_single_window_v001';_E.mkdir(parents=True,exist_ok=True)
_recovery=_E/('live_before_refresh_'+str(time.time_ns())+'.blend')
# Preserve the exact loaded state (including unsaved changes) before reloading.
bpy.ops.wm.save_as_mainfile(filepath=str(_recovery),copy=True,relative_remap=False,compress=True)
bpy.ops.wm.open_mainfile(filepath=str(_P),load_ui=True)
sys.path.insert(0,str(_P.parent/'tall_grass_md2_v001'));_ui=importlib.import_module('grass_library_ui');_ui.register();_ui.loaded(None)
print('REFRESHED_SAME_ENVIRONMENT_WINDOW',str(_recovery),flush=True)
