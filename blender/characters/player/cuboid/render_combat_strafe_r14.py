"""Render one R14 review case. CASE and VIEWS supplied by live Blender caller."""
import bpy,json
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'combat_strafe_r14_review'
d=json.loads((OUT/'design.json').read_text());data=d['reviews'][CASE]
s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s
s.render.resolution_x=960;s.render.resolution_y=720;s.render.fps=24
targets=[o for o in s.objects if 'Enemy' in o.name]
for view in VIEWS:
    s.camera=bpy.data.objects[data['cameras'][view]]
    for o in targets:o.hide_render=view!='Gameplay'
    s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG'
    s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='MEDIUM';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE'
    s.render.filepath=str(OUT/f'{CASE}_{view}.mp4');bpy.ops.render.render(animation=True)
    s.frame_set(5 if CASE!='D' else 187);s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/f'{CASE}_{view}.png');bpy.ops.render.render(write_still=True)
for o in targets:o.hide_render=False
s.frame_set(1)
result={'case':CASE,'views':VIEWS,'frames_per_clip':s.frame_end}
