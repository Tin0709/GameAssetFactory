"""SOLDIER Library facial section. Explicit launcher bootstrap; no global auto-run."""
import bpy,json
from bpy.props import StringProperty,IntProperty,FloatProperty,BoolProperty,EnumProperty,CollectionProperty,PointerProperty
from bpy.app.handlers import persistent
import expression_model as model
import face_blender as fb
_GUARD=False
SIT_ITEMS=[('EXPRESSION','Expression presets','Independent preset review')]+[(name,name,'Situation-driven face + existing body preview') for name in model.SITUATIONS]

def main():return bpy.data.scenes.get('SOLDIER_ASSET_LIBRARY')
def available():return main() is not None and bpy.data.objects.get('SF_Face_Control') is not None

def show_layer(context):
 scene=main();context.window.scene=scene;context.window.view_layer=scene.view_layers['Facial Expressions']
 for view_layer in scene.view_layers:view_layer.use=view_layer.name=='Facial Expressions'
 return scene

def apply_controls(self,context):
 if _GUARD or not available():return
 ctrl=bpy.data.objects['SF_Face_Control']
 for key in ['intensity','look_x','look_y','auto_blink']:ctrl[key]=float(getattr(self,key))
 ctrl.update_tag();context.view_layer.update()

def select(context,kind,key,autoplay=False):
 global _GUARD
 if not available():return
 _GUARD=True
 try:
  scene=show_layer(context);props=scene.soldier_facial;ctrl=bpy.data.objects['SF_Face_Control'];current={k:float(ctrl[k]) for k in model.NEUTRAL}
  duration=model.PRESETS[key]['duration'] if kind=='preset' else model.SITUATIONS[key]
  fb.assign(ctrl,fb.face_action('SF_Preview_Live_Face',ctrl,kind,key,duration,current))
  fb.body_action(bpy.data.objects['SF_Soldier_Rig'],bpy.data.objects['SF_Rifle_Sand_Block_V1'],kind,key,duration)
  scene.frame_start=1;scene.frame_end=round(duration*30)
  if kind=='preset':props.loop=model.PRESETS[key]['loop'];props.index=list(model.PRESETS).index(key);props.situation='EXPRESSION'
  else:props.loop=key not in ['Jump','Landing','Hurt'];props.situation=key
  scene['sf_selected_preset']=props.index;scene['sf_mode']=kind;scene['sf_situation']=key;scene['sf_loop']=props.loop
  scene.frame_set(1);scene.camera=bpy.data.objects.get(scene.get('sf_camera','SF_Front_Close'),bpy.data.objects['SF_Front_Close'])
  for area in context.window.screen.areas:
   if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.show_region_ui=True;area.tag_redraw()
  if autoplay and not bpy.app.background and not context.screen.is_animation_playing:bpy.ops.screen.animation_play()
 finally:_GUARD=False

def selected(self,context):
 if not _GUARD and available():select(context,'preset',list(model.PRESETS)[self.index],True)
def situation_changed(self,context):
 if _GUARD or not available():return
 if self.situation=='EXPRESSION':select(context,'preset',list(model.PRESETS)[self.index],True)
 else:select(context,'situation',self.situation,True)
def loop_changed(self,context):
 if main():main()['sf_loop']=self.loop

class SF_PresetItem(bpy.types.PropertyGroup):
 key:StringProperty()
class SF_Settings(bpy.types.PropertyGroup):
 presets:CollectionProperty(type=SF_PresetItem)
 index:IntProperty(default=0,min=0,max=17,update=selected)
 intensity:FloatProperty(name='Intensity',default=1.,min=0.,max=1.,update=apply_controls)
 look_x:FloatProperty(name='Look Left / Right',default=0.,min=-1.,max=1.,update=apply_controls)
 look_y:FloatProperty(name='Look Down / Up',default=0.,min=-1.,max=1.,update=apply_controls)
 auto_blink:BoolProperty(name='Auto Blink',default=True,update=apply_controls)
 loop:BoolProperty(name='Loop',default=True,update=loop_changed)
 situation:EnumProperty(name='Situation Preview',items=SIT_ITEMS,default='EXPRESSION',update=situation_changed)

class SF_UL_presets(bpy.types.UIList):
 def draw_item(self,context,layout,data,item,icon,active_data,active_propname,index):
  row=layout.row(align=True);row.label(text=item.key,icon='TIME');row.label(text='Pending')

class SF_OT_open(bpy.types.Operator):
 bl_idname='soldier_face.open';bl_label='Facial Expressions';bl_description='Preview the actual Soldier face inside this same library'
 def execute(self,context):select(context,'preset',list(model.PRESETS)[main().soldier_facial.index]);return {'FINISHED'}
class SF_OT_step(bpy.types.Operator):
 bl_idname='soldier_face.step';bl_label='Previous / Next Expression'
 direction:IntProperty(default=1)
 def execute(self,context):
  props=main().soldier_facial;props.index=(props.index+self.direction)%len(model.PRESETS);return {'FINISHED'}
class SF_OT_play(bpy.types.Operator):
 bl_idname='soldier_face.play';bl_label='Play / Pause'
 def execute(self,context):
  show_layer(context)
  if not bpy.app.background:bpy.ops.screen.animation_play()
  return {'FINISHED'}
