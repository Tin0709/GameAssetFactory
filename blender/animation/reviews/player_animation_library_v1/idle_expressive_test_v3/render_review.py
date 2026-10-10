"""Matched v2 review stage; strict source/Action/stage provenance for render reuse."""
import bpy,sys,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;s=bpy.context.scene;r=bpy.data.objects['IEV3_Test_Rig'];a=bpy.data.actions['Idle_Expressive_Test_v3']
s.render.use_persistent_data=True;r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
ROOT=OUT.parents[4];sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
validation=json.loads((OUT/'validation.json').read_text());assert validation['passed']
assert sha(Path(bpy.data.filepath))==validation['sampled_source_sha256'] and ui.action_signature(a)==validation['sampled_action_sha256']
settings={'resolution':[s.render.resolution_x,s.render.resolution_y,s.render.resolution_percentage],'engine':s.render.engine,'fps':s.render.fps,'color_management':[s.view_settings.view_transform,s.view_settings.look,s.view_settings.exposure,s.view_settings.gamma],'cameras':{v:{'matrix':[list(x) for x in bpy.data.objects['Showcase_'+v].matrix_world],'ortho_scale':bpy.data.objects['Showcase_'+v].data.ortho_scale} for v in ['FRONT','THREE_QUARTER','SIDE']}}
provenance={'source_sha256':validation['sampled_source_sha256'],'action_sha256':validation['sampled_action_sha256'],'settings':settings}
stamp=OUT/'render_provenance.json'
if stamp.exists():
    saved=json.loads(stamp.read_text());assert all(saved[k]==v for k,v in provenance.items()),'Render source/stage changed; archive frames before rerendering'
    assert all(sha(OUT/rel)==sig for rel,sig in saved.get('frames',{}).items()),'Previously rendered PNG changed'
else:
    assert not any((OUT/'frames').rglob('*.png')),'Unstamped PNGs cannot be reused'
provenance['frames']={}
stamp.write_text(json.dumps(provenance,indent=2))
keys=[1,25,49,65,90,115,146,158,181,218,240]
for view in ['FRONT','THREE_QUARTER','SIDE']:
    s.camera=bpy.data.objects['Showcase_'+view];folder=OUT/'frames'/view.lower();folder.mkdir(parents=True,exist_ok=True)
    for f in keys if 'keys' in sys.argv else keys+[f for f in range(1,241) if f not in keys]:
        p=folder/f'{f:03d}.png'
        if p.exists():continue
        s.frame_set(f);s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
    print('RENDERED V3',view,flush=True)

assert sha(Path(bpy.data.filepath))==provenance['source_sha256']
provenance['frames']={p.relative_to(OUT).as_posix():sha(p) for p in sorted((OUT/'frames').rglob('*.png'))}
provenance['complete']=len(provenance['frames'])==720
stamp.write_text(json.dumps(provenance,indent=2))
