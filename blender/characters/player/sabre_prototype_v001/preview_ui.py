"""Optional local Blender sidebar; the saved NLA reel also works without it."""
from pathlib import Path
import sys, math
import bpy
from bpy.props import EnumProperty, BoolProperty
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import motion

def select_action(scene,context):
    rig=bpy.data.objects.get('SabrePrototypeRig')
    if not rig:return
    action=bpy.data.actions.get('Sabre_'+scene.sabre_action)
    if not action:return
    rig.animation_data.use_nla=False;rig.animation_data.action=action
    rig.animation_data.action_slot=action.slots[0]
    scene.frame_start=1;scene.frame_end=round(1+120*motion.CLIPS[scene.sabre_action]['duration'])
    scene.frame_set(1)

def expression(scene,context=None):
    face=bpy.data.objects.get('SabrePrototypeFace')
    if not face:return
    face.data.shape_keys.key_blocks['Focused'].value=1. if scene.sabre_expression=='Focused' else 0.
    t=(scene.frame_current-1)/120
    phase=t%2.8
    blink=max(0.,1-abs(phase-2.55)/.085) if scene.sabre_blink else 0.
    face.data.shape_keys.key_blocks['Blink'].value=blink

def frame_update(scene,depsgraph=None):expression(scene)

class SABRE_OT_reel(bpy.types.Operator):
    bl_idname='sabre.reel';bl_label='Play complete action reel'
    def execute(self,context):
        rig=bpy.data.objects['SabrePrototypeRig'];rig.animation_data.action=None;rig.animation_data.use_nla=True
        context.scene.frame_start=1
        context.scene.frame_end=math.ceil(max(s.frame_end for t in rig.animation_data.nla_tracks for s in t.strips))
        context.scene.frame_set(1)
        return {'FINISHED'}

class SABRE_OT_play(bpy.types.Operator):
    bl_idname='sabre.play';bl_label='Play / pause'
    def execute(self,context):
        bpy.ops.screen.animation_play();return {'FINISHED'}

class SABRE_PT_controls(bpy.types.Panel):
    bl_label='Sabre Character Prototype';bl_idname='SABRE_PT_controls'
    bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Sabre Prototype'
    def draw(self,context):
        layout=self.layout;scene=context.scene
        layout.label(text='22 actions | authored reconstruction',icon='ARMATURE_DATA')
        layout.prop(scene,'sabre_action',text='Action')
        row=motion.CLIPS[scene.sabre_action]
        layout.label(text='%.4f s | %s'%(row['duration'],row['category']))
        layout.operator('sabre.play',icon='PLAY')
        layout.operator('sabre.reel',icon='NLA')
        layout.separator();layout.prop(scene,'sabre_expression',text='Face')
        layout.prop(scene,'sabre_blink',text='Looped blink')
        layout.label(text='Dimensions/clocks measured; poses rebuilt.')

def register():
    for cls in [SABRE_OT_reel,SABRE_OT_play,SABRE_PT_controls]:
        if hasattr(bpy.types,cls.__name__):bpy.utils.unregister_class(getattr(bpy.types,cls.__name__))
        bpy.utils.register_class(cls)
    bpy.types.Scene.sabre_action=EnumProperty(name='Action',items=[(n,n,'%s %.4fs'%(d['category'],d['duration'])) for n,d in motion.CLIPS.items()],update=select_action)
    bpy.types.Scene.sabre_expression=EnumProperty(name='Expression',items=[('Neutral','Neutral','Relaxed eyes'),('Focused','Focused','Combat brows and eyes')],update=expression)
    bpy.types.Scene.sabre_blink=BoolProperty(name='Looped blink',default=True,update=expression)
    if frame_update not in bpy.app.handlers.frame_change_post:bpy.app.handlers.frame_change_post.append(frame_update)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':area.spaces.active.show_region_ui=True
    # Default selection is an individual loop so the control is immediately usable.
    select_action(bpy.context.scene,bpy.context)

if __name__=='__main__':register()
