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
# A second refresh must also replace Python modules cached by the first one.
# Unregister only this environment viewer's known UI classes/handlers.
_modules={'grass_library_ui','tall_review_ui','review_ui','wind_review_ui'}
for _handler in list(bpy.app.handlers.load_post):
 if getattr(_handler,'__module__','') in _modules:bpy.app.handlers.load_post.remove(_handler)
for _name in ['MD2_PT_wind_individual','MD2_PT_wind','MD2_OT_wind_play','MD2_OT_wind_view','MD2_PT_grass_library','MD2_OT_grass_library_view','MD2_PT_tall_grass','MD2_OT_tall_view','MD2_PT_short_grass','MD2_OT_view']:
 _class=getattr(bpy.types,_name,None)
 if _class:bpy.utils.unregister_class(_class)
sys.path[:0]=[str(_P.parent/'short_grass_md2_v001'),str(_P.parent/'tall_grass_md2_v001'),str(_P.parent/'grass_wind_md2_v001')]
importlib.invalidate_caches()
for _name in ['review_ui','tall_review_ui','wind_review_ui','grass_library_ui']:
 if _name in sys.modules:importlib.reload(sys.modules[_name])
_ui=importlib.import_module('grass_library_ui');_ui.register();_ui.loaded(None)
print('REFRESHED_SAME_ENVIRONMENT_WINDOW',str(_recovery),flush=True)
