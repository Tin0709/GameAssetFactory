"""Encode actual Godot Movie Maker pixels; no asset rendering or .blend save.

Run with Blender --background --factory-startup --python this_file.
"""
from pathlib import Path
import json
import bpy

root = Path(__file__).resolve().parents[1] / '.validation' / 'flower_patch_v1'
metadata = json.loads((root / 'movie.json').read_text(encoding='utf-8'))
scene = bpy.context.scene
scene.sequence_editor_create()
strip = scene.sequence_editor.strips.new_movie('Actual Godot flower passage', str(root / 'gameplay.avi'), channel=1, frame_start=1)
scene.frame_start = 1
scene.frame_end = min(strip.frame_duration, metadata['last_content_frame'])
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.fps = 30
scene.render.use_sequencer = True
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.render.image_settings.media_type = 'VIDEO'
scene.render.image_settings.file_format = 'FFMPEG'
scene.render.ffmpeg.format = 'MPEG4'
scene.render.ffmpeg.codec = 'H264'
scene.render.ffmpeg.constant_rate_factor = 'HIGH'
scene.render.ffmpeg.ffmpeg_preset = 'GOOD'
scene.render.ffmpeg.audio_codec = 'NONE'
scene.render.filepath = str(root / 'gameplay.mp4')
bpy.ops.render.render(animation=True)
metadata['encoded_frames'] = scene.frame_end
metadata['seconds'] = scene.frame_end / 30
(root / 'encoded.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
print('FLOWER_VIDEO_ENCODED', scene.frame_end, flush=True)
