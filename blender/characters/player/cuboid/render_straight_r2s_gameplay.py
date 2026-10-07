import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent/'straight_study_r2s_review';folder=OUT/'gameplay_raw';folder.mkdir(exist_ok=True)
s=bpy.data.scenes['R2S_Gameplay_V1_V2'];bpy.context.window.scene=s
for i in range(208):
 s.frame_set(i+1);s.render.filepath=str(folder/('%04d.png'%(i+1)));bpy.ops.render.render(write_still=True)
print('R2S_GAMEPLAY_DONE',flush=True)
