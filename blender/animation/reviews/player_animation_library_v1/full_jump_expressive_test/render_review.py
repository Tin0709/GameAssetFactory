"""Render the separate Blender-only preview, never save it into the library."""
import bpy,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene
assert bpy.data.filepath.endswith('full_jump_preview.blend')
s.render.use_persistent_data=True
keys=[1,7,9,14,19,24,29,33,38,43,46,47,51,55,67,80,89,93]
for batch in [keys,[] if 'keys' in sys.argv else [f for f in range(1,94) if f not in keys]]:
    for view in ['FRONT','THREE_QUARTER','SIDE']:
        s.camera=bpy.data.objects['Showcase_'+view];folder=OUT/'frames'/view.lower();folder.mkdir(parents=True,exist_ok=True)
        for f in batch:
            path=folder/f'{f:03d}.png'
            if path.exists():continue
            s.frame_set(f);s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        print('RENDERED FULL JUMP',view,len(batch),flush=True)
