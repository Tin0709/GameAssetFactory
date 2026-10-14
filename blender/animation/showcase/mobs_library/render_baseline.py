"""Existing original zombie clips, rendered read-only with the identical review camera."""
import bpy,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT));import gaf_mobs_animation_library as lib
bpy.ops.wm.open_mainfile(filepath=str((OUT.parent if OUT.parent.name=='showcase' else OUT)/'Mobs_Animation_Library.blend'))
s=bpy.context.scene;r=bpy.data.objects['Zombie_Cuboid_Rig']
source='/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation_v2/zombie_animation_v2.blend'
with bpy.data.libraries.load(source,link=False) as (src,dst):dst.actions=['Zombie_Idle','Zombie_Walk']
s.camera=bpy.data.objects['Mobs Camera THREE_QUARTER'];s.cycles.samples=8
s.render.resolution_x=448;s.render.resolution_y=448;s.render.resolution_percentage=100
for kind,N in [('Idle',90),('Walk',48)]:
    lib.reset_rig(r);a=bpy.data.actions['Zombie_'+kind]
    r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
    folder=OUT/'baseline_frames'/kind;folder.mkdir(parents=True,exist_ok=True)
    for f in range(1,N+1):
        path=folder/f'{f:04}.png'
        if path.exists():continue
        s.frame_set(f);s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
print('BASELINE_RENDERS_COMPLETE',flush=True)
