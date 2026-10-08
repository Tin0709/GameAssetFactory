"""Original rectangular pixel clusters; the pack is read only for reference hashes."""
from pathlib import Path
from PIL import Image, ImageDraw
import random, json, hashlib

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'v3_textures'
OUT.mkdir(exist_ok=True)
REF = ROOT.parents[3] / 'references/resource_packs/dungeons_ii_style/extracted/assets/minecraft/textures/block'
GREEN = [(70,112,47),(76,122,49),(84,130,52),(90,137,56),(97,143,60)]
EARTH = [(122,85,49),(132,93,54),(141,101,59),(150,110,65),(159,119,73)]
STONE = [(108,120,125),(116,128,132),(124,136,139),(132,144,146),(140,151,152)]

def clusters(palette, seed, count, stone=False):
    rng = random.Random(seed)
    im = Image.new('RGBA',(32,32),(*palette[2],255))
    draw = ImageDraw.Draw(im)
    for _ in range(count):
        x,y=rng.randrange(32),rng.randrange(32)
        w=rng.randrange(4,11) if stone else rng.randrange(4,9)
        h=rng.randrange(2,5) if stone else rng.randrange(3,7)
        c=(*rng.choice(palette),255)
        # Wrapped stepped brush clusters tile across all four edges.
        for dx in (-32,0,32):
            for dy in (-32,0,32):
                draw.rectangle((x+dx,y+dy,x+w+dx-1,y+h+dy-1),fill=c)
                draw.rectangle((x+dx+1,y+dy-2,x+dx+w-2,y+dy),fill=c)
    return im

tops=[clusters(GREEN,101+i*37,25) for i in range(4)]
dirt=clusters(EARTH,613,25)
draw=ImageDraw.Draw(dirt)
# Sparse embedded stones, never concentric rings.
for xy in [(6,11,8,13),(24,22,27,24)]: draw.rectangle(xy,fill=(136,126,103,255))
stone=clusters(STONE,912,36,True)
side=dirt.copy(); d=ImageDraw.Draw(side)
cap=[7,7,8,8,10,10,9,9,7,7,8,8,11,11,10,10,8,8,7,7,9,9,10,10,8,8,9,9,8,8,7,7]
for x,h in enumerate(cap):
    for y in range(h):
        c=tops[0].getpixel((x,y)); side.putpixel((x,y),c)
    side.putpixel((x,h),(*GREEN[0],255))

def plant(tall=False):
    h=64 if tall else 32
    im=Image.new('RGBA',(32,h),(0,0,0,0)); d=ImageDraw.Draw(im)
    # Broad, squared, independent blades. PIL coordinates run downward.
    if tall:
        polys=[[(10,63),(9,34),(5,34),(5,19),(8,19),(8,28),(12,28),(13,63)],
               [(13,63),(13,6),(17,6),(17,15),(18,15),(18,63)],
               [(17,63),(18,27),(22,27),(22,12),(25,12),(25,36),(22,36),(21,63)],
               [(10,63),(7,50),(2,50),(2,36),(5,36),(5,44),(10,44),(15,63)],
               [(18,63),(22,44),(27,44),(27,27),(30,27),(30,50),(25,50),(23,63)],
               [(12,63),(11,17),(14,17),(15,63)],
               [(19,63),(20,38),(24,38),(24,55),(21,63)]]
    else:
        polys=[[(10,31),(8,22),(4,22),(4,14),(7,14),(7,19),(11,19),(14,31)],
               [(12,31),(12,6),(16,6),(16,12),(18,12),(18,31)],
               [(17,31),(19,17),(23,17),(23,9),(26,9),(26,23),(22,23),(21,31)],
               [(8,31),(3,27),(1,27),(1,23),(5,23),(12,31)],
               [(18,31),(23,26),(27,26),(27,19),(30,19),(30,28),(24,28),(22,31)],
               [(13,31),(9,11),(12,11),(16,31)]]
    palette=[(83,130,52),(104,150,62),(76,121,48),(90,137,53),(110,156,66),(96,143,57),(84,131,48)]
    for i,poly in enumerate(polys):
        d.polygon(poly,fill=(*palette[i],255))
    # A rooted darker lower section and restrained squared highlight strips.
    for y in range(h):
        for x in range(32):
            r,g,b,a=im.getpixel((x,y))
            if a:
                lift=-14 if y>h*.82 else (4 if y<h*.28 else 0)
                im.putpixel((x,y),(r+lift,g+lift,b+lift,a))
    return im

images={**{f'grass_top_{i}':im for i,im in enumerate(tops)},'dirt':dirt,'grass_side':side,'stone':stone,'grass':plant(),'tall_grass':plant(True)}
for n,im in images.items(): im.save(OUT/(n+'.png'))
sheet=Image.new('RGB',(1200,540),(35,43,44)); d=ImageDraw.Draw(sheet)
for i,n in enumerate(['grass_top_0','grass_side','dirt','stone','grass','tall_grass']):
    im=images[n]; preview=im.resize((184,368 if n=='tall_grass' else 184),Image.Resampling.NEAREST)
    sheet.paste(preview,(i*200+8,40),preview);d.text((i*200+8,12),n,fill='white')
sheet.save(ROOT/'v3_texture_board.png')
meta={'style':'original angular pixel cluster study, pack palette/layout reference only','texture_size':'32px blocks; 32x64 tall','reference_sha256':{n:hashlib.sha256((REF/(n+'.png')).read_bytes()).hexdigest() for n in ['grass_block_top','grass_block_side','dirt','stone','short_grass','tall_grass_top','tall_grass_bottom']},'texture_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')}}
(ROOT/'v3_texture_manifest.json').write_text(json.dumps(meta,indent=2))
print('Original V3 textures:',len(images))
