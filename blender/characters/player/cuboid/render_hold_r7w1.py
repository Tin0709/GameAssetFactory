import bpy,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'hold_r7w1_review'
scene=bpy.data.scenes['R7W1_AUTHORING'];bpy.context.window.scene=scene
rig=bpy.data.objects['R7W1_Author_Player_Cuboid_Rig']
for label,name,frame in [('A','LongGunHold_V2',1),('B','LongGunHold_ReferenceStudy_V1',1),('C','LongGunAimBias_Study_V1',20)]:
 action=bpy.data.actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 for view in ['Front','Side','Gameplay','Rear','GameplayDistance','CloseGun']:
  scene.camera=bpy.data.objects['R7W1_'+view];scene.frame_set(frame);scene.render.filepath=str(OUT/(label+'_'+view+'.png'));bpy.ops.render.render(write_still=True)
print('R7W1_STILLS_RENDERED',flush=True)
