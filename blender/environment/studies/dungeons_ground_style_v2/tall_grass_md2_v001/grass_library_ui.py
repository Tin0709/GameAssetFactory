"""One shared Grass MD2 panel for the saved short and tall research assets."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
from bpy.app.handlers import persistent
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));import tall_review_ui as tall
short=tall.short_ui;LIB='dungeons_ground_style_v2.blend'
def record():return json.loads(bpy.context.scene.get('md2_grass_library','{}'))
def tall_closeup(context,key):
 # Review cameras are created/reused in memory; source meshes and saved cameras
 # are never moved or rescaled. Fit the complete tuft, including its roots.
 tall.select(context,key);context.view_layer.update()
 info=tall.record();obj=next(bpy.data.objects[n] for n in info['masters'] if bpy.data.objects[n]['variant']==key)
 normal=bpy.data.objects[info['cameras'][key]];name='MD2_Tall_Closeup_'+obj.name
 camera=bpy.data.objects.get(name)
 if camera is None:
  data=normal.data.copy();data.name=name;camera=bpy.data.objects.new(name,data)
  bpy.data.collections['04_Tall_MD2_Review_Studio'].objects.link(camera);camera['md2_tall_closeup']=True
 rotation=normal.rotation_euler.to_matrix();right=rotation.col[0];up=rotation.col[1]
 points=[obj.matrix_world@v.co for v in obj.data.vertices]
 bounds=[(min(p.dot(axis) for p in points),max(p.dot(axis) for p in points)) for axis in [right,up]]
 center=sum(points,Vector())/len(points)
 center+=right*((sum(bounds[0])/2)-center.dot(right))
 center+=up*((sum(bounds[1])/2)-center.dot(up))
 render=context.scene.render;aspect=(render.resolution_x*render.pixel_aspect_x)/(render.resolution_y*render.pixel_aspect_y)
 camera.rotation_euler=normal.rotation_euler.copy();camera.location=center+rotation.col[2]*3.
 camera.data.type='ORTHO';camera.data.sensor_fit='HORIZONTAL'
 camera.data.ortho_scale=max(bounds[0][1]-bounds[0][0],(bounds[1][1]-bounds[1][0])*aspect)*1.08
 for area in context.screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.camera=camera;area.spaces.active.region_3d.view_perspective='CAMERA';area.tag_redraw()
 context.view_layer.update()
 return camera
def select(context,key):
 if 'md2_interaction_review' in context.scene:
  import interaction_review_ui
  interaction_review_ui.leave(context)
 # Restore the pre-wind timeline when returning to any static review route.
 if 'md2_wind_review' in context.scene:
  import wind_review_ui
  wind_review_ui.leave(context)
 info=record();assert info and Path(bpy.data.filepath).name==LIB
 layer=context.scene.view_layers[info['layer']]
 if key=='All' or key.startswith('S:'):
  context.window.view_layer=layer
  for o in list(bpy.data.collections[info['combined_collection']].all_objects):o.hide_set(key!='All',view_layer=layer)
 if key=='All':
  for a in context.screen.areas:
   if a.type=='VIEW_3D':
    v=a.spaces.active;v.use_local_camera=True;v.camera=bpy.data.objects[info['all_camera']];v.region_3d.view_perspective='CAMERA';v.region_3d.view_camera_zoom=0;v.show_region_ui=True;v.overlay.show_overlays=False;a.tag_redraw()
 elif key.startswith('S:'):short.select(context,key[2:])
 elif key.startswith('TC:'):tall_closeup(context,key[3:])
 elif key.startswith('T:'):tall.select(context,key[2:])
 else:raise ValueError(key)
 context.scene['md2_grass_library_selected']=key
class MD2_OT_grass_library_view(bpy.types.Operator):
 bl_idname='md2_grass_library.view';bl_label='Select grass review';bl_options={'REGISTER'}
 key:bpy.props.StringProperty()
 def execute(self,context):select(context,self.key);return {'FINISHED'}
class MD2_PT_grass_library(bpy.types.Panel):
 bl_label='Grass MD2 — Short + Tall';bl_idname='MD2_PT_grass_library';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Grass MD2'
 @classmethod
 def poll(cls,context):return Path(bpy.data.filepath).name==LIB and 'md2_grass_library' in context.scene
 def draw(self,context):
  l=self.layout
  def button(layout,key,text,icon='NONE'):layout.operator('md2_grass_library.view',text=text,icon=icon).key=key
  button(l,'All','ALL GRASS · same review', 'OUTLINER_OB_GROUP_INSTANCE')
  r=l.row(align=True);button(r,'S:Overview','Short');button(r,'T:Overview','Tall');button(r,'T:Compare','Compare')
  b=l.box();b.label(text='SHORT GRASS · 0.5 block')
  for pair in [[('Low Cushion','A · Cushion'),('Broad Fan','B · Fan')],[('Soft Rosette','C · Rosette'),('Uneven Tuft','D · Uneven')]]:
   r=b.row(align=True)
   for key,title in pair:button(r,'S:'+key,title,'MESH_DATA')
  button(b,'S:Cluster','Short · Dense Cluster')
  b=l.box();b.label(text='TALL GRASS · CẬN CẢNH',icon='VIEWZOOM')
  for key,title in [('Soft Meadow','A · Soft Meadow'),('Open Fan','B · Open Fan'),('Low Sweep','C · Low Sweep'),('Uneven Crown','D · Uneven Crown'),('Meadow Cluster','Cluster 1 · Meadow'),('Upright Cluster','Cluster 2 · Upright')]:
   button(b,'TC:'+key,title,'MESH_DATA')
  r=l.row(align=True);button(r,'T:Grouped','Mixed patch');button(r,'T:Gameplay','Gameplay')
  r=l.row(align=True);button(r,'T:Side','Side');button(r,'T:Opposite','Opposite')
  button(l,'S:Original','Existing environment studies','BACK')
  l.label(text='Tall: 0.72–0.94 block')
  l.label(text='Pending · Blender review only',icon='INFO')
@persistent
def loaded(_):
 if not bpy.app.background and Path(bpy.data.filepath).name==LIB and record():
  if 'md2_interaction_review' in bpy.context.scene:
   import interaction_review_ui
   interaction_review_ui.select(bpy.context)
   if not bpy.app.timers.is_registered(interaction_review_ui.start_preview):bpy.app.timers.register(interaction_review_ui.start_preview,first_interval=.9)
  elif 'md2_wind_review' in bpy.context.scene:
   import wind_review_ui
   wind_review_ui.select(bpy.context,'Field')
   if not bpy.app.timers.is_registered(wind_review_ui.start_preview):bpy.app.timers.register(wind_review_ui.start_preview,first_interval=.9)
  else:select(bpy.context,'All')
  if not bpy.app.timers.is_registered(short.focus_sidebar):bpy.app.timers.register(short.focus_sidebar,first_interval=.3)
def register():
 tall.register()
 for old in [short.loaded,tall.loaded]:
  if old in bpy.app.handlers.load_post:bpy.app.handlers.load_post.remove(old)
 for name in ['MD2_PT_short_grass','MD2_PT_tall_grass']:
  cls=getattr(bpy.types,name,None)
  if cls:bpy.utils.unregister_class(cls)
 for cls in [MD2_OT_grass_library_view,MD2_PT_grass_library]:
  if not hasattr(bpy.types,cls.__name__):bpy.utils.register_class(cls)
 wind_path=str(D.parent/'grass_wind_md2_v001')
 if wind_path not in sys.path:sys.path.insert(0,wind_path)
 import wind_review_ui
 wind_review_ui.register()
 interaction_path=str(D.parent/'grass_interaction_md2_v001')
 if interaction_path not in sys.path:sys.path.insert(0,interaction_path)
 import interaction_review_ui
 interaction_review_ui.register()
 if loaded not in bpy.app.handlers.load_post:bpy.app.handlers.load_post.append(loaded)
