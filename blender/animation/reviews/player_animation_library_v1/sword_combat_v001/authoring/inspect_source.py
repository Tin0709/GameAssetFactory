import bpy,json,sys
from pathlib import Path
R=Path(__file__).resolve().parents[6]
sys.path.insert(0,str(R/'blender/animation/showcase'))
import gaf_animation_library as ui
rig=bpy.data.objects['SC_Player_Rig'];scene=bpy.data.scenes['SWORD_COMBO_ORIGINAL_REVIEW'];bpy.context.window.scene=scene
act=bpy.data.actions['Sword_Combo_Original_v001'];rig.animation_data.action=act;rig.animation_data.action_slot=act.slots[0];scene.frame_set(1);bpy.context.view_layer.update()
print('INSPECT',json.dumps({'scene':scene.name,'armature':rig.data.name,'rest_signature':ui.rest_signature(rig.data),'signature':ui.action_signature(act),'bones':{b.name:{'parent':b.parent.name if b.parent else None,'basis':[list(x) for x in b.matrix_basis],'matrix':[list(x) for x in b.matrix]} for b in rig.pose.bones},'sword_matrix':[list(x) for x in bpy.data.objects['Sword_Sand_Block_V1'].matrix_world],'texts':list(bpy.data.texts.keys()),'scene_objs':[o.name for o in scene.objects]}))
