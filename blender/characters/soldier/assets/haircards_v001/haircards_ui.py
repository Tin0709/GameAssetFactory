"""Small head-asset controls in the existing SOLDIER Library sidebar."""
import bpy
from bpy.props import EnumProperty,BoolProperty,PointerProperty
from bpy.app.handlers import persistent
GUARD=False
LAYER='Hair & Bandana'
COLS={'hair':'SOLDIER_HairCards_v001_PENDING','band':'SOLDIER_Bandana_2D_v001_PENDING','old':'HC_Original_Hair — archived / unchanged','body':'HC_Character — unchanged body and clothing'}
def scene():return bpy.data.scenes.get('SOLDIER_ASSET_LIBRARY')
def ready():return scene() is not None and LAYER in scene().view_layers
def find(root,name):
 if root.collection.name==name:return root
 for c in root.children:
  found=find(c,name)
  if found:return found
def apply(self,context):
 if GUARD or not ready():return
 s=scene();layer=s.view_layers[LAYER]
 for key,excluded in [('hair',self.style=='ORIGINAL'),('old',self.style!='ORIGINAL'),('band',self.style=='ORIGINAL' or not self.bandana),('body',self.preview!='CHARACTER')]:
  item=find(layer.layer_collection,COLS[key]);item.exclude=excluded
 for name in ['style','bandana','preview','closeup']:s['hc_'+name]=getattr(self,name)
 camera(context,s.get('hc_camera','ThreeQuarter'))
 for area in context.window.screen.areas:area.tag_redraw()
def show(context):
 s=scene();context.window.scene=s;context.window.view_layer=s.view_layers[LAYER]
 for layer in s.view_layers:layer.use=layer==context.window.view_layer
 for area in context.window.screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.show_region_ui=True;area.spaces.active.use_local_camera=False;area.spaces.active.region_3d.view_perspective='CAMERA';area.tag_redraw()
 return s
def camera(context,direction):
 if not ready():return
 s=scene();s['hc_camera']=direction;p=s.soldier_hair
 old={'ThreeQuarter':'Front_3Q','Side':'Left_Side','BackThreeQuarter':'Back_3Q','OtherSide':'Right_Side'}
 name='HC_'+direction if p.closeup or p.preview!='CHARACTER' else old.get(direction,direction)
 s.camera=bpy.data.objects[name]
def preview_changed(self,context):
 global GUARD
 if GUARD:return
 GUARD=True
 if self.preview!='CHARACTER':self.style='CARDS';self.bandana=self.preview=='HAIR_BANDANA'
 GUARD=False;apply(self,context)
def bandana_changed(self,context):
 global GUARD
 if GUARD:return
 GUARD=True
 if self.preview!='CHARACTER':self.preview='HAIR_BANDANA' if self.bandana else 'HAIR_ONLY'
 GUARD=False;apply(self,context)
def style_changed(self,context):
 global GUARD
 if GUARD:return
 GUARD=True
 if self.style=='ORIGINAL':
  self.bandana=False
  if self.preview=='HAIR_BANDANA':self.preview='HAIR_ONLY'
 GUARD=False;apply(self,context)
class HC_Settings(bpy.types.PropertyGroup):
 style:EnumProperty(name='Hair',items=[('ORIGINAL','Original Hair','Preserved chunky voxel hairstyle'),('CARDS','2D Hair','Thin layered pixel cards')],default='CARDS',update=style_changed)
 bandana:BoolProperty(name='Show Bandana',default=True,update=bandana_changed)
 preview:EnumProperty(name='Preview',items=[('CHARACTER','On Soldier','The actual unchanged Soldier'),('HAIR_ONLY','Hair only','Isolated flat hair cards'),('HAIR_BANDANA','Hair + Bandana','Isolated layered head assets')],default='CHARACTER',update=preview_changed)
 closeup:BoolProperty(name='Close-up',default=True,update=apply)
class HC_OT_open(bpy.types.Operator):
 bl_idname='soldier_hair.open';bl_label='2D Hair & Bandana'
 def execute(self,context):
  s=show(context);apply(s.soldier_hair,context);return {'FINISHED'}
