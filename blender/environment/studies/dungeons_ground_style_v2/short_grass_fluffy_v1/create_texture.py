"""Original pixel silhouettes; reference pack is never sampled or copied."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

HERE=Path(__file__).resolve().parent
NAMES=['SoftYellow','DustyPink','Lavender','SageGreen']
GREENS=[(76,122,49),(84,130,52),(90,137,56),(97,143,60)]
TIPS=[[(173,178,110),(195,195,133),(212,207,153)],
      [(173,128,132),(195,151,151),(211,176,171)],
      [(137,133,174),(160,155,193),(182,178,211)],
      [(130,162,123),(153,181,145),(180,200,166)]]
# Each blade has an independently designed stepped path, width, and height.
# Coordinates are in logical16px cells, bottom-up. This is not the pack mask.
BLADES=[(1,5,-1,1),(3,10,-2,1),(4,7,0,2),(6,14,-1,1),
        (7,9,1,2),(9,12,1,1),(10,6,1,2),(12,15,1,1),
        (13,10,1,1),(14,5,1,1)]
atlas=Image.new('RGBA',(128,32),(84,130,52,0))
stats=[]
for index,name in enumerate(NAMES):
    tile=Image.new('RGBA',(16,16),(84,130,52,0))
    for blade,(root,height,lean,width) in enumerate(BLADES):
        for z in range(height):
            x=root+round(lean*(z/max(height-1,1))**1.7)
            for w in range(width):
                xx=x+w
                if not 0<=xx<16: continue
                if z<3: rgb=GREENS[1 if (xx+z)%4 else 0]
                elif z<height-4: rgb=GREENS[(blade+z//3)%3+1]
                elif z==height-4: rgb=tuple(round(a*.48+b*.52) for a,b in zip(GREENS[3],TIPS[index][0]))
                else: rgb=TIPS[index][min(2,(z-height+3)//2+1)]
                tile.putpixel((xx,15-z),rgb+(255,))
    # Short, jagged interleaved root leaves; retain transparent notches.
    for x,h in [(0,2),(2,4),(5,3),(8,5),(11,4),(15,2)]:
        for z in range(h):
            if tile.getpixel((x,15-z))[3]==0:
                tile.putpixel((x,15-z),GREENS[(x+z)%3]+(255,))
    atlas.paste(tile,(index*32+8,8))
    # Eight-cell edge extension prevents neighbour bleed. No smoothing.
    for yy in range(32):
        for xx in range(32):
            if 8<=xx<24 and 8<=yy<24: continue
            atlas.putpixel((index*32+xx,yy),tile.getpixel((min(15,max(0,xx-8)),min(15,max(0,yy-8)))))
    stats.append({'variant':name,'logical_size':[16,16],'opaque_pixels':sum(tile.getpixel((x,y))[3]>127 for y in range(16) for x in range(16)),'tip_palette':TIPS[index]})
atlas.save(HERE/'ShortGrass_Fluffy_v1_Atlas.png')
board=Image.new('RGB',(800,250),(65,90,49));d=ImageDraw.Draw(board)
for i,name in enumerate(NAMES):
    im=atlas.crop((i*32+8,8,i*32+24,24)).resize((192,192),Image.Resampling.NEAREST)
    board.paste(im,(i*200+4,10),im)
    d.text((i*200+12,215),name,fill=(235,235,220))
board.save(HERE/'previews/Original_Texture_Board.png')
(HERE/'texture_design.json').write_text(json.dumps({'original':True,'reference_pixels_copied':False,'atlas_size':[128,32],'base_palette_matches':'DI_V3_grass_top_0','variants':stats},indent=2))
print(json.dumps(stats))
