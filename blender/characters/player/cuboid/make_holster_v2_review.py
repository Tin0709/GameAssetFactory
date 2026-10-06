from pathlib import Path
from PIL import Image, ImageDraw

base = Path(__file__).parent / 'holster_d1_v2_review'
frames = [1, 3, 5, 8, 11, 13, 15, 18]
sheet = Image.new('RGB', (8 * 220, 3 * 282), '#20252d')
draw = ImageDraw.Draw(sheet)
for row, view in enumerate(['gameplay', 'front', 'side']):
    for col, frame in enumerate(frames):
        source = Image.open(base / f'pose_{frame:04.1f}_{view}.png').convert('RGBA')
        source.thumbnail((220, 255))
        x, y = col * 220, row * 282
        sheet.paste(source, (x, y + 22), source)
        draw.text((x + 8, y + 5), f'{view} / {frame}', fill='white')
sheet.save(base / 'contact_sheet.png')
images = []
for frame in range(1, 18):
    source = Image.open(base / f'pose_{frame:04.1f}_gameplay.png').convert('RGBA')
    background = Image.new('RGBA', source.size, '#20252d')
    background.alpha_composite(source)
    images.append(background.convert('RGB'))
for name, rate in [('preview_24fps.gif', 24), ('preview_half_speed.gif', 12)]:
    durations = [10 * (round((i + 1) * 100 / rate) - round(i * 100 / rate)) for i in range(17)]
    images[0].save(base / name, save_all=True, append_images=images[1:], duration=durations, loop=0)
print(base / 'contact_sheet.png')
