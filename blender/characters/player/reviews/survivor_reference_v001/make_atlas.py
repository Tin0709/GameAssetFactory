"""Reference-inspired skin ONLY. Original six-cuboid geometry stays unchanged.
Original pixel painting; no image projection, no generated raster substitute.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import json,random
OUT=Path(__file__).resolve().parent
ATLAS=Image.new('RGB',(512,512),(57,44,33));regions={};cx=2;cy=2;row=0
SKIN=(235,172,139)
HAIR=[(59,30,18),(68,35,21),(77,40,24),(54,27,17),(83,43,26),(64,32,20)]
def paint(w,h,color,seed=0,variation=0):
 im=Image.new('RGB',(w,h),color);d=ImageDraw.Draw(im);rng=random.Random(seed)
 for i in range(w*h//12 if variation else 0):
  x=rng.randrange(w);y=rng.randrange(h);v=rng.choice([-variation,variation])
  d.rectangle((x,y,x+rng.choice([1,2,3]),y+rng.choice([1,2,3])),fill=tuple(max(0,min(255,c+v)) for c in color))
 return im,d

def store(name,im):
 global cx,cy,row
 w,h=im.size
 if cx+w+2>512:cx=2;cy+=row+4;row=0
 assert cy+h+2<512
 ATLAS.paste(im.resize((w+2,h+2),Image.Resampling.NEAREST),(cx-1,cy-1));ATLAS.paste(im,(cx,cy))
 regions[name]=[cx,cy,w,h];cx+=w+4;row=max(row,h)

def hair_paint(im,mask,seed):
 """Broad offset pixel locks, dark undersides and restrained top highlights."""
 d=ImageDraw.Draw(im);rng=random.Random(seed)
 for y in range(0,32,2):
  for x in range(0,32,2):
   if not mask(x,y):continue
   shade=HAIR[((x-y//2)//4*7+y//4*11+seed)%len(HAIR)]
   for yy in range(y,min(32,y+2)):
    for xx in range(x,min(32,x+2)):
     if mask(xx,yy):im.putpixel((xx,yy),shade)
 # Hand-placed, staggered locks, clipped to the haircut silhouette.
 for x,y,w,h,tone in [(2,4,8,4,1),(10,2,7,5,2),(21,4,8,5,0),(0,10,7,5,2),(7,9,9,4,1),(17,8,8,5,2),(24,14,7,5,1),(5,15,7,5,0),(12,13,6,5,2),(2,20,5,5,0),(20,18,6,5,1)]:
  color=HAIR[(tone+seed)%len(HAIR)]
  for yy in range(y,min(32,y+h)):
   for xx in range(x,min(32,x+w)):
    if mask(xx,yy):
     shade=tuple(max(0,c-10) for c in color) if yy==y+h-1 else tuple(c+4 for c in color) if yy==y else color
     im.putpixel((xx,yy),shade)
 # Pixel staircase shadow directly under the fringe, not an eyebrow.
 for x in range(32):
  ys=[y for y in range(32) if mask(x,y)]
  if ys and max(ys)<31:
   y=max(ys);c=im.getpixel((x,y));im.putpixel((x,y),tuple(max(0,v-12) for v in c))
 return im

# FACE: eyes only, no nose, mouth, eyebrows, or sculpted facial parts.
im,d=paint(32,32,SKIN)
d.rectangle((0,13,1,30),fill=(218,143,111));d.rectangle((30,13,31,30),fill=(219,146,114))
fringe=[26,22,16,15,12,11,15,12,8,10,14,15,15,18,24,26]
hair_paint(im,lambda x,y:y<fringe[x//2],0)
d=ImageDraw.Draw(im)
for x in [4,20]:
 d.rectangle((x,16,x+7,23),fill=(249,241,222))
 d.rectangle((x+3,16,x+6,23),fill=(54,43,29))
 d.rectangle((x+3,16,x+5,17),fill=(28,27,23))
d.rectangle((2,25,8,27),fill=(244,182,148));d.rectangle((24,25,29,27),fill=(244,182,148))
store('head_front',im)
for side in ['left','right']:
 im,d=paint(32,32,SKIN)
 def mask(x,y):
  xx=x if side=='right' else 31-x
  bottom=27 if xx<4 else 28 if xx<11 else 30 if xx<23 else 28
  return y<bottom and not (xx<3 and 17<=y<=25)
 hair_paint(im,mask,1 if side=='left' else 4);store('head_'+side,im)
im,d=paint(32,32,SKIN);hair_paint(im,lambda x,y:y<(29 if x%9<4 else 30),3);store('head_back',im)
im,d=paint(32,32,HAIR[0]);hair_paint(im,lambda x,y:True,2);store('head_top',im)
im,d=paint(32,32,SKIN,0,2);store('head_bottom',im)

for i,name in enumerate(['shirt_front','shirt_back','shirt_side','shirt_top','shirt_bottom']):
 im,d=paint(32,48 if name in ['shirt_front','shirt_back','shirt_side'] else 16,(44,45,44),20+i,4)
 if name=='shirt_front':
  d.rectangle((9,0,22,2),fill=(31,33,32))
 if name in ['shirt_front','shirt_back']:d.rectangle((0,46,31,47),fill=(37,39,37))
 store(name,im)

for side in ['L','R']:
 for face in ['front','back','side','inside']:
  im,d=paint(16,48,SKIN,31,3)
  sleeve,sd=paint(16,16,(43,44,43),27,4);im.paste(sleeve,(0,0));d=ImageDraw.Draw(im)
  d.rectangle((0,15,15,15),fill=(34,36,35))
  # Warm skin directly below the sleeve, then the pale wrap and dark wrist band.
  d.rectangle((0,16,15,18),fill=(228,137,108));d.rectangle((2,16,5,18),fill=(240,155,123))
  d.rectangle((0,21,15,26),fill=(205,195,171));d.rectangle((0,21,15,21),fill=(178,163,137));d.rectangle((0,26,15,26),fill=(233,220,193));d.rectangle((2,23,10,23),fill=(216,206,180))
  d.rectangle((0,35,15,39),fill=(34,37,36));d.rectangle((0,35,15,35),fill=(45,46,43))
  # User-requested restrained skin contact shadows BELOW each3D ring.
  d.rectangle((0,27,15,27),fill=(211,148,115));d.rectangle((0,28,15,28),fill=(226,163,130))
  d.rectangle((0,40,15,40),fill=(207,145,111));d.rectangle((0,41,15,41),fill=(224,160,127))
  d.rectangle((0,46,15,47),fill=(220,150,116))
  if face=='front':
   x=11 if side=='L' else 3
   d.rectangle((x,44,x+1,47),fill=(179,111,81));d.rectangle((x,44,x,45),fill=(240,173,135))
  store('arm_'+side+'_'+face,im)
 im,d=paint(16,16,(44,45,44),26,3);store('arm_'+side+'_top',im)
 im,d=paint(16,16,SKIN,21,3);store('arm_'+side+'_bottom',im)

for side in ['L','R']:
 for face in ['front','back','side','inside']:
  im,d=paint(16,48,(48,51,49),51+len(regions),5)
  masks=[(1,2,5,5),(4,6,8,8),(11,2,14,5),(9,8,12,10),(0,16,3,19),(6,17,9,20),(12,16,15,18),(10,26,13,29),(1,28,4,31),(5,31,8,33),(0,36,15,38)]
  if face in ['side','inside']:masks=[(2,5,6,8),(8,9,12,11),(0,17,4,20),(9,20,12,22),(2,28,6,30),(10,30,14,32),(0,36,15,38)]
  if face=='back':masks=[(2,3,7,5),(10,6,14,9),(0,17,4,20),(5,22,8,24),(10,29,14,32),(0,36,15,38)]
  for j,(x0,y0,x1,y1) in enumerate(masks):
   if side=='R':x0,x1=15-x1,15-x0
   color=[(108,96,79),(128,107,87),(139,117,94)][j%3]
   d.rectangle((x0,y0,x1,y1),fill=color)
   d.rectangle((x0,y0,min(x1,x0+1),min(y1,y0+1)),fill=(58,60,55))
   if j%2==0:d.rectangle((min(x1,x0+2),min(y1,y0+1),min(x1,x0+3),min(y1,y0+2)),fill=(72,73,64))
  d.rectangle((0,12,15,13),fill=(35,38,36));d.rectangle((0,25,15,25),fill=(36,39,37))
  # A painted inner seam separates the two original touching leg blocks.
  if face=='front':
   seam=0 if side=='L' else 15
   d.rectangle((seam,0,seam,47),fill=(35,38,35))
  # Boots are painted onto the ORIGINAL leg block, no added sole/toe geometry.
  d.rectangle((0,39,15,40),fill=(42,43,38));d.rectangle((0,41,15,44),fill=(73,58,44));d.rectangle((0,44,15,45),fill=(108,80,58));d.rectangle((0,46,15,47),fill=(37,39,35))
  d.rectangle((3,42,6,43),fill=(122,91,64));d.rectangle((10,43,13,44),fill=(91,71,51))
  if face=='front':d.rectangle((seam,39,seam,47),fill=(29,32,29))
  store('leg_'+side+'_'+face,im)
 im,d=paint(16,16,(48,51,48),50,4);store('leg_'+side+'_top',im)
 im,d=paint(16,16,(35,37,33),52,3);store('leg_'+side+'_bottom',im)
# Explicitly requested3D clothing reuses this one atlas.
for name,color in [('wrap3d',(205,195,171)),('band3d',(34,37,36)),('shirt3d_edge',(35,37,35)),('pants3d_edge',(37,40,36))]:
 im,d=paint(16,8,color,88,3)
 if name=='wrap3d':
  d.rectangle((0,0,15,0),fill=(179,164,138));d.rectangle((0,7,15,7),fill=(231,218,189));d.rectangle((2,3,12,3),fill=(218,208,180))
 store(name,im)
# Layered3D hair palette sampled by eye against the reference's dark warm browns.
HAIR_3D=[(46,23,14),(55,27,16),(63,31,18),(39,19,13),(69,35,20),(50,25,15)]
for i,color in enumerate(HAIR_3D):
 im,d=paint(8,8,color,97+i,2)
 d.rectangle((1,0,6,0),fill=tuple(c+3 for c in color))
 d.rectangle((0,7,7,7),fill=tuple(max(0,c-5) for c in color))
 store('hair3d_'+str(i),im)
ATLAS.save(OUT/'survivor_atlas.png');(OUT/'atlas_regions.json').write_text(json.dumps(regions,indent=2))
print('Painted skin-only atlas:',len(regions),'regions')
