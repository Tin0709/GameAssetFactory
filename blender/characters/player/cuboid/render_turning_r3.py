import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'turning_study_r3_review';draft='--draft' in sys.argv
jobs=[('R3_Review_AB','ab_raw',456),('R3_Review_Gameplay','gameplay_raw',456),('R3_V1_V2_Left','versions_raw',208),('R3_Entry_Phases','entry_raw',48)]
for name,folder,count in jobs:
 s=bpy.data.scenes[name];bpy.context.window.scene=s;path=OUT/folder;path.mkdir(exist_ok=True)
 fs=([1,37,61,181,265,289,313,337,397,445] if count==456 else [1,7,13,19,25,37,48]) if draft else range(1,count+1)
 for f in fs:
  s.frame_set(f);s.render.filepath=str(path/('%04d.png'%f));bpy.ops.render.render(write_still=True)
 print('R3_RENDERED '+name,flush=True)
if not draft:
 s=bpy.data.scenes['R3_Turn_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_R3_Author_Rig'];s.camera=bpy.data.objects['R3_Detail_Front'];folder=OUT/'midpoints';folder.mkdir(exist_ok=True)
 for gait,period in PERIOD.items():
  base=bpy.data.actions[gait+'_ReferenceStudy_V2'];left=bpy.data.actions[gait+'_TurnLeft_Reference_V2'];right=bpy.data.actions[gait+'_TurnRight_Reference_V2']
  for label,a,b in [('StraightLeft',base,left),('StraightRight',base,right),('LeftRight',left,right)]:
   for phi in [0,.25]:
    for w in [.25,.5,.75]:
     f=1+period*phi;pa=sample(r,s,a,f);pb=sample(r,s,b,f);apply(r,mix(pa,pb,w));s.render.filepath=str(folder/(gait+'_'+label+'_'+str(phi)+'_'+str(w)+'.png'));bpy.ops.render.render(write_still=True)
 for gait,period in PERIOD.items():
  for view in ['Front','Rear','Side']:
   s.camera=bpy.data.objects['R3_Detail_'+view]
   for d in ['Left','Right']:
    for phi in [0,.25,.5,.75]:
     sample(r,s,bpy.data.actions[gait+'_Turn'+d+'_Reference_V2'],1+phi*period);s.render.filepath=str(OUT/(gait+'_'+d+'_'+view+'_'+str(phi)+'.png'));bpy.ops.render.render(write_still=True)
print('R3_RENDER_DONE',flush=True)
