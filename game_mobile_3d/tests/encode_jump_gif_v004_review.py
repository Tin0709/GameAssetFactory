"""Package real Godot pixels in the connected foreground Blender only."""
import bpy
from pathlib import Path

def run():
    assert not bpy.app.background
    folder=Path(__file__).resolve().parents[1]/'.validation/jump_gif_v004'
    original=bpy.context.window.scene
    scene=bpy.data.scenes.new('JGIF4_TEMP_RUNTIME_ENCODE')
    try:
        bpy.context.window.scene=scene
        strip=scene.sequence_editor_create().strips.new_movie('Actual WorldMap capture',str(folder/'gameplay.avi'),channel=1,frame_start=1)
        scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
        scene.render.fps=30;scene.render.fps_base=1
        scene.frame_start=1;scene.frame_end=strip.frame_final_end-1
        scene.render.use_sequencer=True
        scene.render.image_settings.media_type='VIDEO';scene.render.image_settings.file_format='FFMPEG'
        scene.render.ffmpeg.format='MPEG4';scene.render.ffmpeg.codec='H264'
        scene.render.ffmpeg.constant_rate_factor='HIGH';scene.render.ffmpeg.ffmpeg_preset='GOOD'
        scene.render.ffmpeg.audio_codec='NONE'
        scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
        scene.render.filepath=str(folder/'gameplay.mp4')
        bpy.ops.render.render(animation=True,scene=scene.name)
    finally:
        bpy.context.window.scene=original;bpy.data.scenes.remove(scene)
    return str(folder/'gameplay.mp4')
