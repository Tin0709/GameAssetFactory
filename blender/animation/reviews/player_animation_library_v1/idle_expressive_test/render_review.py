"""Same stage/cameras for expressive loop and original native-speed Idle."""
import bpy,json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene;r=bpy.data.objects['IE_Test_Rig'];s.render.use_persistent_data=True
a=bpy.data.actions['Idle_Expressive_Test'];candidate='candidate' in sys.argv;data=json.loads((OUT/('lookaround_manifest.json' if candidate else 'manifest.json')).read_text());P=data['playback_frames'][1];mode='new_lookaround' if candidate else 'new';keys=[1,22,30,37,52,62,72,90,109,124,P]
for batch in ([] if 'old_only' in sys.argv else [keys,[] if 'keys' in sys.argv else [f for f in range(1,P+1) if f not in keys]]):
    for view in ['FRONT','THREE_QUARTER','SIDE']:
        s.camera=bpy.data.objects['Showcase_'+view];folder=OUT/'frames'/mode/view.lower();folder.mkdir(parents=True,exist_ok=True)
        for f in batch:
            p=folder/f'{f:03d}.png'
            if p.exists():continue
            r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s.frame_set(f);s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
        print('RENDERED EXPRESSIVE IDLE',view,len(batch),flush=True)
old=json.loads((OUT/'old_idle_baseline.json').read_text());r.animation_data.action=None
for view in ['FRONT','THREE_QUARTER','SIDE']:
    s.camera=bpy.data.objects['Showcase_'+view]
    for i,sample in enumerate(old['samples'],1):
        p=OUT/'frames/old'/view.lower()/f'{i:03d}.png';p.parent.mkdir(parents=True,exist_ok=True)
        if p.exists():continue
        for b in r.pose.bones:
            for k,v in sample['pose'][b.name].items():setattr(b,k,v)
        r.update_tag();bpy.data.objects['IE_Test_Mesh'].update_tag();bpy.context.view_layer.update()
        s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
    print('RENDERED ORIGINAL IDLE AT NATIVE SPEED',view,len(old['samples']),flush=True)
