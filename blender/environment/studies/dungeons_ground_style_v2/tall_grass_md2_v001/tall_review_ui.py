"""Tall and short candidates share the established Grass MD2 viewer tab."""
from pathlib import Path
import bpy,json,sys
from bpy.app.handlers import persistent
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D.parent/'short_grass_md2_v001'));import review_ui as short_ui
LIB='dungeons_ground_style_v2.blend'
def record():return json.loads(bpy.context.scene.get('md2_tall_review','{}'))
def select(context,key):
 info=record();assert info and Path(bpy.data.filepath).name==LIB
 if key in ['Short','Original']:short_ui.select(context,'Overview' if key=='Short' else 'Original')
 else:
  context.window.view_layer=context.scene.view_layers[info['layer']]
  for area in context.screen.areas:
   if area.type=='VIEW_3D':
    s=area.spaces.active;s.use_local_camera=True;s.camera=bpy.data.objects[info['cameras'][key]];s.region_3d.view_perspective='CAMERA';s.region_3d.view_camera_zoom=0;s.show_region_ui=True;s.overlay.show_overlays=False;area.tag_redraw()
 context.scene['md2_tall_selected_view']=key
class MD2_OT_tall_view(bpy.types.Operator):
 bl_idname='md2_tall_grass.view';bl_label='Review tall grass';bl_options={'REGISTER'}
 key:bpy.props.StringProperty()
 def execute(self,context):select(context,self.key);return {'FINISHED'}
class MD2_PT_tall_grass(bpy.types.Panel):
 bl_label='Tall Grass MD2 — Pending';bl_idname='MD2_PT_tall_grass';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Grass MD2';bl_order=-10
 @classmethod
 def poll(cls,context):return Path(bpy.data.filepath).name==LIB and 'md2_tall_review' in context.scene
 def draw(self,context):
  l=self.layout;l.label(text='TALL GRASS / Blender review',icon='OUTLINER_OB_GROUP_INSTANCE')
  for key,title in [('Overview','Tall grass overview'),('Compare','Compare short / tall / existing')]:l.operator('md2_tall_grass.view',text=title).key=key
  box=l.box();box.label(text='Individual tall candidates')
  for key,title in [('Soft Meadow','A · Soft Meadow'),('Open Fan','B · Open Fan'),('Low Sweep','C · Low Sweep'),('Uneven Crown','D · Uneven Crown'),('Meadow Cluster','Cluster 1 · Meadow'),('Upright Cluster','Cluster 2 · Upright')]:box.operator('md2_tall_grass.view',text=title,icon='MESH_DATA').key=key
  row=l.row(align=True)
  for key in ['Grouped','Gameplay']:row.operator('md2_tall_grass.view',text=key).key=key
  row=l.row(align=True)
  for key in ['Side','Opposite']:row.operator('md2_tall_grass.view',text=key).key=key
  l.operator('md2_tall_grass.view',text='Short grass overview · 0.5 block').key='Short'
  l.operator('md2_tall_grass.view',text='Existing environment studies',icon='BACK').key='Original'
  l.label(text='Tall: 0.72–0.94 m · one material')
  l.label(text='A–D: 48–60 triangles each')
  l.label(text='Pending · no Godot integration',icon='INFO')
@persistent
def loaded(_):
 if not bpy.app.background and Path(bpy.data.filepath).name==LIB and record():
  select(bpy.context,'Overview')
  if not bpy.app.timers.is_registered(short_ui.focus_sidebar):bpy.app.timers.register(short_ui.focus_sidebar,first_interval=.3)
def register():
 short_ui.register()
 for cls in [MD2_OT_tall_view,MD2_PT_tall_grass]:
  if not hasattr(bpy.types,cls.__name__):bpy.utils.register_class(cls)
 if loaded not in bpy.app.handlers.load_post:bpy.app.handlers.load_post.append(loaded)
