"""Original pixel-painted canvas, leather and metal for the supplied backpack reference."""
from pathlib import Path
from PIL import Image, ImageDraw
import random, json

HERE = Path(__file__).resolve().parent
atlas = Image.new('RGB', (512, 512), (56, 43, 28))
regions = {}
x0, y0, row_h = 2, 2, 0

def add(name, color, seed, size=96, kind='canvas'):
    global x0, y0, row_h
    if x0 + size + 2 > 512:
        x0, y0, row_h = 2, y0 + row_h + 4, 0
    assert y0 + size + 2 < 512
    rng = random.Random(seed)
    im = Image.new('RGB', (size, size), color)
    d = ImageDraw.Draw(im)
    # Broad quiet variations underneath coarse woven/pixel wear.
    for _ in range(26):
        x, y = rng.randrange(size), rng.randrange(size)
        w, h = rng.randrange(5, 15), rng.randrange(4, 13)
        delta = rng.choice([-7, -4, 3, 6])
        c = tuple(max(0, min(255, v + delta)) for v in color)
        d.rectangle((x, y, x+w, y+h), fill=c)
    for _ in range(size*size//12):
        x, y = rng.randrange(size), rng.randrange(size)
        if kind == 'canvas':
            delta = rng.choice([-12, -7, -3, 6, 10])
            tint = rng.choice([(0, 0, 0), (-3, 0, 4), (-2, 1, 6)])
            c = tuple(max(0, min(255, color[i]+delta+tint[i])) for i in range(3))
        else:
            delta = rng.choice([-8, -4, 4, 8])
            c = tuple(max(0, min(255, v+delta)) for v in color)
        d.rectangle((x, y, x+rng.choice([1, 1, 2]), y+rng.choice([1, 2, 3])), fill=c)
    if kind == 'webbing':
        for y in range(2, size, 6):
            d.line((0,y,size,y), fill=tuple(v+4 for v in color), width=1)
    if kind == 'plate':
        # Small flush rivets are painted, not separate expensive spheres.
        for x in [5, size-6]:
            for y in [5, size-6]:
                d.rectangle((x-1,y-1,x+1,y+1), fill=(77,76,69))
                d.point((x-1,y-1), fill=(154,151,136))
    atlas.paste(im.resize((size+2,size+2), Image.Resampling.NEAREST), (x0-1,y0-1))
    atlas.paste(im,(x0,y0))
    regions[name] = [x0,y0,size,size]
    x0 += size+4
    row_h = max(row_h,size)

add('canvas', (90,64,35), 12, 128)
add('canvas_warm', (101,71,38), 33, 128)
add('canvas_flap', (108,78,43), 54, 128)
add('canvas_side', (85,61,35), 61)
add('canvas_edge', (121,88,49), 73)
add('canvas_shadow', (67,49,29), 84)
add('leather', (36,32,27), 92, kind='webbing')
add('webbing_brown', (81,62,39), 105, kind='webbing')
add('back_pad', (66,53,37), 113, kind='webbing')
add('steel', (129,132,125), 128, kind='metal')
add('steel_edge', (75,79,77), 139, kind='metal')
add('buckle_plate', (132,135,128), 146, kind='plate')
atlas.save(HERE/'backpack_atlas.png')
(HERE/'atlas_regions.json').write_text(json.dumps(regions,indent=2))
print('Backpack atlas:', len(regions), 'original pixel-painted regions')
