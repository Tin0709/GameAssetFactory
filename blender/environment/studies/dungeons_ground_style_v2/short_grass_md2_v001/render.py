"""Actual saved-source previews; temporary render settings, never save the library."""
import bpy,json,sys
from pathlib import Path
D=Path(__file__).resolve().parent;bpy.ops.wm.open_mainfile(filepath=str(D.parent/'dungeons_ground_style_v2.blend'))
scene=bpy.context.scene;info=json.loads(scene['md2_review']);out=D/'review';out.mkdir(exist_ok=True)
for layer in scene.view_layers:layer.use=layer.name==info['layer']
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
for key in ['Overview','Low Cushion','Grouped','Gameplay','Compare','Opposite']:
 scene.camera=bpy.data.objects[info['cameras'][key]];scene.render.filepath=str(out/(key.replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True)
 print('RENDERED',key,flush=True)
