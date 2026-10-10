"""Encode actual frames in a temporary foreground Blender scene, then remove it."""
import bpy
from pathlib import Path

OUT = Path(__file__).resolve().parent
TMP = OUT.parents[4] / '.validation/jump_dungeons_gif_v004/encode'


def run():
    assert not bpy.app.background
    original = bpy.context.window.scene
    scene = bpy.data.scenes.new('JGIF4_TEMP_VIDEO_ENCODE')
    try:
        bpy.context.window.scene = scene
        editor = scene.sequence_editor_create()
        strip = editor.strips.new_image('Actual rendered frames', str(TMP / '0001.png'), channel=1, frame_start=1)
        for frame in range(2, 109):
            strip.elements.append(f'{frame:04d}.png')
        scene.render.resolution_x, scene.render.resolution_y = 1280, 736
        scene.render.resolution_percentage = 100
        scene.render.fps, scene.render.fps_base = 30, 1
        scene.frame_start, scene.frame_end = 1, 108
        scene.render.use_sequencer = True
        scene.render.image_settings.media_type = 'VIDEO'
        scene.render.image_settings.file_format = 'FFMPEG'
        scene.render.ffmpeg.format = 'MPEG4'
        scene.render.ffmpeg.codec = 'H264'
        scene.render.ffmpeg.constant_rate_factor = 'HIGH'
        scene.render.ffmpeg.ffmpeg_preset = 'GOOD'
        scene.render.ffmpeg.audio_codec = 'NONE'
        scene.view_settings.view_transform = 'Standard'
        scene.view_settings.look = 'None'
        scene.render.filepath = str(OUT / 'jump_land_1x.mp4')
        bpy.ops.render.render(animation=True, scene=scene.name)
    finally:
        bpy.context.window.scene = original
        bpy.data.scenes.remove(scene)
    return str(OUT / 'jump_land_1x.mp4')
