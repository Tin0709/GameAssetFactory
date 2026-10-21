"""Same-window Pending interaction review, keeping Wind's native code untouched."""
import json
from pathlib import Path
import bpy
import runtime
from field import CONTROLS

LIB='dungeons_ground_style_v2.blend'
record=runtime.record


def leave(context):
    scene=context.scene
    if not scene.get('md2_interaction_view_active'):return
    if context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    old=json.loads(scene['md2_interaction_return_timeline'])
    scene['md2_interaction_view_active']=False
    scene.use_preview_range=False
    scene.frame_start=min(old['frame_start'],old['frame_preview_start'])
    scene.frame_end=max(old['frame_end'],old['frame_preview_end'])
    scene.frame_preview_start=old['frame_preview_start'];scene.frame_preview_end=old['frame_preview_end']
    scene.frame_start=old['frame_start'];scene.frame_end=old['frame_end']
    scene.use_preview_range=old['use_preview_range'];scene.sync_mode=old['sync_mode'];scene.frame_set(old['frame_current'])


def select(context,key='Gameplay'):
    import wind_review_ui
    scene=context.scene;info=record(scene)
    assert Path(bpy.data.filepath).name==LIB and info
    wind_review_ui.leave(context)
    if not scene.get('md2_interaction_view_active'):
        keys=['frame_current','frame_start','frame_end','use_preview_range','frame_preview_start','frame_preview_end','sync_mode']
        scene['md2_interaction_return_timeline']=json.dumps({k:getattr(scene,k) for k in keys})
        scene['md2_interaction_view_active']=True
        scene.use_preview_range=False;scene.frame_start=1
        end=round(runtime.ensure_cache(scene).duration*scene.render.fps/scene.render.fps_base)
        scene.frame_end=max(scene.frame_end,end);scene.frame_preview_start=1;scene.frame_preview_end=end;scene.use_preview_range=True
    context.window.view_layer=scene.view_layers[info['layer']]
    for obj in list(bpy.data.collections[info['root']].all_objects):
        obj.hide_set(False,view_layer=context.view_layer)
    for area in context.screen.areas:
        if area.type=='VIEW_3D':
            view=area.spaces.active;view.use_local_camera=True;view.camera=bpy.data.objects[info['cameras'][key]]
            view.region_3d.view_perspective='CAMERA';view.region_3d.view_camera_zoom=0.;view.overlay.show_overlays=False
            view.show_region_ui=True;area.tag_redraw()
    scene.sync_mode='FRAME_DROP';scene['md2_interaction_selected']=key
    runtime.update(scene,force=True);context.view_layer.update()


class MD2_OT_interaction_view(bpy.types.Operator):
    bl_idname='md2_interaction.view';bl_label='Review player interaction'
    key:bpy.props.StringProperty(default='Gameplay')
    def execute(self,context):
        if self.key=='Wind':
            import wind_review_ui
            wind_review_ui.select(context,'Field')
        else:select(context,self.key)
        return {'FINISHED'}


class MD2_OT_interaction_play(bpy.types.Operator):
    bl_idname='md2_interaction.play';bl_label='Play / pause interaction'
    reset:bpy.props.BoolProperty(default=False)
    def execute(self,context):
        if not context.scene.get('md2_interaction_view_active'):select(context)
        if self.reset:
            if context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
            context.scene.frame_set(1);runtime.update(force=True)
        else:bpy.ops.screen.animation_play()
        return {'FINISHED'}


class MD2_PT_interaction(bpy.types.Panel):
    bl_label='Grass MD2 — Player Interaction';bl_idname='MD2_PT_interaction'
    bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Grass MD2';bl_order=-30
    @classmethod
    def poll(cls,context):return Path(bpy.data.filepath).name==LIB and 'md2_interaction_review' in context.scene
    def draw(self,context):
        layout=self.layout;info=record(context.scene)
        row=layout.row(align=True)
        for key,title in [('Gameplay','Fixed gameplay'),('Close','Close-up')]:row.operator('md2_interaction.view',text=title).key=key
        row=layout.row(align=True);row.operator('md2_interaction.play',text='Play / Pause · 1×',icon='PLAY')
        row.operator('md2_interaction.play',text='Restart',icon='REW').reset=True
        controller=bpy.data.objects[info['controller']]
        for key in CONTROLS:layout.prop(controller,'["'+key+'"]',text=key)
        layout.label(text=controller.get('Preview Phase','WALK / SHORT GRASS'))
        layout.label(text='Walk → Run → Stop → Recover')
        layout.operator('md2_interaction.view',text='Unchanged Wind v001').key='Wind'
        layout.label(text='Pending · original interaction adaptation',icon='INFO')


def register():
    import wind_review_ui
    # Route adapter only: no edits to Wind's file/tree/controller or original function.
    original=getattr(wind_review_ui.select,'_md2_original',wind_review_ui.select)
    def select_wind(context,key):
        leave(context);return original(context,key)
    select_wind._md2_original=original;wind_review_ui.select=select_wind
    for cls in [MD2_OT_interaction_view,MD2_OT_interaction_play,MD2_PT_interaction]:
        if not hasattr(bpy.types,cls.__name__):bpy.utils.register_class(cls)
    runtime.register()


def start_preview():
    if bpy.app.background or not record() or not bpy.context.scene.get('md2_interaction_view_active'):return
    runtime.update(force=True)
    if not bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_play()
    print('MD2_INTERACTION_NATIVE_READY',bpy.context.view_layer.name,bpy.context.screen.is_animation_playing,flush=True)
