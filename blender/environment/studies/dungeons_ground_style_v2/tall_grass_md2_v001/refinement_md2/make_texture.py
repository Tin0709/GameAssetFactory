"""Observed MD2 meadow refinement: green base with restrained pale seed tips."""
from pathlib import Path
from PIL import Image,ImageOps
import hashlib,json
D=Path(__file__).resolve().parent;S=Path('/Users/tin/Desktop/Game Dev/local_references/Dungeons II Style 0.7 JE/assets/minecraft/textures/block')
full=Image.new('RGBA',(16,32));full.paste(Image.open(S/'tall_grass_top.png'),(0,0));full.paste(Image.open(S/'tall_grass_bottom.png'),(0,16));mask=full.crop((2,3,15,32))
variants=[mask.copy(),ImageOps.mirror(mask),mask.copy(),ImageOps.mirror(mask)]
for x in range(13):
 for y in range(3):variants[2].putpixel((x,y),(0,0,0,0))
for x in range(8,13):
 for y in range(8):variants[3].putpixel((x,y),(0,0,0,0))
root=(84,130,52);greens=[(76,122,49),(82,128,51),(89,136,55),(97,144,60)];levels=[141,146,160,175];seeds=[(173,172,110),(190,187,122),(208,201,142),(219,212,156)]
atlas=Image.new('RGBA',(128,128),(*root,0));regions=[]
def place(tile,x,y):
 tile=tile.resize((tile.width*2,tile.height*2),Image.Resampling.NEAREST);atlas.paste(tile,(x,y));regions.append([x,y,tile.width,tile.height])
 for yy in range(y-2,y+tile.height+2):
  for xx in range(x-2,x+tile.width+2):
   if x<=xx<x+tile.width and y<=yy<y+tile.height:continue
   p=tile.getpixel((min(tile.width-1,max(0,xx-x)),min(tile.height-1,max(0,yy-y))));atlas.putpixel((xx,yy),(*p[:3],0))
for i,m in enumerate(variants):
 tile=Image.new('RGBA',m.size,(*root,0));tops=[min([y for y in range(29) if m.getpixel((x,y))[3]>127],default=29) for x in range(13)]
 for y in range(29):
  for x in range(13):
   g,_,_,a=m.getpixel((x,y))
   if a<128:continue
   k=min(range(4),key=lambda k:abs(levels[k]-g));color=greens[k]
   if y<13 and y<tops[x]+3 and g>=160:color=seeds[k]
   if y>=26:color=root if (x//3+y)%3 else greens[1]
   tile.putpixel((x,y),(*color,255))
 place(tile,4+(i%2)*32,3+(i//2)*64)
short=Image.open(S/'short_grass.png').convert('RGBA').crop((0,6,16,16))
for i,m in enumerate([short,ImageOps.mirror(short)]):
 tile=Image.new('RGBA',m.size,(*root,0))
 for y in range(10):
  for x in range(16):
   g,_,_,a=m.getpixel((x,y))
   if a<128:continue
   color=greens[min(range(4),key=lambda k:abs(levels[k]-g))]
   if y>=8:color=root if (x//3+y)%3 else greens[1]
   tile.putpixel((x,y),(*color,255))
 place(tile,80,8+i*32)
atlas.save(D/'Tall_Grass_MD2_Meadow_Atlas.png')
info={'reference_images':['docs/graphics/references/user-dungeons2-gameplay-2026-10-09.png','docs/graphics/references/user-dungeons2-2026-10-09.png'],'observed_style':'dense green base, fewer upright stalks and small pale cream/gold seed tips; visual observation only','source_files':{n:hashlib.sha256((S/n).read_bytes()).hexdigest() for n in ['tall_grass_top.png','tall_grass_bottom.png','short_grass.png']},'regions_top_left':regions,'atlas_size':[128,128],'green_palette':greens,'seed_palette':seeds,'root_srgb':root,'alpha_values':[0,255],'adaptation':'Actual pack masks; source tint retained at roots, authored pale tip tint based on supplied MD2 image. No claim of official meshes/materials.'}
(D/'texture_manifest.json').write_text(json.dumps(info,indent=2)+'\n');print('MEADOW_TEXTURE_READY',regions)
