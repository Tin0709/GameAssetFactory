import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
TMP=OUT.parents[4]/'.validation/expressive_arm_motion_test/encode'
def run():
    original=bpy.context.window.scene
    s=bpy.data.scenes.new('EAM_TEMP_ENCODING')
    try:
        bpy.context.window.scene=s
        e=s.sequence_editor_create()
        strip=e.strips.new_image('Actual front and three-quarter renders',str(TMP/'0001.png'),channel=1,frame_start=1)
        for f in range(2,73):strip.elements.append(f'{f:04d}.png')
        s.render.resolution_x=1280;s.render.resolution_y=720;s.render.resolution_percentage=100
        s.render.fps=30;s.frame_start=1;s.frame_end=72;s.render.use_sequencer=True
        s.render.image_settings.media_type='VIDEO';s.render.image_settings.file_format='FFMPEG'
        s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH'
        s.render.ffmpeg.audio_codec='NONE';s.view_settings.view_transform='Standard';s.view_settings.look='None'
        s.render.filepath=str(OUT/'expressive_arm_motion_1x.mp4')
        bpy.ops.render.render(animation=True,scene=s.name)
    finally:
        bpy.context.window.scene=original;bpy.data.scenes.remove(s)
    return str(OUT/'expressive_arm_motion_1x.mp4')
