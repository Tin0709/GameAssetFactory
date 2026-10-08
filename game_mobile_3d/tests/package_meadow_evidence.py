"""Archive actual Godot pixels and independently decode the final review video."""
from pathlib import Path
import json
import shutil

import cv2
import numpy as np
from PIL import Image, ImageDraw

repo = Path(__file__).resolve().parents[2]
source = repo / 'game_mobile_3d/.validation/forest_meadow_v3'
target = repo / 'docs/validation/forest_meadow_v3'
target.mkdir(parents=True, exist_ok=True)
for name in ['before_v2.png', 'stage_2.png', 'detail.png', 'grove.png',
             'grass_shadows_on.png', 'grass_shadows_off.png', 'haze_on.png', 'haze_off.png',
             'warmth_on.png', 'warmth_off.png', 'captures.json',
             'checks.json', 'movie.json', 'gameplay.mp4',
             'profile_grass_on.json', 'profile_grass_off.json', 'profile_haze_on.json']:
    shutil.copy2(source / name, target / name)

def comparison(names, labels, destination):
    sheet = Image.new('RGB', (1280, 388), '#111a20')
    draw = ImageDraw.Draw(sheet)
    for index, (name, label) in enumerate(zip(names, labels)):
        sheet.paste(Image.open(source / name).convert('RGB').resize((640, 360)), (index*640, 28))
        draw.text((index*640+10, 8), label, fill='white')
    sheet.save(target / destination, quality=94)

comparison(['before_v2.png', 'stage_2.png'],
           ['V2 previous forest', 'V3 current review: balanced light + shadows + thin haze'], 'comparison.jpg')
comparison(['grass_shadows_off.png', 'grass_shadows_on.png'],
           ['Grass shadows OFF', 'Grass shadows ON (temporary review)'], 'grass_shadows_comparison.jpg')
comparison(['haze_off.png', 'haze_on.png'],
           ['Thin haze OFF (same light and shadows)', 'Thin haze ON (current review)'], 'haze_comparison.jpg')
warmth = json.loads((source / 'captures.json').read_text(encoding='utf-8'))['warmth']
comparison(['warmth_off.png', 'warmth_on.png'],
           ['Warm grade OFF', f'Warm grade +{warmth:.0%} (current review)'], 'warmth_comparison.jpg')

video = cv2.VideoCapture(str(source / 'gameplay.mp4'))
assert video.isOpened(), 'Cannot decode review video'
fps = video.get(cv2.CAP_PROP_FPS)
sheet = Image.new('RGB', (1280, 630), '#111a20')
draw = ImageDraw.Draw(sheet)
samples = [1, 30, 45, 60, 80, 100, 120, 145, 170, 200, 230, 260]
count = 0
sizes = set()
while True:
    ok, frame = video.read()
    if not ok:
        break
    count += 1
    sizes.add((frame.shape[1], frame.shape[0]))
    if count in samples:
        i = samples.index(count)
        x, y = i % 4 * 320, i // 4 * 210
        pixels = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        sheet.paste(pixels.resize((320, 180)), (x, y+25))
        draw.text((x+8, y+6), f'Frame {count} / {(count-1)/fps:.2f}s', fill='white')
video.release()
expected = json.loads((source / 'movie.json').read_text(encoding='utf-8'))['last_content_frame']
assert count == expected and fps == 30 and sizes == {(1280, 720)}, (count, fps, sizes)
sheet.save(target / 'motion_contact_sheet.jpg', quality=93)

report = {'decoded_frames': count, 'fps': fps, 'seconds': count/fps,
          'resolution': [1280, 720], 'art_approved': False, 'phone_verified': False}
for kind in ['bloom', 'grass_shadows', 'haze', 'warmth']:
    on = np.asarray(Image.open(source / f'{kind}_on.png').convert('RGB')).astype(float)
    off = np.asarray(Image.open(source / f'{kind}_off.png').convert('RGB')).astype(float)
    report[kind] = {'mean_absolute_rgb_delta_8bit': float(abs(on-off).mean()),
                    'max_rgb_delta_8bit': float(abs(on-off).max()),
                    'changed_pixel_fraction': float(np.any(on != off, axis=2).mean())}
    if kind == 'warmth':
        report[kind]['strength'] = warmth
        report[kind]['mean_rgb_channel_shift_8bit'] = (on-off).mean(axis=(0, 1)).tolist()
        report[kind]['mean_luma_shift_8bit'] = float(((on-off) @ np.array([.2126, .7152, .0722])).mean())
(target / 'video_and_pixel_checks.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
