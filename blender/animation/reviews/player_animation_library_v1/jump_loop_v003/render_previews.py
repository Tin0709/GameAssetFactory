"""Render actual continuous three-cycle scenes; no holds or cuts."""
import bpy,json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;M=json.loads((OUT/'manifest.json').read_text())
for kind,c in M['cases'].items():
    sc=bpy.data.scenes[c['scene']];bpy.context.window.scene=sc
    sc.render.resolution_x=640;sc.render.resolution_y=480;sc.render.resolution_percentage=100
    sc.cycles.samples=12;sc.render.image_settings.file_format='PNG'
    for view,direction in [('gameplay','THREE_QUARTER'),('side','SIDE')]:
        sc.camera=bpy.data.objects[c['cameras'][direction]]
        folder=OUT.parents[4]/'.validation/jump_loop_v003/frames'/kind/view;folder.mkdir(parents=True,exist_ok=True)
        frames=[1,1+c['take'],1+(c['take']+c['land'])//2,1+c['land']] if '--poses-only' in sys.argv else range(1,c['preview_end']+1)
        for f in frames:
            path=folder/f'{f:03d}.png'
            if path.exists() and '--force' not in sys.argv:continue
            sc.frame_set(f);sc.render.filepath=str(path);bpy.ops.render.render(write_still=True)
print('LOOP_PREVIEWS_COMPLETE')
