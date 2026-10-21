"""Original-speed review renders from the native wind candidate; never save source."""
import bpy
import json
import os
import sys
import time
from pathlib import Path

D = Path(__file__).resolve().parent; P = D.parent; R = D.parents[4]
E = R / '.validation/md2_grass_wind_v001'
sys.path[:0] = [str(D), str(P / 'tall_grass_md2_v001')]
import grass_library_ui
import wind_review_ui as ui
bpy.ops.wm.open_mainfile(filepath=str(E / 'dungeons_ground_style_v2.blend'))
grass_library_ui.register(); scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'; scene.render.resolution_percentage = 100
scene.render.resolution_x = 960; scene.render.resolution_y = 600
scene.render.image_settings.file_format = 'PNG'; scene.render.film_transparent = False
scene.render.use_file_extension = True
if hasattr(scene, 'eevee'):
    if hasattr(scene.eevee, 'taa_render_samples'): scene.eevee.taa_render_samples = 16
for layer in scene.view_layers: layer.use = layer.name == ui.record()['layer']
mode = os.environ.get('MD2_WIND_RENDER', 'stills')
outputs = D / 'review'; outputs.mkdir(exist_ok=True)
if mode == 'stills':
    frames = [('Field', 1), ('Field', 240), ('Close', 240), ('Compare', 240), ('Tall_Grass_MD2_v001_A',240), ('Short_Grass_MD2_v001_A',240)]
    records = []
    for key, frame in frames:
        ui.select(bpy.context,key); scene.camera = bpy.data.objects[ui.record()['cameras'][key]]; scene.frame_set(frame)
        scene.render.filepath = str(outputs / ('Still_%s_%03d.png' % (key,frame)))
        start = time.perf_counter(); bpy.ops.render.render(write_still=True)
        records.append({'view':key,'frame':frame,'render_seconds':time.perf_counter()-start})
    (E / 'render_times.json').write_text(json.dumps(records,indent=2)+'\n')
else:
    assert mode in ['Field','Close']
    ui.select(bpy.context,mode); scene.camera = bpy.data.objects[ui.record()['cameras'][mode]]
    directory = E / ('frames_' + mode.lower()); directory.mkdir(exist_ok=True)
    scene.render.resolution_x = 800; scene.render.resolution_y = 500
    if hasattr(scene, 'eevee') and hasattr(scene.eevee, 'taa_render_samples'): scene.eevee.taa_render_samples = 8
    start = time.perf_counter()
    for frame in range(1,481):
        scene.frame_set(frame); scene.render.filepath = str(directory / ('%04d.png' % frame))
        bpy.ops.render.render(write_still=True)
        if frame % 48 == 0: print('WIND_RENDER_PROGRESS',mode,frame,round(time.perf_counter()-start,2),flush=True)
    print('WIND_RENDER_DONE',mode,round(time.perf_counter()-start,2),flush=True)
