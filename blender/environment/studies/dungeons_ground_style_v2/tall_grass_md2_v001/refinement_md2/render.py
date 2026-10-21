import bpy,json,sys
from pathlib import Path
D=Path(__file__).resolve().parent;T=D.parent;P=T.parent;R=T.parents[4];sys.path[:0]=[str(T),str(P)];import grass_library_ui as ui
path=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else P/'dungeons_ground_style_v2.blend';bpy.ops.wm.open_mainfile(filepath=str(path));s=bpy.context.scene
s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';out=D/'review';out.mkdir(exist_ok=True)
root=bpy.data.collections['MD2_Tall_Grass_v001_PENDING']
for key,name in [('All','All_Grass'),('T:Soft Meadow','Tall_A'),('T:Grouped','Meadow_Patch'),('T:Compare','Compare'),('T:Side','Side')]:
 ui.select(bpy.context,key)
 for layer in s.view_layers:layer.use=layer==bpy.context.view_layer
 if key.startswith('T:'):
  visible=ui.tall.visible_names(key[2:])
  for o in list(root.all_objects):o.hide_render=o.name not in visible
 s.camera=next(a.spaces.active.camera for a in bpy.context.screen.areas if a.type=='VIEW_3D');s.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);print('RENDERED',name,flush=True)
