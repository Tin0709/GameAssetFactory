import bpy,json
from pathlib import Path
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/jump_loop_v003'
meta=json.loads((OUT/'media_manifest.json').read_text())
for kind,p in meta['previews'].items():
    sc=bpy.data.scenes.new('EncodeLoop_'+kind);bpy.context.window.scene=sc
    folder=TMP/'encode'/kind;ed=sc.sequence_editor_create()
    strip=ed.strips.new_image(kind,str(folder/'0001.png'),channel=1,frame_start=1)
    for f in range(2,p['frames']+1):strip.elements.append(f'{f:04d}.png')
    sc.render.resolution_x,sc.render.resolution_y=p['size'];sc.render.resolution_percentage=100
    sc.render.fps=30;sc.render.fps_base=1;sc.frame_start=1;sc.frame_end=p['frames']
    sc.render.use_sequencer=True;sc.render.image_settings.media_type='VIDEO'
    sc.render.image_settings.file_format='FFMPEG';sc.render.ffmpeg.format='MPEG4';sc.render.ffmpeg.codec='H264'
    sc.render.ffmpeg.constant_rate_factor='HIGH';sc.render.ffmpeg.ffmpeg_preset='GOOD';sc.render.ffmpeg.audio_codec='NONE'
    sc.view_settings.view_transform='Standard';sc.view_settings.look='None';sc.render.filepath=str(OUT/p['file'])
    bpy.ops.render.render(animation=True)
print('LOOP_VIDEOS_ENCODED')
