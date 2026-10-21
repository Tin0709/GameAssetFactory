"""One shared Grass MD2 panel for the saved short and tall research assets."""
import bpy,json,sys
from pathlib import Path
from bpy.app.handlers import persistent
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));import tall_review_ui as tall
short=tall.short_ui;LIB='dungeons_ground_style_v2.blend'
def record():return json.loads(bpy.context.scene.get('md2_grass_library','{}'))
def select(context,key):
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
  b=l.box();b.label(text='TALL GRASS · MD2 meadow')
  for pair in [[('Soft Meadow','A · Meadow'),('Open Fan','B · Open Fan')],[('Low Sweep','C · Low Sweep'),('Uneven Crown','D · Uneven')],[('Meadow Cluster','Cluster 1'),('Upright Cluster','Cluster 2')]]:
   r=b.row(align=True)
   for key,title in pair:button(r,'T:'+key,title,'MESH_DATA')
  r=l.row(align=True);button(r,'T:Grouped','Mixed patch');button(r,'T:Gameplay','Gameplay')
  r=l.row(align=True);button(r,'T:Side','Side');button(r,'T:Opposite','Opposite')
  button(l,'S:Original','Existing environment studies','BACK')
  l.label(text='Tall: 0.72–0.94 block')
  l.label(text='Pending · Blender review only',icon='INFO')
@persistent
def loaded(_):
 if not bpy.app.background and Path(bpy.data.filepath).name==LIB and record():
  select(bpy.context,'All')
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
 if loaded not in bpy.app.handlers.load_post:bpy.app.handlers.load_post.append(loaded)
