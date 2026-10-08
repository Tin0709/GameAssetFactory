"""Package actual Godot pixels. Run with Blender background; never saves a .blend."""
from pathlib import Path
import json
import sys
import bpy

study = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'quality_slice'
if study not in {'quality_slice', 'forest_quality'}:
    raise ValueError('Unknown review study')
root = Path(__file__).resolve().parents[1] / '.validation' / study
scene = bpy.context.scene
scene.sequence_editor_create()
strip = scene.sequence_editor.strips.new_movie('Godot real gameplay', str(root / 'gameplay.avi'), channel=1, frame_start=1)
scene.frame_start = 1
# Exclude teardown frames after the actual game scene is removed.
metadata = json.loads((root / 'movie.json').read_text(encoding='utf-8'))
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
# Decode movie frames for explicit visual inspection; no synthetic animation.
scene.render.image_settings.media_type = 'IMAGE'
scene.render.image_settings.file_format = 'PNG'
for frame in [1, 30, 45, 60, 80, 100, 120, 145, 170, 200, 230, 260]:
    scene.frame_set(frame)
    scene.render.filepath = str(root / f'movie_frame_{frame:03d}.png')
    bpy.ops.render.render(write_still=True)
print('QUALITY_VIDEO_ENCODED', scene.frame_end, flush=True)