class HC_OT_compare(bpy.types.Operator):
 bl_idname='soldier_hair.compare';bl_label='Hair comparison'
 variant:EnumProperty(items=[('ORIGINAL','Original',''),('HAIR','2D Hair',''),('BANDANA','2D + Bandana','')])
 def execute(self,context):
  global GUARD
  s=show(context);p=s.soldier_hair;GUARD=True;p.preview='CHARACTER';p.style='ORIGINAL' if self.variant=='ORIGINAL' else 'CARDS';p.bandana=self.variant=='BANDANA';GUARD=False;apply(p,context);return {'FINISHED'}
class HC_OT_isolate(bpy.types.Operator):
 bl_idname='soldier_hair.isolate';bl_label='Isolated head assets'
 bandana:BoolProperty(default=False)
 def execute(self,context):
  global GUARD
  s=show(context);p=s.soldier_hair;GUARD=True;p.style='CARDS';p.bandana=self.bandana;p.preview='HAIR_BANDANA' if self.bandana else 'HAIR_ONLY';GUARD=False;apply(p,context);return {'FINISHED'}
class HC_OT_view(bpy.types.Operator):
 bl_idname='soldier_hair.view';bl_label='Head review view'
 direction:EnumProperty(items=[(n,n,'') for n in ['Front','ThreeQuarter','Side','Back','BackThreeQuarter','OtherSide']])
 def execute(self,context):show(context);camera(context,self.direction);return {'FINISHED'}
class HC_PT_hair(bpy.types.Panel):
 bl_label='2D Hair & Bandana · Pending';bl_idname='HC_PT_hair';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='SOLDIER Library';bl_parent_id='SOLDIER_PT_library'
 @classmethod
 def poll(cls,context):return ready() and context.scene==scene() and context.view_layer.name==LAYER
 def draw(self,context):
  l=self.layout;p=scene().soldier_hair
  l.label(text='SOLDIER_HairCards_v001 · Pending',icon='OUTLINER_OB_MESH');l.label(text='SOLDIER_Bandana_2D_v001 · Pending')
  row=l.row(align=True)
  for key,label in [('ORIGINAL','Original'),('HAIR','2D Hair'),('BANDANA','2D + Bandana')]:row.operator('soldier_hair.compare',text=label).variant=key
  l.prop(p,'style',expand=True);row=l.row();row.enabled=p.style=='CARDS';row.prop(p,'bandana')
  l.separator();l.prop(p,'preview',text='Preview')
  row=l.row(align=True);row.operator('soldier_hair.isolate',text='Hair only').bandana=False;row.operator('soldier_hair.isolate',text='Hair + Bandana').bandana=True
  l.prop(p,'closeup',toggle=True)
  for pair in [[('Front','Front'),('3/4','ThreeQuarter'),('Side','Side')],[('Back','Back'),('Back 3/4','BackThreeQuarter'),('Other side','OtherSide')]]:
   row=l.row(align=True)
   for label,direction in pair:row.operator('soldier_hair.view',text=label).direction=direction
  l.separator();l.label(text='20 flat hair cards · 14 bandana cards',icon='INFO');l.label(text='Original hair preserved · Blender only')
@persistent
def loaded(_):
 global GUARD
 if not ready():return
 GUARD=True
 try:
  s=scene();p=s.soldier_hair
  for key,default in [('style','CARDS'),('bandana',True),('preview','CHARACTER'),('closeup',True)]:setattr(p,key,s.get('hc_'+key,default))
 finally:GUARD=False
CLASSES=[HC_Settings,HC_OT_open,HC_OT_compare,HC_OT_isolate,HC_OT_view,HC_PT_hair]
def register():
 if hasattr(bpy.types,'HC_PT_hair'):loaded(None);return
 for cls in CLASSES:bpy.utils.register_class(cls)
 bpy.types.Scene.soldier_hair=PointerProperty(type=HC_Settings)
 if loaded not in bpy.app.handlers.load_post:bpy.app.handlers.load_post.append(loaded)
 loaded(None)
def unregister():
 if loaded in bpy.app.handlers.load_post:bpy.app.handlers.load_post.remove(loaded)
 if hasattr(bpy.types.Scene,'soldier_hair'):del bpy.types.Scene.soldier_hair
 for cls in reversed(CLASSES):bpy.utils.unregister_class(cls)
