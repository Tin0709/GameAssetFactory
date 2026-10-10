"""Render only; never save changes to the source library."""
import bpy,json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent
M=json.loads((OUT/'manifest.json').read_text())
base=OUT.parents[4]/'.validation/jump_set_v002/frames'
for kind,c in M['cases'].items():
    sc=bpy.data.scenes[c['scene']];bpy.context.window.scene=sc
    sc.render.resolution_x=720;sc.render.resolution_y=540;sc.render.resolution_percentage=100
    sc.cycles.samples=16;sc.render.image_settings.file_format='PNG'
    for view,direction in [('gameplay','THREE_QUARTER'),('side','SIDE')]:
        folder=base/kind/view;folder.mkdir(parents=True,exist_ok=True)
        sc.camera=bpy.data.objects[c['cameras'][direction]]
        frames=[(c['take']+c['land'])//2] if '--apex-only' in sys.argv else range(1,c['end']+1)
        for f in frames:
            path=folder/f'{f:03d}.png'
            if path.exists() and '--force' not in sys.argv:continue
            sc.frame_set(f);sc.render.filepath=str(path);bpy.ops.render.render(write_still=True)
print('JUMP_SET_RENDERS_COMPLETE')
