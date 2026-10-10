"""Read-only background rendering of the isolated review, never save the library."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
frames_dir=ROOT/'.validation/jump_default_v001/frames'
scene=bpy.data.scenes['JUMP_DEFAULT_V001_REVIEW'];bpy.context.window.scene=scene
scene.render.resolution_x=960;scene.render.resolution_y=900
scene.render.resolution_percentage=100;scene.cycles.samples=32
scene.render.image_settings.file_format='PNG'
for label,camera in [('gameplay','JD1_Gameplay'),('side','JD1_Side')]:
    folder=frames_dir/label;folder.mkdir(parents=True,exist_ok=True)
    scene.camera=bpy.data.objects[camera]
    for frame in range(1,26):
        scene.frame_set(frame)
        scene.render.filepath=str(folder/f'{frame:03d}.png')
        bpy.ops.render.render(write_still=True)
print('JUMP_PREVIEW_RENDERS_COMPLETE')
