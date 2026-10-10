import bpy,runpy,json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;V=runpy.run_path(str(OUT/'review_scene.py'))
s=bpy.context.scene;r=bpy.data.objects['JL_Test_Rig'];data=json.loads((OUT/'manifest.json').read_text())
s.render.use_persistent_data=True
keys=[1,6,9,11,16,20,26,34,40,44]
for mode in ['landing','sequence']:
    priorities=keys if mode=='landing' else [24,45,46,50,53,55,60,64,70,78,84,88]
    fs=priorities if 'keys' in sys.argv else priorities+[f for f in range(1,45 if mode=='landing' else 89) if f not in priorities]
    for view in ['FRONT','THREE_QUARTER','SIDE']:
        s.camera=bpy.data.objects['Showcase_'+view];folder=OUT/'frames'/mode/view.lower();folder.mkdir(parents=True,exist_ok=True)
        for f in fs:
            path=folder/f'{f:03d}.png'
            if path.exists():continue
            if mode=='landing':
                bpy.data.objects['Showcase_FixedFloor'].location.z=0;r.location=(0,0,0);V['bind'](s,r,'Jump_Landing_Test',f)
            else:V['sequence'](s,r,f)
            s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        print('RENDERED',mode,view,flush=True)
