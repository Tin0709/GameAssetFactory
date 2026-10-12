"""Repository-local Weapon Library UI; explicitly loaded by Open_Weapon_Showcase.cmd."""
import bpy,json
from bpy.props import CollectionProperty,IntProperty,StringProperty,EnumProperty
from bpy.app.handlers import persistent
from mathutils import Vector,Matrix
_busy=False
def entries(scene):return json.loads(scene['weapon_manifest_snapshot'])['weapons']
def root_of(entry):return bpy.data.objects[entry['root']]
def bounds(objects):
 pts=[o.matrix_world@Vector(c) for o in objects if o.type=='MESH' for c in o.bound_box]
 lo=Vector([min(v[i] for v in pts) for i in range(3)]);hi=Vector([max(v[i] for v in pts) for i in range(3)])
 return (lo+hi)/2,hi-lo
def activate(scene):
 if _busy or not scene.gaf_weapons:return
 entry=entries(scene)[scene.gaf_weapon_index];mode=scene.gaf_fit_mode
 for c in bpy.data.collections:
  if c.get('weapon_entry'):c.hide_viewport=c.hide_render=(c.name!=entry['collection'])
  if c.get('fit_kind'):c.hide_viewport=c.hide_render=(c.get('fit_kind')!=entry['kind'] or c.get('fit_mode')!=mode)
 root=root_of(entry)
 root.matrix_world=Matrix.Identity(4) if mode=='STANDALONE' else Matrix(scene['fit_'+entry['kind']+'_'+mode])
 bpy.context.view_layer.update()
 for o in bpy.context.selected_objects:o.select_set(False)
 root.select_set(True);bpy.context.view_layer.objects.active=root
 for area in bpy.context.screen.areas if bpy.context.screen else []:
  if area.type=='VIEW_3D':
   meshes=list(bpy.data.collections[entry['collection']].objects)
   if mode!='STANDALONE':meshes+=list(bpy.data.collections['FIT_'+entry['kind']+'_'+mode].objects)
   center,dims=bounds(meshes);area.spaces.active.region_3d.view_location=center
   area.spaces.active.region_3d.view_distance=max(dims)*1.8
 view(scene,scene.get('weapon_view','THREE_QUARTER'))
def changed(self,context):activate(self)
def view(scene,direction):
 if not scene.gaf_weapons:return
 e=entries(scene)[scene.gaf_weapon_index];obs=list(bpy.data.collections[e['collection']].objects)
 if scene.gaf_fit_mode!='STANDALONE':obs+=list(bpy.data.collections['FIT_'+e['kind']+'_'+scene.gaf_fit_mode].objects)
 bpy.context.view_layer.update();center,dims=bounds(obs)
 dirs={'LEFT':(-1,0,0),'RIGHT':(1,0,0),'FRONT':(0,1,0),'BACK':(0,-1,0),'THREE_QUARTER':(1.5,-1.9,1.0)}
 if scene.gaf_fit_mode!='STANDALONE':dirs['THREE_QUARTER']=(1.5,-2.2,.8);dirs['FRONT']=(0,-1,0);dirs['BACK']=(0,1,0)
 cam=bpy.data.objects['Weapon_Review_Camera'];cam.location=center+Vector(dirs[direction]).normalized()*max(2,max(dims)*2)
 cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 # Fit projected corners for the actual render aspect, including angled character views.
 inv=cam.rotation_euler.to_matrix().transposed()
 projected=[inv@(o.matrix_world@Vector(c)-center) for o in obs if o.type=='MESH' for c in o.bound_box]
 low=[min(p[i] for p in projected) for i in range(2)];high=[max(p[i] for p in projected) for i in range(2)]
 shift=cam.rotation_euler.to_matrix()@Vector(((low[0]+high[0])/2,(low[1]+high[1])/2,0))
 center+=shift;cam.location+=shift
 aspect=scene.render.resolution_x*scene.render.pixel_aspect_x/(scene.render.resolution_y*scene.render.pixel_aspect_y)
 cam.data.ortho_scale=max(high[0]-low[0],(high[1]-low[1])*aspect)*1.18
 scene.camera=cam;scene['weapon_view']=direction
 for area in bpy.context.screen.areas if bpy.context.screen else []:
  if area.type=='VIEW_3D':
   r=area.spaces.active.region_3d;r.view_location=center;r.view_rotation=cam.rotation_euler.to_quaternion();r.view_distance=cam.data.ortho_scale*1.4;r.view_perspective='ORTHO'
