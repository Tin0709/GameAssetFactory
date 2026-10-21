"""Preview saved candidate/current library without saving presentation settings."""
import bpy,json,sys
from pathlib import Path
D=Path(__file__).resolve().parent
path=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else D.parent/'dungeons_ground_style_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.context.scene;info=json.loads(scene['md2_tall_review'])
for layer in scene.view_layers:layer.use=layer.name==info['layer']
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
for key in ['Overview','Soft Meadow','Open Fan','Meadow Cluster','Grouped','Compare','Gameplay','Side','Opposite']:
 scene.camera=bpy.data.objects[info['cameras'][key]];scene.render.filepath=str(D/'review'/(key.replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True);print('RENDERED',key,flush=True)
