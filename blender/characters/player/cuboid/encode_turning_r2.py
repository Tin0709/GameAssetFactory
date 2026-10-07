"""Encode the composed PNG reel using Blender's bundled H.264 encoder; no asset save."""
import bpy
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'turning_study_r2_review';folder=OUT/'ab_frames'
assert all((folder/('%04d.png'%f)).exists() for f in range(1,457))
s=bpy.data.scenes.new('TEMP_R2_Encode');bpy.context.window.scene=s
ed=s.sequence_editor_create();strips=ed.strips if hasattr(ed,'strips') else ed.sequences
strip=strips.new_image('R2_AB_Reel',str(folder/'0001.png'),channel=1,frame_start=1)
for f in range(2,457):strip.elements.append('%04d.png'%f)
s.render.resolution_x=960;s.render.resolution_y=1080;s.render.resolution_percentage=100
s.render.fps=24;s.render.fps_base=1;s.frame_start=1;s.frame_end=456;s.render.use_sequencer=True
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE'
s.render.filepath=str(OUT/'turning_AB_24fps.mp4')
# PNGs are display-referred images; avoid a second AgX contrast transform.
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
bpy.ops.render.render(animation=True)
print('R2_H264_DONE',flush=True)
