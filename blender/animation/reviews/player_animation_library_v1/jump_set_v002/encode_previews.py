"""Encode rendered frames with Blender's bundled H.264, without saving a scene."""
import bpy,json
from pathlib import Path
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/jump_set_v002'
metadata=json.loads((OUT/'references.json').read_text(encoding='utf-8'))
for kind,info in metadata.items():
    p=info['preview'];sc=bpy.data.scenes.new('Encode_'+kind);bpy.context.window.scene=sc
    folder=TMP/'encode'/kind;ed=sc.sequence_editor_create()
    strip=ed.strips.new_image(kind,str(folder/'0001.png'),channel=1,frame_start=1)
    for f in range(2,p['frames']+1):strip.elements.append(f'{f:04d}.png')
    sc.render.resolution_x,sc.render.resolution_y=p['size'];sc.render.resolution_percentage=100
    sc.render.fps=30;sc.render.fps_base=1;sc.frame_start=1;sc.frame_end=p['frames']
    sc.render.use_sequencer=True;sc.render.image_settings.media_type='VIDEO'
    sc.render.image_settings.file_format='FFMPEG';sc.render.ffmpeg.format='MPEG4';sc.render.ffmpeg.codec='H264'
    sc.render.ffmpeg.constant_rate_factor='HIGH';sc.render.ffmpeg.ffmpeg_preset='GOOD';sc.render.ffmpeg.audio_codec='NONE'
    sc.view_settings.view_transform='Standard';sc.view_settings.look='None'
    sc.render.filepath=str(OUT/p['file']);bpy.ops.render.render(animation=True)
print('JUMP_SET_VIDEOS_ENCODED')
