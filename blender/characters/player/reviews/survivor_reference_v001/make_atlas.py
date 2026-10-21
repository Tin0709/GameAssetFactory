"""Original pixel painting: fixed clothing masks + sparse, seeded block clusters.
Reads the supplied reference for provenance only; does not project/copy its pixels.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json,random
OUT=Path(__file__).resolve().parent
ATLAS=Image.new('RGB',(512,512),(55,44,35));regions={};cx=2;cy=2;row=0

def tile(name,w,h,base,variation=0,seed=0):
 rng=random.Random(seed);im=Image.new('RGB',(w,h),base);d=ImageDraw.Draw(im)
 if variation:
  for i in range(w*h//10):
   x=rng.randrange(w);y=rng.randrange(h);v=rng.choice([-variation,-variation//2,variation//2,variation])
   col=tuple(max(0,min(255,c+v)) for c in base)
   d.rectangle((x,y,x+rng.choice([1,2,3]),y+rng.choice([1,2,4])),fill=col)
 return im,d

def store(name,im):
 global cx,cy,row
 w,h=im.size
 if cx+w+2>512:cx=2;cy+=row+4;row=0
 assert cy+h+2<512
 # Replicated gutter prevents adjacent tiles leaking at texture boundaries.
 ATLAS.paste(im.resize((w+2,h+2),Image.Resampling.NEAREST),(cx-1,cy-1));ATLAS.paste(im,(cx,cy))
 regions[name]=[cx,cy,w,h];cx+=w+4;row=max(row,h)

skin=(235,169,134)
for name,seed in [('skin',2),('skin_side',3),('hand',4),('neck',5)]:
 im,d=tile(name,16,32 if name=='skin' else 16,skin,5,seed)
 if name=='skin':
  d.rectangle((0,2,15,5),fill=(226,139,111));d.rectangle((0,5,3,8),fill=(235,148,119))
 if name=='hand':
  d.rectangle((0,12,15,15),fill=(214,140,106));d.rectangle((1,1,3,12),fill=(243,180,144))
  d.rectangle((9,12,11,15),fill=(174,102,75));d.rectangle((9,12,10,13),fill=(245,176,138))
 store(name,im)
im,d=tile('face',32,32,skin,3,7)
d.rectangle((0,0,31,9),fill=(220,149,111));d.rectangle((0,12,2,28),fill=(215,135,102));d.rectangle((29,12,31,28),fill=(218,142,110))
# Simple wide white eyes with dark warm pupils, no eyelashes or ornamental detail.
for x in [5,21]:
 d.rectangle((x,17,x+5,22),fill=(247,238,215));d.rectangle((x+2,17,x+4,22),fill=(52,44,33));d.rectangle((x+2,17,x+3,18),fill=(27,28,24))
 d.rectangle((x-1,15,x+5,16),fill=(85,50,34))
d.rectangle((3,25,9,27),fill=(247,183,148));d.rectangle((23,25,28,27),fill=(247,183,148))
d.rectangle((14,25,17,26),fill=(221,145,109));d.rectangle((13,29,18,29),fill=(192,121,91));d.rectangle((4,30,27,31),fill=(226,151,114))
store('face',im)
for i,name in enumerate(['shirt_front','shirt_back','shirt_side','sleeve']):
 im,d=tile(name,32,40 if name!='sleeve' else 24,(56,57,56),5,20+i)
 if name=='shirt_front':
  d.rectangle((9,0,22,1),fill=(32,34,33));d.rectangle((11,2,20,2),fill=(39,40,38))
  d.rectangle((1,4,2,35),fill=(48,49,48));d.rectangle((0,38,31,39),fill=(42,44,42))
 if name=='shirt_back':d.rectangle((8,0,23,1),fill=(43,44,42));d.rectangle((0,38,31,39),fill=(44,45,43))
 if name=='sleeve':d.rectangle((0,22,31,23),fill=(45,46,45))
 store(name,im)
for name,base in [('wrap',(205,195,169)),('band',(38,40,39))]:
 im,d=tile(name,24,8,base,4,31)
 if name=='wrap':
  d.rectangle((0,0,23,0),fill=(178,160,131));d.rectangle((0,7,23,7),fill=(234,220,191));d.rectangle((4,3,15,3),fill=(219,207,177))
 store(name,im)
for side in ['L','R']:
 for face in ['front','back','side']:
  seed=40+len(regions);im,d=tile('pants',16,56,(53,56,54),7,seed)
  rng=random.Random(seed)
  # Authored coarse dust/camouflage islands: darker shins, worn upper thighs/knees.
  masks=[(1,3,5,7),(3,7,8,10),(10,2,14,6),(8,8,12,11),(0,18,4,22),(5,19,9,24),(11,18,15,21),(9,30,13,34),(1,33,5,38),(4,36,9,40),(0,45,15,48),(3,49,9,50)]
  if face=='back':masks=[(2,3,7,6),(9,6,13,10),(0,20,5,24),(6,24,11,27),(9,35,14,40),(0,46,15,48),(4,49,8,51)]
  if face=='side':masks=[(3,6,8,9),(7,11,12,14),(2,19,7,23),(8,23,12,25),(0,33,4,36),(7,36,13,39),(0,46,15,49)]
  for j,(x0,y0,x1,y1) in enumerate(masks):
   if side=='R':x0,x1=15-x1,15-x0
   base=[(111,102,84),(131,112,90),(143,122,97)][j%3]
   d.rectangle((x0,y0,x1,y1),fill=base)
   d.rectangle((max(0,x0+1),max(0,y0-1),min(15,x1-1),y0),fill=(99,94,80))
   d.rectangle((x0,y1,min(x1,x0+1),min(55,y1+2)),fill=(119,104,86))
  # Pocket edge/hem is painted; no bag or new accessory added.
  d.rectangle((0,13,15,14),fill=(40,43,41));d.rectangle((0,29,15,30),fill=(42,45,43));d.rectangle((0,53,15,55),fill=(38,40,37))
  store('pants_'+side+'_'+face,im)
for i,name in enumerate(['boot','sole','boot_toe','boot_collar']):
 base=(66,55,46) if name!='sole' else (43,43,39)
 im,d=tile(name,24,12,base,7,70+i)
 if name in ['boot','boot_toe']:
  d.rectangle((0,8,23,10),fill=(119,87,63));d.rectangle((3,5,7,8),fill=(132,100,72));d.rectangle((11,7,14,8),fill=(140,109,79));d.rectangle((19,3,22,6),fill=(90,73,55))
 if name=='sole':d.rectangle((0,1,23,2),fill=(65,62,51));d.rectangle((0,11,23,11),fill=(31,33,31))
 store(name,im)
for i in range(12):
 base=[(79,43,28),(86,47,30),(92,51,32),(70,37,26),(101,57,35),(83,46,32)][i%6]
 im,d=tile('hair',8,8,base,3,90+i)
 # Broad lock highlights rather than salt-and-pepper texel noise.
 d.rectangle((0,0,7,0),fill=tuple(c+5 for c in base));d.rectangle((0,0,0,7),fill=tuple(c-6 for c in base))
 store('hair'+str(i),im)
ATLAS.save(OUT/'survivor_atlas.png');(OUT/'atlas_regions.json').write_text(json.dumps(regions,indent=2))
print('Atlas painted:',len(regions),'regions,512² RGB')
