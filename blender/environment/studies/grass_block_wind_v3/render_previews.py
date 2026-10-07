import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
demo=bpy.data.scenes['ENV_Player_Reaction_Demo']
if bpy.context.window:bpy.context.window.scene=demo
demo.render.resolution_x=720;demo.render.resolution_y=720
demo.render.resolution_percentage=100
demo.render.image_settings.file_format='PNG'
frames=OUT/'player_demo_frames';frames.mkdir(exist_ok=True)
for frame in range(1,193,3):
    demo.frame_set(frame)
    demo.render.filepath=str(frames/f'{frame:03d}.png')
    bpy.ops.render.render(write_still=True,scene=demo.name)
print('PLAYER_DEMO_FRAMES_READY')
