import bpy,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene
keys=[1,7,9,14,17,19,20,24]
frames=keys if 'keys' in sys.argv else range(1,25)
for view in ['FRONT','THREE_QUARTER','SIDE']:
    s.camera=bpy.data.objects['Showcase_'+view]
    folder=OUT/'frames'/view.lower();folder.mkdir(parents=True,exist_ok=True)
    for f in frames:
        path=folder/f'{f:03d}.png'
        if path.exists():continue
        s.frame_set(f);s.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
    print('RENDERED',view,flush=True)