class SF_OT_restart(bpy.types.Operator):
 bl_idname='soldier_face.restart';bl_label='Restart'
 def execute(self,context):show_layer(context).frame_set(1);return {'FINISHED'}
class SF_OT_neutral(bpy.types.Operator):
 bl_idname='soldier_face.neutral';bl_label='Reset to Neutral'
 def execute(self,context):
  global _GUARD
  _GUARD=True;p=main().soldier_facial;p.look_x=0.;p.look_y=0.;p.intensity=1.;_GUARD=False;apply_controls(p,context)
  select(context,'preset','Neutral_Idle');return {'FINISHED'}
class SF_OT_camera(bpy.types.Operator):
 bl_idname='soldier_face.camera';bl_label='Facial Review Camera'
 camera:StringProperty(default='SF_Front_Close')
 def execute(self,context):
  scene=show_layer(context);scene.camera=bpy.data.objects[self.camera];scene['sf_camera']=self.camera
  for area in context.window.screen.areas:
   if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.use_local_camera=False;area.tag_redraw()
  return {'FINISHED'}
class SF_PT_facial(bpy.types.Panel):
 bl_label='Facial Expressions · Pending';bl_idname='SF_PT_facial';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='SOLDIER Library';bl_parent_id='SOLDIER_PT_library'
 @classmethod
 def poll(cls,context):return available()
 def draw(self,context):
  layout=self.layout
  if context.scene!=main() or context.view_layer.name!='Facial Expressions':layout.operator('soldier_face.open',icon='HIDE_OFF');return
  p=main().soldier_facial;layout.label(text='18 original presets · actual Soldier',icon='OUTLINER_OB_ARMATURE')
  layout.template_list('SF_UL_presets','',p,'presets',p,'index',rows=18,maxrows=18)
  row=layout.row(align=True);row.operator('soldier_face.step',text='Previous',icon='TRIA_LEFT').direction=-1;row.operator('soldier_face.step',text='Next',icon='TRIA_RIGHT').direction=1
  row=layout.row(align=True);row.operator('soldier_face.play',icon='PAUSE' if context.screen.is_animation_playing else 'PLAY');row.operator('soldier_face.restart',icon='FILE_REFRESH');row.prop(p,'loop',toggle=True)
  layout.prop(p,'intensity',slider=True);layout.prop(p,'look_x',slider=True);layout.prop(p,'look_y',slider=True)
  row=layout.row(align=True);row.prop(p,'auto_blink');row.operator('soldier_face.neutral',icon='LOOP_BACK')
  layout.separator();layout.prop(p,'situation',text='Situation')
  row=layout.row(align=True)
  for text,camera in [('Front','SF_Front_Close'),('3/4','SF_ThreeQuarter_Close'),('Side','SF_Side_Close'),('Gameplay','SF_Gameplay_Distance')]:row.operator('soldier_face.camera',text=text).camera=camera
  layout.label(text='30 FPS · original speed · Blender only',icon='INFO')
  layout.label(text='No nose / mouth · rigid block head')

@persistent
def frame_changed(scene,depsgraph=None):
 if _GUARD or not available() or scene!=main() or scene.get('sf_loop',True) or bpy.app.background:return
 for window in bpy.context.window_manager.windows:
  if window.scene==scene and window.view_layer.name=='Facial Expressions' and window.screen.is_animation_playing and scene.frame_current>=scene.frame_end:
   with bpy.context.temp_override(window=window):bpy.ops.screen.animation_cancel(restore_frame=False)
@persistent
def loaded(_):
 global _GUARD
 if not available():return
 _GUARD=True
 try:
  s=main();p=s.soldier_facial;p.presets.clear()
  for name in model.PRESETS:item=p.presets.add();item.key=name
  p.index=int(s.get('sf_selected_preset',0));p.loop=bool(s.get('sf_loop',True))
  ctrl=bpy.data.objects['SF_Face_Control']
  for k in ['intensity','look_x','look_y']:setattr(p,k,float(ctrl.get(k,1. if k=='intensity' else 0.)))
  p.auto_blink=bool(ctrl.get('auto_blink',1.));p.situation=s.get('sf_situation','Idle') if s.get('sf_mode')=='situation' else 'EXPRESSION'
 finally:_GUARD=False
CLASSES=[SF_PresetItem,SF_Settings,SF_UL_presets,SF_OT_open,SF_OT_step,SF_OT_play,SF_OT_restart,SF_OT_neutral,SF_OT_camera,SF_PT_facial]
def register():
 if hasattr(bpy.types,'SF_PT_facial'):loaded(None);return
 for cls in CLASSES:bpy.utils.register_class(cls)
 bpy.types.Scene.soldier_facial=PointerProperty(type=SF_Settings)
 if loaded not in bpy.app.handlers.load_post:bpy.app.handlers.load_post.append(loaded)
 if frame_changed not in bpy.app.handlers.frame_change_post:bpy.app.handlers.frame_change_post.append(frame_changed)
 loaded(None)
def unregister():
 for fn,handlers in [(loaded,bpy.app.handlers.load_post),(frame_changed,bpy.app.handlers.frame_change_post)]:
  if fn in handlers:handlers.remove(fn)
 if hasattr(bpy.types.Scene,'soldier_facial'):del bpy.types.Scene.soldier_facial
 for cls in reversed(CLASSES):bpy.utils.unregister_class(cls)
