"""Render a source-bound cycle; encoding repeats only its17 unique frames."""
import bpy
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = Path(json.loads((OUT/'preservation_before.json').read_text())['project'])
scene = bpy.context.scene
rig = bpy.data.objects['Showcase_Player_Rig']
validation = json.loads((OUT / 'motion_validation.json').read_text())
assert validation['passed']
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest() == validation['source_sha256']
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.use_persistent_data = True
scene.render.image_settings.file_format = 'PNG'
scene.render.resolution_x = scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
proof = {'fps':30, 'unique_frames_per_cycle':17, 'cycles_in_final_videos':5,
         'source_sha256':validation['source_sha256'], 'views':{},
         'stage':'Same saved camera/light/materials for baseline and candidate;12 Cycles samples with denoising'}
for label, name in [('approved','Run_Snappy_Test_v001'),('candidate','Run_Original_Recovery_Test_v001')]:
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    for view in ['FRONT','THREE_QUARTER','SIDE']:
        scene.camera = bpy.data.objects['Showcase_' + view]
        dest = OUT / 'render' / label / view.lower()
        dest.mkdir(parents=True, exist_ok=True)
        proof['views'][label+'/'+view] = {'camera':list(map(list,scene.camera.matrix_world)), 'ortho_scale':scene.camera.data.ortho_scale}
        for frame in range(1,18):
            path = dest / f'{frame:03d}.png'
            if path.exists():
                continue
            scene.frame_set(frame)
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest() == validation['source_sha256']
(OUT/'render_provenance.json').write_text(json.dumps(proof,indent=2))
print('SOURCE_BOUND_RENDERS_COMPLETE 102',flush=True)
