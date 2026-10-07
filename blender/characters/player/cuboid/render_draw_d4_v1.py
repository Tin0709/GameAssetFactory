import bpy, math, json
from pathlib import Path
from mathutils import Matrix
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
out=BASE/'draw_d4_v1_review';out.mkdir(exist_ok=True)
scene=bpy.context.scene;rig=bpy.data.objects['Player_Cuboid_Rig'];action=bpy.data.actions['Draw_LongGun_V1']
def reset():
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
def frame(f):scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
def shot(name,view):
 scene.camera=bpy.data.objects['D1_'+view];scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
for f,view in [(1,'Gameplay'),(4,'Gameplay'),(7,'Side'),(9,'Back'),(11,'Gameplay')]:
 rig.animation_data.action=action;reset();frame(f);shot('draw_%02d_%s'%(f,view.lower()),view)
for layer,phase,f in [('Idle',0,7),('Run',0,7),('Run',4,11),('Run',8,7),('Run',12,11)]:
 source=bpy.data.actions['Player_Idle' if layer=='Idle' else 'Player_Run_Blocky_V7_Final']
 sf=1+((phase+(f-1)*(1.6 if layer=='Run' else 1))%float(source.frame_range[1]-source.frame_range[0]))
 rig.animation_data.action=source;reset();frame(sf);base={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
 rig.animation_data.action=action;reset();frame(f)
 for n in ['Root','Hips','Leg.L','Leg.R']:rig.pose.bones[n].matrix_basis=base[n]
 for n in ['Spine','Chest','Neck','Head']:rig.pose.bones[n].matrix_basis=base[n]@rig.pose.bones[n].matrix_basis
 bpy.context.view_layer.update();shot('overlay_%s_phase%d_frame%d'%(layer.lower(),phase,f),'Gameplay')
# A few comparison stills keep the different pacing/intention reviewable.
rig.animation_data.action=bpy.data.actions['Holster_LongGun_V3_Final']
for f in [5,11,18]:reset();frame(f);shot('holster_compare_%02d'%f,'Gameplay')
rig.animation_data.action=action;reset();frame(1);scene.camera=bpy.data.objects['D1_Gameplay']
print('D4 additional views, overlay phases and Holster comparison rendered')
