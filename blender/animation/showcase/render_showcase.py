import bpy,json
from pathlib import Path
import gaf_animation_library as ui
OUT=Path(__file__).resolve().parent
s=bpy.context.scene;s.camera=bpy.data.objects['Showcase_THREE_QUARTER']
for index,frame in [(0,14),(1,8),(2,18)]:
    s.gaf_active_index=index;ui.activate(s,index);s.frame_set(frame)
    s.render.filepath=str(OUT/f'preview_{index+1}.png')
    bpy.ops.render.render(write_still=True)
print('SHOWCASE REVIEW RENDERS COMPLETE',flush=True)
