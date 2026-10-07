import bpy,math
from pathlib import Path
from mathutils import Matrix
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid');out=BASE/'draw_d4_v3_review';out.mkdir(exist_ok=True)
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene
layer=globals().get('layer','None');phase=globals().get('phase',0);version=globals().get('version',3)
action=bpy.data.actions['Draw_LongGun_V3_Final' if version==3 else 'Draw_LongGun_V2']
source=bpy.data.actions['Player_Idle' if layer=='Idle' else 'Player_Run_Blocky_V7_Final'] if layer!='None' else None
scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.camera=bpy.data.objects['D1_Gameplay']
def reset():
 for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
def frame(f):scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
for i in range(27):
 f=1+i*.5
 if source:
  sf=source.frame_range[0]+((phase+(f-1)*(1.6 if layer=='Run' else 1))%float(source.frame_range[1]-source.frame_range[0]))
  rig.animation_data.action=source;reset();frame(sf);base={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
 rig.animation_data.action=action;reset();frame(f)
 if source:
  for n in ['Root','Hips','Leg.L','Leg.R']:rig.pose.bones[n].matrix_basis=base[n]
  for n in ['Spine','Chest','Neck','Head']:rig.pose.bones[n].matrix_basis=base[n]@rig.pose.bones[n].matrix_basis
  t=max(0,min(1,(f-1)/3));t=t*t*(3-2*t)
  for n in ['Arm.L','Arm.R']:
   p=rig.pose.bones[n];pa,qa,_=base[n].decompose();pb,qb,_=p.matrix_basis.decompose();m=qa.slerp(qb,t).to_matrix().to_4x4();m.translation=pa.lerp(pb,t);p.matrix_basis=m
  bpy.context.view_layer.update()
 scene.render.filepath=str(out/f'v{version}_{layer}_{phase}_{i:02d}.png');bpy.ops.render.render(write_still=True)
rig.animation_data.action=bpy.data.actions['Draw_LongGun_V3_Final'];reset();frame(1)
result={'version':version,'layer':layer,'phase':phase,'rendered':27}
