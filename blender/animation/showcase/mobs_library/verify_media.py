"""Verify encoded FPS/count and decode first/middle/last frames through Blender."""
import bpy,json,warnings
from pathlib import Path
warnings.filterwarnings('ignore',category=DeprecationWarning)
HERE=Path(__file__).resolve().parent
expected=[]
for r in json.loads((HERE/'motion_manifest.json').read_text()):expected.append((Path(r['output']),r['frames']*3))
for r in json.loads((HERE/'comparison_manifest.json').read_text()):expected.append((Path(r['output']),r['frames']))
for r in json.loads((HERE/'source_research/media_manifest.json').read_text()):expected.append((Path(r['output']),r['frames']*(2 if r['kind']=='Idle' else 1)))
qa=HERE/'decoded_media';qa.mkdir(exist_ok=True);records=[]
for path,count in expected:
    assert path.exists(),path
    s=bpy.data.scenes.new('Decode '+path.stem);s.render.fps=30;s.render.resolution_x=192;s.render.resolution_y=192;s.render.resolution_percentage=100
    s.render.use_sequencer=True;s.render.use_compositing=False;s.view_settings.view_transform='Standard';s.view_settings.look='None'
    strip=s.sequence_editor_create().strips.new_movie('Encoded review',str(path),channel=1,frame_start=1)
    assert abs(strip.fps-30)<1e-6 and strip.frame_final_duration==count,(path,strip.fps,strip.frame_final_duration,count)
    for f in [1,count//2,count]:
        s.frame_set(f);s.render.filepath=str(qa/f'{path.stem}_{f:04}.png');bpy.ops.render.render(write_still=True,scene=s.name)
    records.append({'file':str(path),'fps':strip.fps,'frames':count,'duration_s':count/30,'decoded_samples':[1,count//2,count]})
    bpy.data.scenes.remove(s)
(HERE/'validation_media.json').write_text(json.dumps({'passed':True,'videos':records},indent=2))
print('MEDIA_VALIDATION_PASS',len(records),'videos',flush=True)
