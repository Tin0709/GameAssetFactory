"""Saved-source, matching-camera attention poses for three-view review."""
import bpy,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
v=json.loads((OUT/'validation.json').read_text());assert v['passed'] and sha(Path(bpy.data.filepath))==v['sampled_source_sha256']
s=bpy.context.scene;folder=OUT/'attention_frames';folder.mkdir();s.render.use_persistent_data=True
for view in ['FRONT','THREE_QUARTER','SIDE']:
 s.camera=bpy.data.objects['Showcase_'+view]
 for frame in [32,70,92,120]:
  s.frame_set(frame);s.render.filepath=str(folder/f'{view.lower()}_{frame:04d}.png');bpy.ops.render.render(write_still=True)
assert sha(Path(bpy.data.filepath))==v['sampled_source_sha256']
stamp={'source_sha256':v['sampled_source_sha256'],'action_sha256':v['sampled_action_sha256'],'frames':{p.name:sha(p) for p in folder.glob('*.png')},'views':['front','three_quarter','side'],'poses':[32,70,92,120],'original_cameras_lights_materials':True};assert len(stamp['frames'])==12
(OUT/'attention_provenance.json').write_text(json.dumps(stamp,indent=2));print('THREE VIEW ATTENTION POSES READY',flush=True)
