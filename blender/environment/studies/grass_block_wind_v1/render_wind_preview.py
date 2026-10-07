"""Render one tuft loop; does not save changes to the Blender file."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
scene=bpy.context.scene
scene.camera=bpy.data.objects['REVIEW_Camera_Grass_Detail']
scene.render.resolution_x=640
scene.render.resolution_y=640
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
frames=OUT/'wind_frames'
frames.mkdir(exist_ok=True)
for frame in range(1,97,2):
    scene.frame_set(frame)
    scene.render.filepath=str(frames/f'{frame:03d}.png')
    bpy.ops.render.render(write_still=True)
print('WIND_FRAMES_READY')
