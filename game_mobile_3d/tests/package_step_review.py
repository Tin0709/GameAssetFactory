"""Encode/decode actual Godot frames; no generated scene or animation pixels.

Blender --background --python this_file -- --encode; then Python this_file.
"""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1] / '.validation' / 'smooth_step_up'
if '--encode' in sys.argv:
    import bpy
    scene = bpy.context.scene
    scene.sequence_editor_create()
    strip = scene.sequence_editor.strips.new_movie('Godot capture', str(ROOT / 'gameplay.avi'), channel=1, frame_start=1)
    scene.frame_start = 1
    scene.frame_end = strip.frame_duration - 2  # Exclude scene teardown.
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.resolution_percentage = 100
    scene.render.fps = 30
    scene.render.use_sequencer = True
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.render.image_settings.media_type = 'VIDEO'
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.constant_rate_factor = 'HIGH'
    scene.render.ffmpeg.audio_codec = 'NONE'
    scene.render.filepath = str(ROOT / 'gameplay.mp4')
    bpy.ops.render.render(animation=True)
else:
    import cv2
    from PIL import Image, ImageDraw
    cap = cv2.VideoCapture(str(ROOT / 'gameplay.mp4'))
    fps = cap.get(cv2.CAP_PROP_FPS)
    count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    # Sample approach/rise/top/descent from the actual physical capture.
    metadata = json.loads((ROOT / 'capture.json').read_text(encoding='utf-8'))
    chosen = [30, 38, 44, 50, 86, 91, 135, 143, 151, 158, 194, 201, 238, 248, 264]
    sheet = Image.new('RGB', (1280, 5 * 265), '#161c20')
    draw = ImageDraw.Draw(sheet)
    for i, frame in enumerate(chosen):
        cap.set(cv2.CAP_PROP_POS_FRAMES, frame)
        ok, bgr = cap.read()
        if not ok:
            raise RuntimeError(f'Cannot decode frame {frame}')
        rgb = Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
        rgb.save(ROOT / f'frame_{frame:03}.png')
        rgb.thumbnail((426, 240))
        x, y = (i % 3) * 426, (i // 3) * 265
        sheet.paste(rgb, (x, y))
        draw.text((x + 6, y + 243), f'Frame {frame} / {frame / fps:.2f}s', fill='white')
    cap.release()
    sheet.save(ROOT / 'contact_sheet.jpg', quality=92)
    result = {'decoded_frames': count, 'fps': fps, 'seconds': count / fps, 'sample_frames': chosen, 'note': 'Actual encoded Godot video; original walk/run, smooth step up, no jump animation. Offline capture is not a performance benchmark.'}
    (ROOT / 'video_checks.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))
