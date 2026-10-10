"""Current-source stance checkpoint and original-speed stronger-breath preview."""
import bpy,sys,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
s=bpy.context.scene;r=bpy.data.objects['IEV3_Test_Rig'];a=bpy.data.actions['Idle_Expressive_Test_v3']
v=json.loads((OUT/'validation.json').read_text());assert v['passed']
assert sha(Path(bpy.data.filepath))==v['sampled_source_sha256'] and ui.action_signature(a)==v['sampled_action_sha256']
r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s.render.use_persistent_data=True
folder=OUT/'checkpoint_frames';folder.mkdir(exist_ok=True)
stamp={'source_sha256':v['sampled_source_sha256'],'action_sha256':v['sampled_action_sha256'],'fps':30,'range':[1,240],'presentation':'Current saved source, original cameras/lights/materials. Three-view stance stills; eight-second three-quarter motion checkpoint. Full polished comparison package deferred for requested stance review.'}
assert not any(folder.iterdir()),'Archive old checkpoint frames before rendering'
(OUT/'checkpoint_provenance.json').write_text(json.dumps(stamp,indent=2))
for view in ['FRONT','THREE_QUARTER','SIDE']:
 s.camera=bpy.data.objects['Showcase_'+view]
 for f in [1,61]:
  s.frame_set(f);s.render.filepath=str(folder/f'{view.lower()}_{f:04d}.png');bpy.ops.render.render(write_still=True)
print('THREE VIEW STANCE STILLS READY',flush=True)
s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];motion=folder/'three_quarter';motion.mkdir()
for f in range(1,241):
 p=motion/f'{f:04d}.png'
 if f in [1,61]:
  import shutil;shutil.copy2(folder/f'three_quarter_{f:04d}.png',p)
 else:
  s.frame_set(f);s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
assert sha(Path(bpy.data.filepath))==stamp['source_sha256']
stamp['frames']={p.relative_to(OUT).as_posix():sha(p) for p in folder.rglob('*.png')};stamp['complete']=len(stamp['frames'])==246
(OUT/'checkpoint_provenance.json').write_text(json.dumps(stamp,indent=2));assert stamp['complete']
print('CHECKPOINT RENDER COMPLETE',flush=True)
