"""Review controls installed in live Blender; scene/angle selection, no asset edits."""
import bpy,json
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'combat_strafe_r14_pass2_review'
d=json.loads((OUT/'design.json').read_text())
for name in ['R14P2_OT_scene','R14P2_OT_angle','R14P2_PT_review']:
    old=getattr(bpy.types,name,None)
    if old:bpy.utils.unregister_class(old)

class R14P2_OT_scene(bpy.types.Operator):
    bl_idname='r14p2.review_scene';bl_label='Review scene'
    scene_name:bpy.props.StringProperty()
    def execute(self,context):
        context.window.scene=bpy.data.scenes[self.scene_name];context.window.scene.frame_set(1)
        for a in context.window.screen.areas:
            if a.type=='VIEW_3D':a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.overlay.show_overlays=False
        return {'FINISHED'}

class R14P2_OT_angle(bpy.types.Operator):
    bl_idname='r14p2.review_angle';bl_label='Review angle'
    angle:bpy.props.StringProperty()
    def execute(self,context):
        data=next((x for x in d['reviews'].values() if x['scene']==context.scene.name),None)
        if data:context.scene.camera=bpy.data.objects[data['cameras'][self.angle]]
        return {'FINISHED'}

class R14P2_PT_review(bpy.types.Panel):
    bl_label='R14 Pass 2 / Human review';bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Combat Review'
    def draw(self,context):
        l=self.layout;l.label(text='2.60 m/s | 48 FPS | study only')
        l.operator('r14p2.review_scene',text='SIX DIRECTIONS').scene_name=d['showcase_scene']
        l.operator('r14p2.review_scene',text='A/B - V1 vs V2').scene_name=d['ab_scene']
        for direction,data in d['reviews'].items():l.operator('r14p2.review_scene',text=direction).scene_name=data['scene']
        l.separator();l.label(text='Camera / individual directions')
        for angle in ['ThreeQuarter','Front','Side','Gameplay']:l.operator('r14p2.review_angle',text=angle).angle=angle
        l.separator();l.label(text='Continuous phase transitions')
        for i,data in enumerate(d['transitions']):l.operator('r14p2.review_scene',text=str(i+1)+' - '+' > '.join(data['sequence'])).scene_name=data['scene']
        l.separator();l.operator('r14p2.review_scene',text='Lab speed - 4.25 m/s').scene_name=d['lab_speed_scene']
        l.operator('screen.animation_play',text='Play / Pause')
        l.label(text='AWAITING HUMAN REVIEW')

for cls in [R14P2_OT_scene,R14P2_OT_angle,R14P2_PT_review]:bpy.utils.register_class(cls)
for w in bpy.context.window_manager.windows:
    for area in w.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.show_region_ui=True;area.spaces.active.show_region_toolbar=False;area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.region_3d.view_camera_zoom=5;area.spaces.active.overlay.show_overlays=False
            # Activate the custom review tab after UI has drawn the registered panel.
            def tab(a=area):
                for region in a.regions:
                    if region.type=='UI':
                        try:region.active_panel_category='Combat Review'
                        except Exception:pass
                return None
            bpy.app.timers.register(tab,first_interval=.3)
result={'review_panel':'Combat Review','scenes':len(d['reviews'])+4+len(d['transitions'])}
