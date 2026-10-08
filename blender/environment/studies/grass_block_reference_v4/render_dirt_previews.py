import bpy
from pathlib import Path
STUDY=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(STUDY/'grass_block_reference_v4.blend'))
for name,scene_name in [('preview_dirt','ENV_Dirt_Block_Reference_V4'),('preview_grass_dirt_pair','ENV_Grass_Dirt_Pair_V4')]:
    scene=bpy.data.scenes[scene_name];bpy.context.window.scene=scene
    scene.frame_set(1);scene.render.filepath=str(STUDY/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('V4_DIRT_PREVIEW_READY '+name)
