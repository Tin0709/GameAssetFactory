"""Copy inspected Godot evidence; compose contact sheets from actual captured pixels."""
import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw

repo = Path(__file__).resolve().parents[2]
source = repo / 'game_mobile_3d/.validation/forest_quality'
target = repo / 'docs/validation/forest_quality'
target.mkdir(parents=True, exist_ok=True)
names = ['stage_0.png', 'stage_1.png', 'stage_2.png', 'detail.png', 'grove.png',
         'courtyard.png', 'captures.json', 'movie.json', 'gameplay.mp4',
         'profile_stage_0.json', 'profile_stage_1.json', 'profile_stage_2.json']
for name in names:
    shutil.copy2(source / name, target / name)

comparison = Image.new('RGB', (1920, 576), '#111a20')
draw = ImageDraw.Draw(comparison)
for i, label in enumerate(['Previous QualitySlice', 'New geometry / previous light', 'New geometry + sunlight']):
    comparison.paste(Image.open(source / f'stage_{i}.png').resize((640, 360)), (i*640, 30))
    draw.text((i*640+12, 9), label, fill='white')
    crop = Image.open(source / f'stage_{i}.png').crop((480, 250, 880, 430)).resize((400, 180))
    comparison.paste(crop, (i*640+120, 396))
comparison.save(target / 'comparison.jpg', quality=94)

frames = [1, 30, 45, 60, 80, 100, 120, 145, 170, 200, 230, 260]
sheet = Image.new('RGB', (1280, 630), '#111a20')
draw = ImageDraw.Draw(sheet)
for i, frame in enumerate(frames):
    x, y = i % 4 * 320, i // 4 * 210
    sheet.paste(Image.open(source / f'movie_frame_{frame:03d}.png').resize((320, 180)), (x, y+25))
    draw.text((x+8, y+6), f'Frame {frame} / {(frame-1)/30:.2f}s', fill='white')
sheet.save(target / 'motion_contact_sheet.jpg', quality=93)

checks = {'date': '2026-10-09', 'study': 'ForestQualitySlice', 'art_approved': False,
          'phone_verified': False, 'headless_validation': 'PASS', 'mobile_d3d12_validation': 'PASS',
          'covered': ['native GLB vertex color', 'A/B restoration', 'no grass shadow/fog',
                      'floor movement', 'production gun damage', 'wall foundations', 'closed exterior terrace'],
          'profiles': 'separate serial processes; user Godot editor remained open; no concurrent study render',
          'source_checks': 'blender/environment/studies/forest_canopy_v2/validation_source.json'}
(target / 'checks.json').write_text(json.dumps(checks, indent=2), encoding='utf-8')
print('Saved', len(list(target.iterdir())), 'forest evidence files')
