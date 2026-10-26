"""Use installed Blender's FFmpeg encoder; never touches an open Blender scene."""
from pathlib import Path
import json
import sys

import bpy


args = sys.argv[sys.argv.index("--") + 1:]
inspect_only = "--inspect" in args
args = [value for value in args if value != "--inspect"]
if len(args) != 2:
    raise SystemExit("Pass input AVI and output MP4 after --")
source, destination = (Path(value).resolve() for value in args)
if not source.is_file() or destination.suffix.lower() != ".mp4":
    raise SystemExit("Expected an existing AVI and an MP4 destination")
destination.parent.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
editor = scene.sequence_editor_create()
strip = editor.strips.new_movie("Native Godot Capture", str(source), channel=1, frame_start=1)
has_audio = False
try:
    editor.strips.new_sound("Original Sabre Sample Mix", str(source), channel=2, frame_start=1)
    has_audio = True
except RuntimeError:
    pass
scene.frame_start = 1
scene.frame_end = strip.frame_final_end - 1
scene.render.fps = round(strip.fps)
scene.render.fps_base = 1.0
scene.render.resolution_x = strip.elements[0].orig_width
scene.render.resolution_y = strip.elements[0].orig_height
scene.render.resolution_percentage = 100
scene.render.use_sequencer = True
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.render.image_settings.media_type = "VIDEO"
scene.render.image_settings.file_format = "FFMPEG"
scene.render.ffmpeg.format = "MPEG4"
scene.render.ffmpeg.codec = "H264"
scene.render.ffmpeg.constant_rate_factor = "MEDIUM"
scene.render.ffmpeg.ffmpeg_preset = "GOOD"
scene.render.ffmpeg.audio_codec = "AAC" if has_audio else "NONE"
scene.render.filepath = str(destination)
if not inspect_only:
    bpy.ops.render.render(animation=True)
report = {"frames": scene.frame_end, "fps": scene.render.fps, "width": scene.render.resolution_x,
          "height": scene.render.resolution_y, "output": str(destination), "inspect_only": inspect_only,
          "audio": has_audio,
          "bytes": destination.stat().st_size if destination.exists() else 0}
print("SABRE_MOVIE_ENCODE " + json.dumps(report))
