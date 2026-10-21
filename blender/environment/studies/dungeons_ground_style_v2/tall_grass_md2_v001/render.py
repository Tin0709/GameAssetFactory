"""Preview saved candidate/current library without saving presentation settings."""
import bpy,json,sys
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));import tall_review_ui as ui
path=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else D.parent/'dungeons_ground_style_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.context.scene;info=json.loads(scene['md2_tall_review'])
for layer in scene.view_layers:layer.use=layer.name==info['layer']
bpy.context.window.view_layer=scene.view_layers[info['layer']]
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
for key in ['Overview','Soft Meadow','Open Fan','Meadow Cluster','Grouped','Compare','Gameplay','Side','Opposite']:
 visible=ui.visible_names(key)
 for obj in list(bpy.data.collections['MD2_Tall_Grass_v001_PENDING'].all_objects):obj.hide_render=obj.name not in visible
 bpy.context.view_layer.update()
 assert all(o.hide_render==(o.name not in visible) for o in bpy.data.collections['MD2_Tall_Grass_v001_PENDING'].all_objects)
 scene.camera=bpy.data.objects[info['cameras'][key]];scene.render.filepath=str(D/'review'/(key.replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True);print('RENDERED',key,flush=True)
