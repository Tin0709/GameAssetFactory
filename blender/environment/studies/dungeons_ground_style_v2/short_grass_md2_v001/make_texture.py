"""Small hard-cutout derivatives of the user-supplied Dungeons II Style grass.
The untinted four gray values become terrain-matched greens; broad clusters and
pixel boundaries remain crisp. This study contains no runtime export.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
import json,hashlib,collections
D=Path(__file__).resolve().parent
SRC=Path('/Users/tin/Desktop/Game Dev/local_references/Dungeons II Style 0.7 JE/assets/minecraft/textures/block')
source=Image.open(SRC/'short_grass.png').convert('RGBA').crop((0,6,16,16))
# Four asymmetrical crops of the actual reference, rather than four colour swaps.
a=source.copy();b=ImageOps.mirror(source);c=source.copy();d=ImageOps.mirror(source)
# Shorten two tallest isolated prongs for the cushion; offset the broad fan.
for x in range(16):
 for y in range(2):c.putpixel((x,y),(0,0,0,0))
for x in range(12,16):
 for y in range(4):d.putpixel((x,y),(0,0,0,0))
base=(84,130,52);palette=[(76,122,49),(82,128,51),(89,136,55),(97,144,60)]
levels=[141,146,160,175];atlas=Image.new('RGBA',(128,64),(84,130,52,0));regions=[];cover=[]
for i,mask in enumerate([a,b,c,d]):
 tile=Image.new('RGBA',(16,10),(84,130,52,0))
 for y in range(10):
  for x in range(16):
   gray,_,_,alpha=mask.getpixel((x,y))
   if alpha<128:continue
   idx=min(range(4),key=lambda k:abs(levels[k]-gray))
   color=palette[idx]
   # Bottom two pixel rows converge onto the SAME current V3 ground palette.
   if y>=8:color=base if (x//3+y)%3 else palette[1]
   tile.putpixel((x,y),(*color,255))
 # Keep16x10logical reference pixels:2× nearest-neighbour scale only.
 tile=tile.resize((32,20),Image.Resampling.NEAREST)
 x=8+i*32 if False else (8+(i%2)*64);y=8+(i//2)*32
 atlas.paste(tile,(x,y));regions.append([x,y,32,20]);cover.append(sum(p[3]>127 for p in tile.getdata())/(32*20))
 # Duplicate RGB into transparent gutter, keeping alpha0 (no coloured fringe).
 for yy in range(y-4,y+24):
  for xx in range(x-4,x+36):
   if x<=xx<x+32 and y<=yy<y+20:continue
   px=tile.getpixel((min(31,max(0,xx-x)),min(19,max(0,yy-y))));atlas.putpixel((xx,yy),(*px[:3],0))
atlas.save(D/'Short_Grass_MD2_v001_Atlas.png')
manifest={'source_pack':'Dungeons II Style 0.7 JE','source_file':str(SRC/'short_grass.png'),'sha256':hashlib.sha256((SRC/'short_grass.png').read_bytes()).hexdigest(),'reference_grays':levels,'terrain_root_srgb':base,'palette_srgb':palette,'atlas_size':[128,64],'regions_top_left':regions,'coverage':cover,'alpha_values':[0,255],'construction':'Cropped, mirrored and selectively shortened source silhouettes; terrain-matched tint. No blur or random pixel noise.','review_only':True}
(D/'texture_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('TEXTURE_READY',cover)
