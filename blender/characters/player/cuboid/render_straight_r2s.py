import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'straight_study_r2s_review';s=bpy.data.scenes['R2S_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_StraightV2_Author_Rig']
draft='--draft' in sys.argv
for gait,period in PERIOD.items():
 for ver in ['V1','V2']:
  for view in ['Front','Rear','GameClose','Side']:
   if view=='Side' and ver=='V1':continue
   s.camera=bpy.data.objects['R2S_'+view];s.camera.data.ortho_scale=3.1 if gait=='Sprint' else 2.7
   s.render.resolution_x=322;s.render.resolution_y=480
   folder=OUT/(gait.lower()+'_'+ver.lower()+'_'+view.lower());folder.mkdir(exist_ok=True)
   for i in ([0,period//4,period//2,3*period//4] if draft or view=='Side' else range(period)):
    sample(r,s,bpy.data.actions[gait+'_ReferenceStudy_'+ver],1+i);s.render.filepath=str(folder/('%03d.png'%i));bpy.ops.render.render(write_still=True)
for name in ['Front','Gameplay']:
 s=bpy.data.scenes['R2S_'+name+'_V1_V2'];bpy.context.window.scene=s;s.frame_set(1);s.render.filepath=str(OUT/(name.lower()+'_overview.png'));bpy.ops.render.render(write_still=True)
if not draft:
 s=bpy.data.scenes['R2S_Gameplay_V1_V2'];bpy.context.window.scene=s;folder=OUT/'gameplay_raw';folder.mkdir(exist_ok=True)
 for i in range(208):
  s.frame_set(i+1);s.render.filepath=str(folder/('%04d.png'%(i+1)));bpy.ops.render.render(write_still=True)
print('R2S_RENDER_DONE',flush=True)
