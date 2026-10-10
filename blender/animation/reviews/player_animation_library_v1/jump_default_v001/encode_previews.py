"""Use Blender's bundled H.264 encoder; no project/scene mutation is saved."""
import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
for label in ['gameplay','side']:
    scene=bpy.data.scenes.new('EncodeJump_'+label);bpy.context.window.scene=scene
    folder=ROOT/'.validation/jump_default_v001/encode'/label
    editor=scene.sequence_editor_create()
    strip=editor.strips.new_image(label,str(folder/'0001.png'),channel=1,frame_start=1)
    for f in range(2,166):strip.elements.append(f'{f:04d}.png')
    scene.render.resolution_x=960;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
    scene.render.fps=30;scene.render.fps_base=1;scene.frame_start=1;scene.frame_end=165
    scene.render.use_sequencer=True;scene.render.image_settings.media_type='VIDEO'
    scene.render.image_settings.file_format='FFMPEG';scene.render.ffmpeg.format='MPEG4'
    scene.render.ffmpeg.codec='H264';scene.render.ffmpeg.constant_rate_factor='HIGH'
    scene.render.ffmpeg.ffmpeg_preset='GOOD';scene.render.ffmpeg.audio_codec='NONE'
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    scene.render.filepath=str(OUT/f'jump_{label}_1x.mp4')
    bpy.ops.render.render(animation=True)
print('JUMP_VIDEOS_ENCODED')
