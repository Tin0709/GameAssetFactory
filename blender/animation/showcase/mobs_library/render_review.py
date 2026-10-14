import bpy,json,sys,math
from pathlib import Path
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT));import gaf_mobs_animation_library as lib
lib.register();bpy.ops.wm.open_mainfile(filepath=str((OUT.parent if OUT.parent.name=='showcase' else OUT)/'Mobs_Animation_Library.blend'))
s=bpy.context.scene;r=bpy.data.objects['Zombie_Cuboid_Rig']
s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100
s.cycles.samples=12
review=OUT/'review';review.mkdir(exist_ok=True)
for i,kind in enumerate(['Idle','Walk']):
    s.mobs_active_index=i;lib.activate(s)
    for view in ['THREE_QUARTER','SIDE','FRONT']:
        s.camera=bpy.data.objects['Mobs Camera '+view]
        for phase in range(8):
            f=1+phase*s.frame_end/8;s.frame_set(math.floor(f),subframe=f%1)
            s.render.filepath=str(review/f'{kind}_{view}_{phase:02}.png')
            bpy.ops.render.render(write_still=True)
print('REVIEW_STILLS_COMPLETE')
