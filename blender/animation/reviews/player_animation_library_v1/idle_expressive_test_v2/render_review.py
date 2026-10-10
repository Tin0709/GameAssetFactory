"""Matched original review stage; v1 images reused only after exact source validation."""
import bpy,sys,json
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene;r=bpy.data.objects['IEV2_Test_Rig'];a=bpy.data.actions['Idle_Expressive_Test_v2']
s.render.use_persistent_data=True;r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
keys=[1,25,49,65,90,115,146,158,181,218,240]
for view in ['FRONT','THREE_QUARTER','SIDE']:
    s.camera=bpy.data.objects['Showcase_'+view];folder=OUT/'frames'/view.lower();folder.mkdir(parents=True,exist_ok=True)
    for f in keys if 'keys' in sys.argv else keys+[f for f in range(1,241) if f not in keys]:
        p=folder/f'{f:03d}.png'
        if p.exists():continue
        s.frame_set(f);s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
    print('RENDERED V2',view,flush=True)
