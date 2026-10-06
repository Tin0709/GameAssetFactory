from pathlib import Path
from PIL import Image, ImageDraw

base = Path(__file__).parent / 'holster_d1_v3_review'
bg = '#20252d'

def tile(path, label='', size=(300, 350)):
    image = Image.open(path).convert('RGBA')
    image.thumbnail(size)
    canvas = Image.new('RGB', (size[0], size[1] + 22), bg)
    canvas.paste(image, ((size[0] - image.width) // 2, 22), image)
    ImageDraw.Draw(canvas).text((8, 5), label, fill='white')
    return canvas

def gif(images, name, fps=24):
    # GIF delays are quantized to 10 ms; the .blend retains exact 24 FPS.
    delays = [10 * (round((i + 1) * 100 / fps) - round(i * 100 / fps)) for i in range(len(images))]
    images[0].save(base / name, save_all=True, append_images=images[1:], duration=delays, loop=0)

compare = []
for frame in range(1, 19):
    canvas = Image.new('RGB', (600, 372), bg)
    for col, version in enumerate(['v2', 'v3']):
        canvas.paste(tile(base / f'{version}_{frame:05.2f}_gameplay.png', f'{version.upper()} / frame {frame}'), (col * 300, 0))
    compare.append(canvas)
gif(compare, 'compare_V2_V3_24fps.gif')
gif(compare, 'compare_V2_V3_half_speed.gif', 12)

poses = [1, 3, 5, 8, 11, 13, 15, 18]
sheet = Image.new('RGB', (1760, 1128), bg)
for row, view in enumerate(['gameplay', 'front', 'side', 'back']):
    for col, frame in enumerate(poses):
        path = base / f'v3_{frame:05.2f}_{view}.png'
        if path.exists():
            sheet.paste(tile(path, f'{view} / {frame}', (220, 260)), (col * 220, row * 282))
sheet.save(base / 'contact_sheet.png')

idle = [tile(base / f'overlay_idle_phase00_frame{frame:02d}.png', f'Idle overlay / {frame}', (300, 350)) for frame in range(1, 23)]
gif(idle, 'idle_overlay_24fps.gif')
run = []
for frame in range(1, 23):
    canvas = Image.new('RGB', (480, 604), bg)
    for index, phase in enumerate([0, 4, 8, 12]):
        part = tile(base / f'overlay_run_phase{phase:02d}_frame{frame:02d}.png', f'Run 1.60x / phase {phase} / {frame}', (240, 280))
        canvas.paste(part, ((index % 2) * 240, (index // 2) * 302))
    run.append(canvas)
gif(run, 'run_four_phases_1_60x_24fps.gif')
gif(run, 'run_four_phases_1_60x_half_speed.gif', 12)
print(base / 'contact_sheet.png')