def fill(scene):
 global _busy
 _busy=True
 try:
  scene.gaf_weapons.clear()
  for e in entries(scene):
   i=scene.gaf_weapons.add();i.name=e['label'];i.collection=e['collection'];i.status=e['status'];i.kind=e['kind']
  scene.gaf_weapon_index=min(scene.gaf_weapon_index,len(scene.gaf_weapons)-1)
 finally:_busy=False
 activate(scene)
class GAF_WeaponItem(bpy.types.PropertyGroup):
 collection:StringProperty();status:StringProperty();kind:StringProperty()
class GAF_UL_weapons(bpy.types.UIList):
 def draw_item(self,context,layout,data,item,icon,active_data,active_propname,index):
  row=layout.row();row.label(text=item.name,icon='OUTLINER_OB_MESH');row.label(text=item.status)
class GAF_OT_weapon_view(bpy.types.Operator):
 bl_idname='gaf.weapon_view';bl_label='Weapon View'
 direction:StringProperty(default='THREE_QUARTER')
 def execute(self,context):view(context.scene,self.direction);return {'FINISHED'}
class GAF_PT_weapon_library(bpy.types.Panel):
 bl_label='Weapon Library';bl_idname='GAF_PT_weapon_library';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Weapon Library'
 @classmethod
 def poll(cls,context):return bool(context.scene.get('weapon_manifest_snapshot'))
 def draw(self,context):
  l=self.layout;s=context.scene
  l.template_list('GAF_UL_weapons','',s,'gaf_weapons',s,'gaf_weapon_index',rows=10)
  if not s.gaf_weapons:return
  e=entries(s)[s.gaf_weapon_index];b=l.box();b.label(text=e['label']);b.label(text=e['status']+' | '+e['kind']);b.label(text=e['source'].split('/')[-1])
  l.prop(s,'gaf_fit_mode',text='Preview')
  for labels in [[('Left','LEFT'),('Right','RIGHT'),('3/4','THREE_QUARTER')],[('Front','FRONT'),('Back','BACK')]]:
   row=l.row(align=True)
   for label,d in labels:row.operator('gaf.weapon_view',text=label).direction=d
  l.label(text='Orbit / zoom / pan work normally',icon='INFO')
  if s.gaf_fit_mode!='STANDALONE':l.label(text='Static fit; animation unchanged',icon='ARMATURE_DATA')
@persistent
def loaded(_):
 for s in bpy.data.scenes:
  if s.get('weapon_manifest_snapshot'):fill(s)
CLASSES=[GAF_WeaponItem,GAF_UL_weapons,GAF_OT_weapon_view,GAF_PT_weapon_library]
def register():
 if hasattr(bpy.types,'GAF_PT_weapon_library'):return
 for cls in CLASSES:bpy.utils.register_class(cls)
 bpy.types.Scene.gaf_weapons=CollectionProperty(type=GAF_WeaponItem)
 bpy.types.Scene.gaf_weapon_index=IntProperty(default=0,min=0,update=changed)
 bpy.types.Scene.gaf_fit_mode=EnumProperty(items=[('STANDALONE','Standalone','Grip-centered weapon'),('READY','Character ready','Existing holding pose snapshot'),('HOLSTER','Character holster','Existing final holster snapshot')],default='STANDALONE',update=changed)
 bpy.app.handlers.load_post.append(loaded)
 loaded(None)
def unregister():
 if loaded in bpy.app.handlers.load_post:bpy.app.handlers.load_post.remove(loaded)
 for n in ['gaf_weapons','gaf_weapon_index','gaf_fit_mode']:delattr(bpy.types.Scene,n)
 for cls in reversed(CLASSES):bpy.utils.unregister_class(cls)
if __name__=='__main__':register()
