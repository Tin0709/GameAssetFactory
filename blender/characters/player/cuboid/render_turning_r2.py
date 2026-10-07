import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
assert Path(bpy.data.filepath)==DEV
draft='--draft' in sys.argv
frames=[13,37,61,85,109,145,181,229,265,289,313,337,361,397,421,445] if draft else range(1,457)
if '--game-only' in sys.argv:frames=[]
for gait in PERIOD:
    for variant in ['A','B']:
        s=bpy.data.scenes['R2_'+gait+'_'+variant];bpy.context.window.scene=s
        folder=OUT/(gait.lower()+'_'+variant.lower());folder.mkdir(exist_ok=True)
        for f in frames:
            s.frame_set(f);s.render.filepath=str(folder/('%04d.png'%f));bpy.ops.render.render(write_still=True)
        print('R2_RENDERED '+gait+' '+variant,flush=True)
s=bpy.data.scenes['R2_Review_Gameplay'];bpy.context.window.scene=s
for f in [37,109,181,265,289,313,397,445]:
    s.frame_set(f);s.render.filepath=str(OUT/('gameplay_%04d.png'%f));bpy.ops.render.render(write_still=True)
print('R2_RENDER_DONE',flush=True)
