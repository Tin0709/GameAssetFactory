"""One-time color-space correction of this study's initial atlas only."""
import bpy
from pathlib import Path

out=Path(__file__).resolve().parent
assert Path(bpy.data.filepath).resolve() == (out/'grass_block_wind_v1.blend').resolve()
image=bpy.data.images['ENV_Atlas_64_Nearest']
data=list(image.pixels)
for i,c in enumerate(data):
    if i%4 != 3:
        data[i]=12.92*c if c<=.0031308 else 1.055*(c**(1/2.4))-.055
image.pixels.foreach_set(data)
image.update()
image.filepath_raw=str(out/'environment_atlas_64.png')
image.save()
image.pack()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/'grass_block_wind_v1.blend'))
bpy.context.scene.render.filepath=str(out/'preview_hero.png')
bpy.ops.render.render(write_still=True)
print('ATLAS_CORRECTED')
