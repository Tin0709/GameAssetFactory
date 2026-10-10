"""Render a separate impact study using the unchanged comparison stage."""
import bpy,runpy,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;V=runpy.run_path(str(OUT/'review_scene.py'))
s=bpy.context.scene;r=bpy.data.objects['JI_Test_Rig'];s.render.use_persistent_data=True
keys=[1,6,9,10,14,18,26,30,42,52,56]
bpy.data.objects['Showcase_FixedFloor'].location.z=0;r.location=(0,0,0)
for batch in [keys,[] if 'keys' in sys.argv else [f for f in range(1,57) if f not in keys]]:
    for view in ['FRONT','THREE_QUARTER','SIDE']:
        s.camera=bpy.data.objects['Showcase_'+view];folder=OUT/'frames/impact'/view.lower();folder.mkdir(parents=True,exist_ok=True)
        for f in batch:
            path=folder/f'{f:03d}.png'
            if path.exists():continue
            V['bind'](s,r,'Jump_Landing_Impact_Test',f);s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        print('RENDERED',view,len(batch),flush=True)
# Re-render one baseline sample to independently check the retained stage/action.
s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];V['bind'](s,r,'Jump_Landing_Test',16)
s.render.filepath=str(OUT/'baseline_recheck.png');bpy.ops.render.render(write_still=True)
