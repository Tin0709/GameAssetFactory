import bpy,runpy,json,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;V=runpy.run_path(str(OUT/'review_scene.py'))
s=bpy.context.scene;r=bpy.data.objects['AP_Test_Rig'];data=json.loads((OUT/'manifest.json').read_text())
keys=[1,4,7,9,13,16,19,22]
for mode in ['air','sequence']:
    fs=(keys if mode=='air' else [1,14,19,24,27,30,36,39,45]) if 'keys' in sys.argv else range(1,23 if mode=='air' else 46)
    for view in ['FRONT','THREE_QUARTER','SIDE']:
        s.camera=bpy.data.objects['Showcase_'+view];folder=OUT/'frames'/mode/view.lower();folder.mkdir(parents=True,exist_ok=True)
        for f in fs:
            path=folder/f'{f:03d}.png'
            if path.exists():continue
            if mode=='air':
                bpy.data.objects['Showcase_FixedFloor'].location.z=-data['preview_offset_m'][2];r.location=(0,0,0);V['bind'](s,r,'Jump_AirPose_Test',f)
            else:V['sequence'](s,r,f,data)
            s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        print('RENDERED',mode,view,flush=True)
boundary=OUT/'boundary_air_first.png'
if not boundary.exists():
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];bpy.data.objects['Showcase_FixedFloor'].location.z=0
    r.location=V['preview_offset'](1,data);V['bind'](s,r,'Jump_AirPose_Test',1)
    s.render.filepath=str(boundary);bpy.ops.render.render(write_still=True)
