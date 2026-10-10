"""Review UI: select archived clips and isolated new studies without editing keys."""
import bpy, json
from bpy.props import StringProperty, EnumProperty

SCENE='PLAYER_ANIMATION_LIBRARY_V1'
def review_scene():return bpy.data.scenes[SCENE]
def entries():return json.loads(review_scene()['review_catalog'])
def actors():return json.loads(review_scene()['review_actors'])
def set_view():
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.show_region_ui=True
                area.spaces.active.overlay.show_overlays=False
                area.spaces.active.shading.type='MATERIAL'
                area.spaces.active.shading.studiolight_intensity=.65

class PLAYER_REVIEW_OT_select(bpy.types.Operator):
    bl_idname='player_review.select';bl_label='Select animation';bl_options={'REGISTER'}
    clip_id:StringProperty()
    def execute(self,context):
        e=next(x for x in entries() if x['id']==self.clip_id)
        scene=review_scene();a=actors()
        for key,info in a.items():
            col=bpy.data.collections[info['collection']]
            col.hide_viewport=key!=e.get('actor');col.hide_render=key!=e.get('actor')
        if 'scene' in e:
            target=bpy.data.scenes[e['scene']]
        else:
            target=scene
            rig=bpy.data.objects[a[e['actor']]['rig']]
            if e.get('action'):
                action=bpy.data.actions[e['action']]
                rig.animation_data.action=action
                if action.slots:rig.animation_data.action_slot=action.slots[0]
            context.window.scene=target
            context.view_layer.objects.active=rig
            for ob in context.selected_objects:ob.select_set(False)
            rig.select_set(True)
        context.window.scene=target
        if e.get('review_rig'):
            rig=bpy.data.objects[e['review_rig']]
            for ob in context.selected_objects:ob.select_set(False)
            context.view_layer.objects.active=rig;rig.select_set(True)
        target.frame_start=e['start'];target.frame_end=e['end'];target.render.fps=e['fps']
        target.render.fps_base=1;target.use_preview_range=False
        scene['review_selected']=e['id'];target.frame_set(e['start'])
        set_view()
        return {'FINISHED'}

class PLAYER_REVIEW_OT_camera(bpy.types.Operator):
    bl_idname='player_review.camera';bl_label='Review camera'
    direction:StringProperty(default='FRONT')
    def execute(self,context):
        from mathutils import Vector
        sc=context.scene
        if sc.get('review_cameras'):
            camera_names=json.loads(sc['review_cameras'])
            sc.camera=bpy.data.objects[camera_names[self.direction]]
            set_view();return {'FINISHED'}
        if sc.name!=SCENE:
            # Keep the original block journey visible rather than switching to an empty stage.
            sc.camera=bpy.data.objects['Side_Diagnostic_FIXED' if self.direction=='SIDE' else 'Gameplay_Oblique_FIXED']
            set_view();return {'FINISHED'}
        loc={'FRONT':(0,-7,2.5),'BACK':(0,7,2.5),'SIDE':(7,0,2.5),'THREE_QUARTER':(3,-6,3)}[self.direction]
        sc.camera.location=loc
        sc.camera.rotation_euler=(Vector((0,0,.95))-sc.camera.location).to_track_quat('-Z','Y').to_euler()
        set_view();return {'FINISHED'}

class PLAYER_REVIEW_PT_library(bpy.types.Panel):
    bl_label='PLAYER / ANIMATION LIBRARY'
    bl_idname='PLAYER_REVIEW_PT_library';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Player Review'
    def draw(self,context):
        layout=self.layout;sc=review_scene();catalog=entries()
        layout.label(text='Blender animation review')
        layout.label(text='Space: play / pause',icon='PLAY')
        selected=next((e for e in catalog if e['id']==sc.get('review_selected')),catalog[0])
        box=layout.box();box.label(text=selected['label'])
        box.label(text=f"{selected['duration_seconds']:.3f} s / {selected['fps']} FPS")
        if selected.get('review_rig'):
            box.label(text='NEW: flat jump / Blender only',icon='INFO')
            box.label(text='F12 apex / F19 contact / F25 recover')
            box.label(text='Carrier = preview height only')
        elif selected['group']=='Jump (study only)':box.label(text='Study only - deferred in game',icon='INFO')
        elif selected['group']=='Holster & Draw':box.label(text='5.25x transition speed (game)')
        else:box.label(text='In-place; original source keys')
        row=layout.row(align=True)
        for text,d in [('3/4','THREE_QUARTER'),('Front','FRONT'),('Back','BACK'),('Side','SIDE')]:
            op=row.operator('player_review.camera',text=text);op.direction=d
        layout.prop(sc,'player_review_group',text='Group')
        group=sc.player_review_group
        if group=='Combat Strafe':layout.prop(sc,'player_review_weapon',text='Weapon')
        for e in catalog:
            if e['group']==group and (group!='Combat Strafe' or e.get('weapon','Rifle')==sc.player_review_weapon):
                op=layout.operator('player_review.select',text=e['label'],depress=e['id']==selected['id'])
                op.clip_id=e['id']
        layout.separator();layout.label(text='Archive: original Scene dropdown')
        layout.label(text='All source Actions remain in this file')

classes=[PLAYER_REVIEW_OT_select,PLAYER_REVIEW_OT_camera,PLAYER_REVIEW_PT_library]
for cls in classes:
    old=getattr(bpy.types,cls.__name__,None)
    if old:
        try:bpy.utils.unregister_class(old)
        except RuntimeError:pass
    bpy.utils.register_class(cls)
bpy.types.Scene.player_review_group=EnumProperty(name='Group',items=[(g,g,g) for g in [
    'Locomotion','Turning','Holster & Draw','Combat Strafe','Jump (study only)']])
bpy.types.Scene.player_review_weapon=EnumProperty(name='Weapon',items=[(g,g,g) for g in ['Pistol','Rifle','Shotgun']],default='Rifle')
set_view()
