"""Original pixel-painted canvas, leather and metal for the supplied backpack reference."""
from pathlib import Path
from PIL import Image, ImageDraw
import random, json

HERE = Path(__file__).resolve().parent
atlas = Image.new('RGB', (512, 512), (56, 43, 28))
regions = {}
x0, y0, row_h = 2, 2, 0

def add(name, color, seed, size=64, kind='canvas'):
    global x0, y0, row_h
    if x0 + size + 2 > 512:
        x0, y0, row_h = 2, y0 + row_h + 4, 0
    assert y0 + size + 2 < 512
    rng = random.Random(seed)
    # Latest direction: quiet broad pixel blocks, no per-pixel grain/speckles.
    # Paint at32 logical pixels, then enlarge with NEAREST to keep crisp voxel edges.
    logical=32
    im = Image.new('RGB', (logical, logical), color)
    d = ImageDraw.Draw(im)
    for x,y,w,h in [(2,3,5,4),(11,2,5,3),(21,4,6,4),(5,11,4,5),
                    (15,10,5,4),(25,13,4,5),(1,23,5,4),(10,20,5,5),
                    (20,23,6,4),(12,28,5,3),(27,26,4,3)]:
        delta=rng.choice([-4,-2,2,4]) if kind=='canvas' else rng.choice([-2,0,2])
        c=tuple(max(0,min(255,v+delta)) for v in color)
        d.rectangle((x,y,x+w-1,y+h-1),fill=c)
    if kind=='canvas_edge':
        d.rectangle((0,0,31,2),fill=tuple(v+4 for v in color))
    if kind == 'webbing':
        for y in [7,15,23]:
            d.rectangle((0,y,31,y+1),fill=tuple(v+2 for v in color))
    if kind == 'plate':
        # Readable flat gray plates with simple edge highlights and four square rivets.
        d.rectangle((0,0,31,0),fill=(128,129,123))
        d.rectangle((0,1,0,30),fill=(121,122,117))
        d.rectangle((31,1,31,31),fill=(91,92,88))
        d.rectangle((0,31,31,31),fill=(91,92,88))
        for x in [3,28]:
            for y in [3,28]:d.rectangle((x,y,x+1,y+1),fill=(86,87,82))
    im=im.resize((size,size),Image.Resampling.NEAREST)
    atlas.paste(im.resize((size+2,size+2), Image.Resampling.NEAREST), (x0-1,y0-1))
    atlas.paste(im,(x0,y0))
    regions[name] = [x0,y0,size,size]
    x0 += size+4
    row_h = max(row_h,size)

add('canvas', (82,61,40), 12, 128)
add('canvas_warm', (91,66,40), 33, 128)
add('canvas_flap', (93,67,40), 54, 128)
add('canvas_side', (76,57,38), 61)
add('canvas_edge', (113,83,49), 73)
add('canvas_shadow', (59,45,32), 84)
add('leather', (36,32,27), 92, kind='webbing')
add('webbing_brown', (81,62,39), 105, kind='webbing')
add('back_pad', (66,53,37), 113, kind='webbing')
add('steel', (105,107,104), 128, kind='metal')
add('steel_edge', (67,69,67), 139, kind='metal')
add('buckle_plate', (111,112,108), 146, kind='plate')
atlas.save(HERE/'backpack_atlas.png')
(HERE/'atlas_regions.json').write_text(json.dumps(regions,indent=2))
print('Backpack atlas:', len(regions), 'original pixel-painted regions')
