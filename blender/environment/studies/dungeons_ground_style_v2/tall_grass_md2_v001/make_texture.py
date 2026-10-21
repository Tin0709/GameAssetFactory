"""Tall foliage derived from the actual supplied resource-pack sprites, never blurred."""
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw
import json,hashlib
D=Path(__file__).resolve().parent
S=Path('/Users/tin/Desktop/Game Dev/local_references/Dungeons II Style 0.7 JE/assets/minecraft/textures/block')
full=Image.new('RGBA',(16,32));full.paste(Image.open(S/'tall_grass_top.png').convert('RGBA'),(0,0));full.paste(Image.open(S/'tall_grass_bottom.png').convert('RGBA'),(0,16))
source=full.crop((2,3,15,32));a=source.copy();b=ImageOps.mirror(source);c=source.copy();d=ImageOps.mirror(source)
# Sparse tip edits retain the actual reference's forked broad blade language.
for x in range(13):
 for y in range(3):c.putpixel((x,y),(0,0,0,0))
for x in range(8,13):
 for y in range(8):d.putpixel((x,y),(0,0,0,0))
levels=[141,146,160,175];palette=[(76,122,49),(82,128,51),(89,136,55),(97,144,60)];root=(84,130,52)
atlas=Image.new('RGBA',(128,128),(*root,0));regions=[];coverage=[]
for i,mask in enumerate([a,b,c,d]):
 tile=Image.new('RGBA',(13,29),(*root,0))
 for y in range(29):
  for x in range(13):
   gray,_,_,alpha=mask.getpixel((x,y))
   if alpha<128:continue
   color=palette[min(range(4),key=lambda k:abs(levels[k]-gray))]
   if y>=26:color=root if (x//3+y)%3 else palette[1]
   tile.putpixel((x,y),(*color,255))
 tile=tile.resize((26,58),Image.Resampling.NEAREST);x=8+(i%2)*64;y=3+(i//2)*64;atlas.paste(tile,(x,y));regions.append([x,y,26,58]);coverage.append(sum(p[3]>127 for p in tile.getdata())/(26*58))
 for yy in range(y-3,y+61):
  for xx in range(x-4,x+30):
   if x<=xx<x+26 and y<=yy<y+58:continue
   p=tile.getpixel((min(25,max(0,xx-x)),min(57,max(0,yy-y))));atlas.putpixel((xx,yy),(*p[:3],0))
atlas.save(D/'Tall_Grass_MD2_v001_Atlas.png')
report={'source_pack':'Dungeons II Style 0.7 JE','source_files':{n:{'path':str(S/n),'sha256':hashlib.sha256((S/n).read_bytes()).hexdigest()} for n in ['tall_grass_top.png','tall_grass_bottom.png','grass_block_top.png']},'source_sprite_size':[16,16],'joined_crop':[2,3,15,32],'reference_grays':levels,'terrain_root_srgb':root,'palette_srgb':palette,'atlas_size':[128,128],'regions_top_left':regions,'coverage':coverage,'alpha_values':[0,255],'construction':'Actual joined top/bottom13x29crop; mirror and selective tip trimming. Same short-grass greens and terrain root convergence; nearest2x only. Geometry is an authored adaptation, not official game data.','review_only':True}
(D/'texture_manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('TALL_TEXTURE_READY',coverage)
board=Image.new('RGB',(760,420),(42,47,48));draw=ImageDraw.Draw(board)
for i,(x,y,w,h) in enumerate(regions):
 tile=atlas.crop((x,y,x+w,y+h)).resize((130,290),Image.Resampling.NEAREST);board.paste(tile,(25+i*185,70),tile);draw.text((25+i*185,35),'TALL '+chr(65+i),fill=(225,230,220))
board.save(D/'review/Texture_Reference.png')
