"""Repository-local Soldier asset selector, loaded explicitly by the existing launcher."""
import bpy,json,sys
from pathlib import Path
from bpy.props import StringProperty,EnumProperty
from bpy.app.handlers import persistent

CATEGORY='SOLDIER Library'
_sidebar_attempts=0

def registry():
    scene=bpy.data.scenes.get('SOLDIER_ASSET_LIBRARY')
    if scene is None:return {'entries':[]}
    try:return json.loads(scene.get('soldier_registry','{}'))
    except (ValueError,TypeError):return {'entries':[]}

def review_scene(entry):
    return entry.get('review_scene','SOLDIER_ASSET_LIBRARY')

def active_entry(context):
    entries=registry().get('entries',[])
    if context.view_layer.name=='Facial Expressions':
        return next((e for e in entries if e.get('type')=='facial'),None)
    return next((e for e in entries if review_scene(e)==context.scene.name and e.get('type')!='facial'),None)

def label(entry):
    if entry['id']=='SOLDIER_Skin_v001':return 'Soldier Skin v001'
    if entry['id']=='SOLDIER_Backpack_v001':return 'Backpack v001'
    return entry.get('label',entry['id'])

def show_camera(context,entry,direction):
    target=bpy.data.scenes[review_scene(entry)]
    prefix='BPK_' if entry['id']=='SOLDIER_Backpack_v001' else ''
    camera=bpy.data.objects.get(prefix+direction)
    if camera is None:raise ValueError('Review camera is unavailable')
    target.camera=camera
    for area in context.window.screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.use_local_camera=False
            space.region_3d.view_perspective='CAMERA'
            space.overlay.show_overlays=False
            space.show_region_ui=True
            area.tag_redraw()

class SOLDIER_OT_select_asset(bpy.types.Operator):
    bl_idname='soldier_library.select_asset'
    bl_label='Review Soldier Asset'
    bl_description='Show this asset in its own review without fitting or changing it'
    asset_id:StringProperty()
    def execute(self,context):
        entry=next((e for e in registry().get('entries',[]) if e['id']==self.asset_id),None)
        if entry is None or review_scene(entry) not in bpy.data.scenes:
            self.report({'ERROR'},'Asset review is unavailable');return {'CANCELLED'}
        target=bpy.data.scenes[review_scene(entry)]
        context.window.scene=target
        context.window.view_layer=target.view_layers.get(entry.get('view_layer',''),target.view_layers[0])
        for obj in context.view_layer.objects:
            if obj.select_get():obj.select_set(False)
        selected=bpy.data.objects.get(entry.get('object',entry.get('body','')))
        if selected is not None:
            selected.select_set(True);context.view_layer.objects.active=selected
        show_camera(context,entry,'Front_3Q')
        return {'FINISHED'}

class SOLDIER_OT_view(bpy.types.Operator):
    bl_idname='soldier_library.view'
    bl_label='Soldier Review View'
    direction:EnumProperty(items=[(v,v.replace('_',' '),'') for v in ['Front','Front_3Q','Left_Side','Back','Right_Side','Back_3Q']])
    def execute(self,context):
        entry=active_entry(context)
        if entry is None:return {'CANCELLED'}
        show_camera(context,entry,self.direction)
        return {'FINISHED'}

class SOLDIER_PT_library(bpy.types.Panel):
    bl_label='SOLDIER — Asset Library'
    bl_idname='SOLDIER_PT_library'
    bl_space_type='VIEW_3D'
    bl_region_type='UI'
    bl_category=CATEGORY
    @classmethod
    def poll(cls,context):
        return bool(registry().get('entries')) and active_entry(context) is not None
    def draw(self,context):
        layout=self.layout;entries=registry()['entries'];current=active_entry(context)
        for title,equipment in [('CHARACTER',False),('EQUIPMENT',True)]:
            group=[e for e in entries if e.get('type')!='facial' and (e.get('type')=='equipment')==equipment]
            if not group:continue
            box=layout.box();box.label(text=title,icon='OUTLINER_COLLECTION')
            for entry in group:
                row=box.row(align=True);row.scale_y=1.35
                op=row.operator('soldier_library.select_asset',text=label(entry),icon='OUTLINER_OB_MESH',depress=current['id']==entry['id'])
                op.asset_id=entry['id']
                row.label(text=entry.get('status','Pending'))
        if current.get('type')=='facial':return
        if any(e.get('type')=='facial' for e in entries):layout.operator('soldier_face.open',text='Facial Expressions · 18 Pending',icon='HIDE_OFF')
        layout.separator()
        box=layout.box();box.label(text=label(current),icon='CHECKMARK' if current.get('status')=='Approved' else 'TIME')
        box.label(text='Status: '+current.get('status','Pending'))
        if current.get('type')=='equipment':box.label(text='Standalone — not attached',icon='INFO')
        layout.label(text='REVIEW VIEWS')
        for choices in [[('Front','Front'),('3/4','Front_3Q'),('Side','Left_Side')],[('Back','Back'),('Back 3/4','Back_3Q'),('Other side','Right_Side')]]:
            row=layout.row(align=True)
            for text,direction in choices:
                row.operator('soldier_library.view',text=text).direction=direction
        layout.separator();layout.label(text='Blender review only',icon='INFO')

def focus_sidebar():
    global _sidebar_attempts
    _sidebar_attempts+=1;ready=False;active=False
    for window in bpy.context.window_manager.windows:
        if not any(review_scene(e)==window.scene.name for e in registry().get('entries',[])):continue
        for area in window.screen.areas:
            if area.type!='VIEW_3D':continue
            area.spaces.active.show_region_ui=True;area.tag_redraw()
            for region in area.regions:
                if region.type=='UI':
                    ready=True
                    try:
                        with bpy.context.temp_override(window=window,area=area,region=region):
                            region.active_panel_category=CATEGORY
                    except (AttributeError,TypeError,RuntimeError):
                        pass  # Some native contexts expose this getter as read-only; the tab stays available.
                    active=active or region.active_panel_category==CATEGORY
    if not ready and _sidebar_attempts<12:return .25
    print('SOLDIER_LIBRARY_UI_READY',json.dumps({'assets':len(registry().get('entries',[])),'sidebar_available':ready,'sidebar_active':active,'scene':bpy.context.scene.name}),flush=True)

@persistent
def loaded(_):
    global _sidebar_attempts
    if not registry().get('entries'):return
    _sidebar_attempts=0
    if not bpy.app.background and not bpy.app.timers.is_registered(focus_sidebar):
        bpy.app.timers.register(focus_sidebar,first_interval=.25)

CLASSES=[SOLDIER_OT_select_asset,SOLDIER_OT_view,SOLDIER_PT_library]
def register():
    if hasattr(bpy.types,'SOLDIER_PT_library'):return
    for cls in CLASSES:bpy.utils.register_class(cls)
    facial=Path(__file__).resolve().parents[1]/'facial'
    if str(facial) not in sys.path:sys.path.insert(0,str(facial))
    if (facial/'facial_ui.py').exists():
        import facial_ui;facial_ui.register()
    if loaded not in bpy.app.handlers.load_post:bpy.app.handlers.load_post.append(loaded)
    loaded(None)

def unregister():
    if bpy.app.timers.is_registered(focus_sidebar):bpy.app.timers.unregister(focus_sidebar)
    if loaded in bpy.app.handlers.load_post:bpy.app.handlers.load_post.remove(loaded)
    if 'facial_ui' in sys.modules:sys.modules['facial_ui'].unregister()
    for cls in reversed(CLASSES):bpy.utils.unregister_class(cls)

if __name__=='__main__':register()
