"""Refresh this study's packed bytes from the corrected standalone atlas."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve()==(OUT/'grass_block_wind_v1.blend').resolve()
old=bpy.data.images['ENV_Atlas_64_Nearest']
old.name='STALE_Atlas_Initial'
image=bpy.data.images.load(str(OUT/'environment_atlas_64.png'),check_existing=False)
image.name='ENV_Atlas_64_Nearest'
image.colorspace_settings.name='sRGB'
for mat in bpy.data.materials:
    if mat.use_nodes:
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image==old:
                node.image=image
bpy.data.images.remove(old)
image.pack()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'grass_block_wind_v1.blend'))
bpy.context.scene.render.filepath=str(OUT/'preview_hero.png')
bpy.ops.render.render(write_still=True)
print('CORRECTED_ATLAS_PACKED_FROM_DISK')
