"""Original pixel-painted canvas, leather and metal for the supplied backpack reference."""
from pathlib import Path
from PIL import Image, ImageDraw
import random, json

HERE = Path(__file__).resolve().parent
atlas = Image.new('RGB', (1024, 1024), (56, 43, 28))
regions = {}
x0, y0, row_h = 2, 2, 0

def add(name, color, seed, size=128, kind='canvas'):
    global x0, y0, row_h
    if x0 + size + 2 > 1024:
        x0, y0, row_h = 2, y0 + row_h + 4, 0
    assert y0 + size + 2 < 1024
    rng = random.Random(seed)
    im = Image.new('RGB', (size, size), color)
    d = ImageDraw.Draw(im)
    # The source sheet has mottled brown cloth with gray-brown dust and tiny
    # cool speckles, rather than large camouflage-like squares. Paint these
    # as original pixels at a finer density, using measured reference colors.
    for _ in range(size*size//280):
        x, y = rng.randrange(size), rng.randrange(size)
        w, h = rng.randrange(4, 15), rng.randrange(3, 12)
        delta = rng.choice([-10, -5, 3, 8])
        tint = (-2,1,5) if rng.random()<.4 else (0,0,0)
        c = tuple(max(0, min(255, color[i] + delta + tint[i])) for i in range(3))
        d.rectangle((x, y, x+w, y+h), fill=c)
    for _ in range(size*size//3):
        x, y = rng.randrange(size), rng.randrange(size)
        if kind == 'canvas':
            delta = rng.choice([-17, -11, -6, -3, 2, 7, 12, 17])
            tint = rng.choice([(0,0,0), (-4,0,5), (-7,-1,7), (6,2,-3)])
            c = tuple(max(0, min(255, color[i]+delta+tint[i])) for i in range(3))
        else:
            delta = rng.choice([-8, -4, 4, 8])
            c = tuple(max(0, min(255, v+delta)) for v in color)
        d.rectangle((x, y, x+rng.choice([0,0,1]), y+rng.choice([0,1,1,2])), fill=c)
    if kind=='canvas':
        # Restrained warm fiber threads and small desaturated grit pixels.
        for _ in range(size*size//38):
            x,y=rng.randrange(size),rng.randrange(size)
            c=rng.choice([(color[0]+20,color[1]+15,color[2]+8),
                          (color[0]-10,color[1]-3,color[2]+4),
                          (color[0]-17,color[1]-11,color[2]-4)])
            d.rectangle((x,y,x+1,y+1),fill=c)
    if kind == 'webbing':
        for y in range(2, size, 5):
            d.line((0,y,size,y), fill=tuple(v+3 for v in color), width=1)
    if kind == 'plate':
        # Worn gray steel: edge nicks, dark rivet rings and short scratches.
        for _ in range(size*size//150):
            x,y=rng.randrange(size),rng.randrange(size)
            d.line((x,y,x+rng.randrange(1,5),y),fill=(146,144,135))
        d.rectangle((0,0,size-1,1),fill=(145,144,135))
        d.rectangle((0,2,1,size-2),fill=(130,130,122))
        d.rectangle((size-2,2,size-1,size-1),fill=(78,77,71))
        d.rectangle((0,size-2,size-1,size-1),fill=(80,78,71))
        for x in [12,size-13]:
            for y in [12,size-13]:
                d.rectangle((x-2,y-2,x+2,y+2),fill=(76,74,67))
                d.rectangle((x-1,y-1,x+1,y+1),fill=(123,121,111))
                d.point((x-1,y-1),fill=(161,158,144))
    atlas.paste(im.resize((size+2,size+2), Image.Resampling.NEAREST), (x0-1,y0-1))
    atlas.paste(im,(x0,y0))
    regions[name] = [x0,y0,size,size]
    x0 += size+4
    row_h = max(row_h,size)

add('canvas', (82,61,40), 12, 256)
add('canvas_warm', (91,66,40), 33, 256)
add('canvas_flap', (93,67,40), 54, 256)
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
