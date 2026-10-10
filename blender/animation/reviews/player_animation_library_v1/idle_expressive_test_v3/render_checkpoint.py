"""Current-source stance checkpoint and original-speed stronger-breath preview."""
import bpy,sys,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
s=bpy.context.scene;r=bpy.data.objects['IEV3_Test_Rig'];a=bpy.data.actions['Idle_Expressive_Test_v3']
v={'sampled_source_sha256':sha(Path(bpy.data.filepath)),'sampled_action_sha256':ui.action_signature(a)} if 'authoring' in sys.argv else json.loads((OUT/'validation.json').read_text())
if 'authoring' not in sys.argv:assert v['passed']
assert sha(Path(bpy.data.filepath))==v['sampled_source_sha256'] and ui.action_signature(a)==v['sampled_action_sha256']
r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s.render.use_persistent_data=True
folder=OUT/'checkpoint_frames';folder.mkdir(exist_ok=True)
stamp={'source_sha256':v['sampled_source_sha256'],'action_sha256':v['sampled_action_sha256'],'fps':30,'range':[1,240],'presentation':'Current saved source, original cameras/lights/materials. Three-view stance stills; eight-second three-quarter motion checkpoint. Full polished comparison package deferred for requested stance review.'}
if any(folder.iterdir()):
 saved=json.loads((OUT/'checkpoint_provenance.json').read_text())
 assert saved['source_sha256']==stamp['source_sha256'] and saved['action_sha256']==stamp['action_sha256']
 assert all(sha(OUT/p)==h for p,h in saved.get('frames',{}).items()),'Stance still changed before reuse'
(OUT/'checkpoint_provenance.json').write_text(json.dumps(stamp,indent=2))
for view in ['FRONT','THREE_QUARTER','SIDE']:
 s.camera=bpy.data.objects['Showcase_'+view]
 for f in [1,61]:
  if (folder/f'{view.lower()}_{f:04d}.png').exists():continue
  s.frame_set(f);s.render.filepath=str(folder/f'{view.lower()}_{f:04d}.png');bpy.ops.render.render(write_still=True)
print('THREE VIEW STANCE STILLS READY',flush=True)
stamp['frames']={p.relative_to(OUT).as_posix():sha(p) for p in folder.glob('*.png')};stamp['stills_complete']=len(stamp['frames'])==6;stamp['complete']=False
(OUT/'checkpoint_provenance.json').write_text(json.dumps(stamp,indent=2))
if 'stills' in sys.argv:raise SystemExit
s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];motion=folder/'three_quarter';motion.mkdir()
for f in range(1,241):
 p=motion/f'{f:04d}.png'
 if f in [1,61]:
  import shutil;shutil.copy2(folder/f'three_quarter_{f:04d}.png',p)
 else:
  s.frame_set(f);s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
assert sha(Path(bpy.data.filepath))==stamp['source_sha256']
final_validation=json.loads((OUT/'validation.json').read_text())
assert final_validation['passed'] and final_validation['sampled_source_sha256']==stamp['source_sha256'] and final_validation['sampled_action_sha256']==stamp['action_sha256'],'Current saved-source validation must pass before publishing motion'
stamp['frames']={p.relative_to(OUT).as_posix():sha(p) for p in folder.rglob('*.png')};stamp['complete']=len(stamp['frames'])==246
(OUT/'checkpoint_provenance.json').write_text(json.dumps(stamp,indent=2));assert stamp['complete']
print('CHECKPOINT RENDER COMPLETE',flush=True)
