import bpy
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'hold_r7w1_review'
s=bpy.data.scenes['R7W1_COMPARISON'];bpy.context.window.scene=s
s.render.resolution_x=1600;s.render.resolution_y=900
s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE'
s.render.fps=24;s.render.fps_base=1;s.frame_start=1;s.frame_end=48;s.render.filepath=str(OUT/'ABC_aim_24fps.mp4')
bpy.ops.render.render(animation=True)
print('R7W1_MOTION_RENDERED',flush=True)
