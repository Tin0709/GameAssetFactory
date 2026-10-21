"""Actual native candidate, fixed-camera original-speed preview; never saves library."""
import bpy
import json
import os
import sys
import time
from pathlib import Path

D=Path(__file__).resolve().parent;P=D.parent;R=D.parents[4];E=R/'.validation/md2_grass_interaction_v001'
sys.path[:0]=[str(D),str(P/'tall_grass_md2_v001'),str(P/'grass_wind_md2_v001')]
import grass_library_ui
import interaction_review_ui as ui
import runtime
bpy.ops.wm.open_mainfile(filepath=str(E/'dungeons_ground_style_v2.blend'))
grass_library_ui.register();scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_percentage=100
scene.render.resolution_x=960;scene.render.resolution_y=600
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False;scene.render.use_lock_interface=True
if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'):scene.eevee.taa_render_samples=16
for layer in scene.view_layers:layer.use=layer.name==ui.record()['layer']
mode=os.environ.get('MD2_INTERACTION_RENDER','stills');out=D/'review';out.mkdir(exist_ok=True)
ui.select(bpy.context,'Gameplay');scene.camera=bpy.data.objects[ui.record()['cameras']['Gameplay']]
if mode=='stills':
    for seconds in [3.,6.8,9.5,12.,16.,19.]:
        scene.frame_set(round(seconds*24));runtime.update(force=True)
        scene.render.filepath=str(out/('Gameplay_%04d.png'%round(seconds*24)));bpy.ops.render.render(write_still=True)
else:
    directory=E/'frames';directory.mkdir(exist_ok=True)
    scene.render.resolution_x=800;scene.render.resolution_y=500
    if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'):scene.eevee.taa_render_samples=8
    start=time.perf_counter()
    for frame in range(1,481):
        scene.frame_set(frame);runtime.update(force=True);scene.render.filepath=str(directory/('%04d.png'%frame))
        bpy.ops.render.render(write_still=True)
        if frame%48==0:print('INTERACTION_RENDER_PROGRESS',frame,round(time.perf_counter()-start,2),flush=True)
    print('INTERACTION_RENDER_DONE',round(time.perf_counter()-start,2),flush=True)
