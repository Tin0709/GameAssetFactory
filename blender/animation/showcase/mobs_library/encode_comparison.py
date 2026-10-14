import bpy,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
for r in json.loads((OUT/'comparison_manifest.json').read_text()):
    s=bpy.data.scenes.new('Compare '+r['kind']);s.render.resolution_x=r['width'];s.render.resolution_y=r['height'];s.render.resolution_percentage=100
    s.render.fps=30;s.frame_start=1;s.frame_end=r['frames'];s.render.use_sequencer=True;s.render.use_compositing=False
    s.view_settings.view_transform='Standard';s.view_settings.look='None'
    strip=s.sequence_editor_create().strips.new_image('Compare',str(Path(r['folder'])/'0001.png'),channel=1,frame_start=1)
    for i in range(2,r['frames']+1):strip.elements.append(f'{i:04}.png')
    strip.frame_final_duration=r['frames']
    s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG'
    s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.filepath=r['output']
    bpy.ops.render.render(animation=True,scene=s.name);bpy.data.scenes.remove(s)
print('COMPARISON_VIDEOS_READY',flush=True)
