"""Author original continuous two-cell grass pixels, retaining the V2 atlas elsewhere."""
from pathlib import Path
from PIL import Image
import json, hashlib
ROOT=Path(__file__).resolve().parent
SOURCE=ROOT.parent/'dungeons_ground_style_v2'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p.relative_to(SOURCE)):sha(p) for p in SOURCE.rglob('*') if p.is_file()}
atlas=Image.open(SOURCE/'textures/meadow_atlas.png').convert('RGBA')
short=Image.open(SOURCE/'textures/short_grass.png').convert('RGBA')
palette=sorted({p[:3] for p in short.getdata() if p[3]})
# All blades start at the same crown; varied heights and alternating bends form one plant.
blades=[([(13,0),(10,18),(6,34),(3,46),(4,53),(8,45),(12,30),(17,0)],(119,148,76)),
        ([(12,0),(12,25),(14,49),(16,64),(18,59),(18,35),(17,15),(18,0)],(138,160,91)),
        ([(15,0),(17,22),(21,39),(26,56),(28,58),(27,47),(24,30),(20,0)],(101,130,63)),
        ([(14,0),(8,10),(3,19),(0,31),(3,30),(8,22),(12,16),(19,0)],(111,140,69)),
        ([(16,0),(21,12),(28,26),(32,40),(29,39),(24,31),(19,21),(14,0)],(131,153,82)),
        ([(13,0),(9,23),(9,44),(7,58),(5,56),(6,38),(8,20),(16,0)],(123,145,77)),
        ([(15,0),(15,28),(18,41),(21,49),(23,48),(21,38),(20,20),(19,0)],(146,165,98))]
def inside(x,y,p):
    state=False;j=len(p)-1
    for i,(xi,yi) in enumerate(p):
        xj,yj=p[j]
        if (yi>y)!=(yj>y) and x<(xj-xi)*(y-yi)/(yj-yi)+xi:state=not state
        j=i
    return state
patch=Image.new('RGBA',(32,64))
for y in range(64):
    for x in range(32):
        color=(0,0,0,0)
        for poly,base in blades:
            if inside(x+.5,y+.5,poly):
                lift=-6 if y<13 else (3 if y>42 else 0)
                desired=tuple(v+lift for v in base)
                rgb=min(palette,key=lambda c:sum((a-b)**2 for a,b in zip(c,desired)))
                color=(*rgb,255)
        patch.putpixel((x,63-y),color)
patch.save(ROOT/'tall_grass_pixels.png')
# V2 coordinates are Blender bottom-up coordinates. Pillow starts at the top.
atlas.paste(patch,(38,128-38-64))
atlas.save(ROOT/'meadow_m2_atlas.png')
Image.open(ROOT/'meadow_m2_atlas.png').resize((768,768),Image.Resampling.NEAREST).save(ROOT/'atlas_review.png')
(ROOT/'source_preservation.json').write_text(json.dumps(before,indent=2))
print('ATLAS_READY',len(palette),'exact short palette colors')
