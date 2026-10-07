"""Reuse live Blender preview rendering, one job per MCP invocation."""
from living_r9w2_common import *
OUT=BASE/'living_r9w3_review';job=globals().get('JOB','SWEEP')
s=bpy.data.scenes['R9W3_REVIEW_'+job];bpy.context.window.scene=s
s.render.resolution_percentage=100;s.eevee.taa_render_samples=16
if globals().get('STILL',False):
    s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
    s.frame_set(191,subframe=.5);s.render.filepath=str(OUT/(job.lower()+'_AB_f191_5.png'));bpy.ops.render.render(write_still=True)
else:
    s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG'
    s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE'
    s.render.filepath=str(OUT/(job.lower()+'_AB_24fps.mp4'));bpy.ops.render.render(animation=True)
result={'rendered':s.render.filepath,'fps':s.render.fps,'frame_range':[s.frame_start,s.frame_end]}
