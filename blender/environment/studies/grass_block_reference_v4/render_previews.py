"""Render actual saved Blender file, hero/detail and differing wind phase."""
import bpy
from pathlib import Path
STUDY=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(STUDY/'grass_block_reference_v4.blend'))
scene=bpy.data.scenes['ENV_Grass_Block_Reference_V4'];bpy.context.window.scene=scene
for name,camera,frame in [('preview_hero','REVIEW_Camera_Hero_V4',1),
                          ('preview_detail','REVIEW_Camera_Grass_Detail_V4',1),
                          ('preview_wind_phase','REVIEW_Camera_Grass_Detail_V4',25)]:
    scene.camera=bpy.data.objects[camera];scene.frame_set(frame)
    scene.render.filepath=str(STUDY/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('V4_PREVIEW_READY '+name)
