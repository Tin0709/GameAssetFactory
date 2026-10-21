"""Local controls for the same environment viewer; no geometry/import/rebuild."""
from pathlib import Path
import bpy,json
from bpy.app.handlers import persistent
LIB='dungeons_ground_style_v2.blend'
def record():return json.loads(bpy.context.scene.get('md2_review','{}'))
def select(context,key):
 info=record();assert info and Path(bpy.data.filepath).name==LIB
 context.window.view_layer=context.scene.view_layers[info['old_layer'] if key=='Original' else info['layer']]
 camera=bpy.data.objects[info['original_camera'] if key=='Original' else info['cameras'][key]]
 for area in context.screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.use_local_camera=True;space.camera=camera;space.region_3d.view_perspective='CAMERA';space.region_3d.view_camera_zoom=0;space.overlay.show_overlays=False;space.show_region_ui=True;area.tag_redraw()
 context.scene['md2_selected_view']=key
class MD2_OT_view(bpy.types.Operator):
 bl_idname='md2_grass.view';bl_label='Review grass';bl_options={'REGISTER'}
 key:bpy.props.StringProperty()
 def execute(self,context):select(context,self.key);return {'FINISHED'}
class MD2_PT_short_grass(bpy.types.Panel):
 bl_label='Short Grass MD2 — Pending';bl_idname='MD2_PT_short_grass';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Grass MD2'
 @classmethod
 def poll(cls,context):return Path(bpy.data.filepath).name==LIB and 'md2_review' in context.scene
 def draw(self,context):
  layout=self.layout;layout.label(text='SHORT GRASS / Blender review',icon='OUTLINER_OB_GROUP_INSTANCE')
  for key,title in [('Overview','Full review'),('Compare','Beside current grass')]:
   op=layout.operator('md2_grass.view',text=title);op.key=key
  box=layout.box();box.label(text='Individual candidates')
  for key,title in [('Low Cushion','A · Low Cushion'),('Broad Fan','B · Broad Fan'),('Soft Rosette','C · Soft Rosette'),('Uneven Tuft','D · Uneven Tuft'),('Cluster','Dense Cluster')]:
   op=box.operator('md2_grass.view',text=title,icon='MESH_DATA');op.key=key
  row=layout.row(align=True)
  for key in ['Grouped','Gameplay','Opposite']:
   op=row.operator('md2_grass.view',text=key);op.key=key
  op=layout.operator('md2_grass.view',text='Existing environment studies',icon='BACK');op.key='Original'
  layout.label(text='A–D: 28–36 triangles each')
  layout.label(text='16–27 cm · one shared material')
  layout.label(text='Pending · no Godot integration',icon='INFO')
def focus_sidebar():
 for window in bpy.context.window_manager.windows:
  for area in window.screen.areas:
   if area.type!='VIEW_3D':continue
   area.spaces.active.show_region_ui=True
   for region in area.regions:
    if region.type=='UI':
     try:
      with bpy.context.temp_override(window=window,area=area,region=region):region.active_panel_category='Grass MD2'
     except (AttributeError,TypeError,RuntimeError):pass
   area.tag_redraw()
 print('MD2_REVIEW_SIDEBAR_READY',flush=True)
@persistent
def loaded(_):
 if Path(bpy.data.filepath).name==LIB and 'md2_review' in bpy.context.scene and not bpy.app.background:select(bpy.context,'Overview')
 if not bpy.app.background and not bpy.app.timers.is_registered(focus_sidebar):bpy.app.timers.register(focus_sidebar,first_interval=.3)
def register():
 for cls in [MD2_OT_view,MD2_PT_short_grass]:
  if not hasattr(bpy.types,cls.__name__):bpy.utils.register_class(cls)
 if loaded not in bpy.app.handlers.load_post:bpy.app.handlers.load_post.append(loaded)
