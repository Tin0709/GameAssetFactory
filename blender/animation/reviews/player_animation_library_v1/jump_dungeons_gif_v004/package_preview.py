"""Arrange real sequential Blender pixels; this script does not synthesize poses."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
TMP = OUT.parents[4] / '.validation/jump_dungeons_gif_v004'
font = ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf', 25)
small = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 20)


def phase(frame):
    if frame <= 6:
        return 'READY / ANTICIPATION / PUSH'
    if frame < 23:
        return 'AIR / JUMP REFERENCE'
    if frame <= 25:
        return 'CONTACT / ABSORB'
    return 'JUMP LAND / RECOVER TO IDLE'


def run():
    folder = TMP / 'encode'
    folder.mkdir(parents=True, exist_ok=True)
    for frame in range(1, 37):
        canvas = Image.new('RGB', (1280, 736), (20, 28, 37))
        draw = ImageDraw.Draw(canvas)
        for x, view in [(0, 'three_quarter'), (640, 'side')]:
            src = Image.open(TMP / 'frames' / view / f'{frame:03d}.png')
            assert src.size == (640, 640)
            canvas.paste(src, (x, 64))
        draw.text((18, 5), 'JUMP + LAND V004  /  3/4 + SIDE  /  BLENDER STUDY', font=font, fill='white')
        draw.text((18, 35), '1x speed / 30 FPS / one complete jump repeated three times', font=small, fill=(141, 218, 208))
        draw.text((18, 707), f'F{frame:02d} / {phase(frame)}', font=small, fill='white')
        for repeat in range(3):
            canvas.save(folder / f'{repeat*36+frame:04d}.png')
    frames = [1, 4, 6, 8, 14, 20, 23, 25, 28, 32, 35, 36]
    sheet = Image.new('RGB', (1280, 1060), (20, 28, 37))
    draw = ImageDraw.Draw(sheet)
    draw.text((18, 8), 'JUMP + LAND V004 / ACTUAL SEQUENTIAL BLENDER RENDERS', font=font, fill='white')
    for i, frame in enumerate(frames):
        x, y = i % 6 * 212, 52 + i // 6 * 500
        draw.text((x + 6, y), f'F{frame:02d}', font=small, fill=(141, 218, 208))
        for j, view in enumerate(['three_quarter', 'side']):
            src = Image.open(TMP / 'frames' / view / f'{frame:03d}.png').resize((212, 212), Image.Resampling.LANCZOS)
            sheet.paste(src, (x, y + 30 + j * 222))
    sheet.save(OUT / 'contact_sheet.jpg', quality=94)
    metadata = {'file': 'jump_land_1x.mp4', 'fps': 30, 'frames': 108, 'size': [1280, 736],
                'source_frames_per_jump': 36, 'repeats': 3, 'kind': 'Blender-only sequential renders, no Godot footage',
                'reference_metadata': 'references/references.json'}
    (OUT / 'media_manifest.json').write_text(json.dumps(metadata, indent=2))
    return metadata


if __name__ == '__main__':
    print(json.dumps(run(), indent=2))
