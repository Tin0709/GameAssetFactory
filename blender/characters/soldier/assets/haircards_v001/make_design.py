"""Hand-authored Minecraft hair cards; original pixel atlas, binary cutouts."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,math
D=Path(__file__).resolve().parent
atlas=Image.new('RGBA',(512,512),(55,30,21,0));cards=[]
HAIR=[(56,30,21),(63,34,24),(69,38,26),(49,27,20),(75,41,28)]
CLOTH=[(113,47,38),(125,53,42),(101,40,33),(133,58,46)]
def card(name,verts,w,h,polygon=None,kind='hair',seed=0):
 i=len(cards);x=4+(i%7)*72;y=4+(i//7)*72
 assert y+h+4<512
 palette=HAIR if kind=='hair' else CLOTH
 tile=Image.new('RGBA',(w,h),palette[seed%len(palette)]+(255,));draw=ImageDraw.Draw(tile)
 if kind=='hair':
  # Broad offset locks, no random speckles / subpixel grain.
  for yy in range(0,h,5):
   for xx in range(-3,w,6):
    offset=(yy//5%2)*3;shade=palette[((xx+3)//6+yy//5+seed)%len(palette)]
    draw.rectangle((xx+offset,yy,xx+offset+5,yy+4),fill=shade+(255,))
    if (xx//6+yy//5+seed)%3==0:
     draw.line((xx+offset+1,yy,xx+offset+4,yy),fill=tuple(min(255,c+5) for c in shade)+(255,))
 else:
  draw.rectangle((0,0,w-1,0),fill=tuple(c+12 for c in palette[seed%4])+(255,))
  if h>3:draw.rectangle((0,h-1,w-1,h-1),fill=CLOTH[2]+(255,))
  if h>6:
   for yy in range(5,h,7):draw.rectangle((1,yy,max(1,w-2),yy),fill=CLOTH[(seed+1)%4]+(255,))
  elif w>8:
   draw.line((2,h//2,w//2,h//2),fill=CLOTH[(seed+1)%4]+(255,))
 mask=Image.new('L',(w,h),0);md=ImageDraw.Draw(mask);md.polygon(polygon or [(0,0),(w-1,0),(w-1,h-1),(0,h-1)],fill=255)
 tile.putalpha(mask)
 # One-pixel shadow follows the cut silhouette; fully binary alpha stays crisp.
 if kind=='hair':
  for xx in range(w):
   ys=[yy for yy in range(h) if mask.getpixel((xx,yy))]
   if ys:
    yy=max(ys);c=tile.getpixel((xx,yy));tile.putpixel((xx,yy),tuple(max(0,a-9) for a in c[:3])+(255,))
 atlas.paste(tile,(x,y))
 # Extrude colour/alpha into2px gutter; UVs sample texel centres.
 atlas.paste(tile.resize((w+4,h+4),Image.Resampling.NEAREST),(x-2,y-2));atlas.paste(tile,(x,y))
 cards.append(dict(name=name,vertices=verts,region=[x,y,w,h],kind=kind,flat=True))
def front(name,x0,x1,z0,z1,y,w,h,poly=None,seed=0):card(name,[(x0,y,z0),(x1,y,z0),(x1,y,z1),(x0,y,z1)],w,h,poly,seed=seed)
def side(name,x,y0,y1,z0,z1,w,h,poly=None,seed=0):card(name,[(x,y0,z0),(x,y1,z0),(x,y1,z1),(x,y0,z1)],w,h,poly,seed=seed)
def stair_profile(profile,height):
 p=[(0,0),(len(profile)-1,0)];last=None
 for x in range(len(profile)-1,-1,-1):
  v=profile[x]
  if last is not None and last!=v:p.append((x+1,v))
  p.append((x,v));last=v
 return p
# Five connected flat cap faces; the unchanged painted head remains underneath.
fringe=[29,28,26,23,17,16,15,14,12,11,12,14,15,14,11,10,9,10,12,14,15,15,16,16,17,17,17,18,23,26,28,29,29,28]
front('Hair / front scalp + irregular fringe',-.239,.239,1.35,1.82,-.237,34,34,stair_profile(fringe,34),0)
for sign,label in [(1,'L'),(-1,'R')]:
 profile=[29,28,30,29,30,31,30,29,31,30,29,30,31,30,30,29,30,31,30,29,28,29,28,27,28,29,28,27,29,28,29,28,29,29]
 side('Hair / '+label+' side cap',sign*.238,-.237,.239,1.365,1.819,34,32,stair_profile(profile,32),1 if sign>0 else 3)
front('Hair / rear cap',-.239,.239,1.37,1.82,.238,34,32,stair_profile([29,30,29,30,31,30,29,30,31,30,29,29,30,31,30,31,30,29,30,31,30,29,30,29,30,31,30,29,30,29,30,29,28,29],32),2)
card('Hair / flat crown cap',[(-.239,-.237,1.82),(.239,-.237,1.82),(.239,.239,1.82),(-.239,.239,1.82)],34,34,seed=2)
# Two-dimensional broad fringe locks, staggered in depth8–15mm.
front('Hair / swept fringe right',-.248,-.015,1.575,1.825,-.251,17,18,[(0,0),(16,0),(16,8),(14,8),(14,11),(11,11),(11,13),(8,13),(8,15),(5,15),(5,17),(2,17),(2,14),(0,14)],1)
front('Hair / swept fringe left',-.020,.249,1.565,1.826,-.253,20,19,[(0,0),(19,0),(19,17),(17,17),(17,18),(15,18),(15,16),(12,16),(12,14),(9,14),(9,12),(7,12),(7,9),(4,9),(4,7),(0,7)],2)
front('Hair / central lifted lock',-.112,.041,1.61,1.841,-.263,11,17,[(0,1),(3,1),(3,0),(9,0),(9,2),(10,2),(10,10),(8,10),(8,13),(6,13),(6,16),(3,16),(3,14),(1,14),(1,11),(0,11)],1)
for sign,label in [(-1,'R'),(1,'L')]:
 x0,x1=(sign*.247-.026,sign*.247+.026)
 front('Hair / '+label+' flat temple lock',x0,x1,1.392,1.75,-.248,4,26,[(0,0),(3,0),(3,22),(2,22),(2,25),(1,25),(1,23),(0,23)],3)
# Two paper-thin crown sheets, stepped outlines rather than cubical tufts.
card('Hair / crown sweep A',[(-.247,-.215,1.833),(.064,-.215,1.833),(.064,.226,1.833),(-.247,.226,1.833)],22,31,[(1,1),(8,1),(8,0),(18,0),(18,2),(21,2),(21,27),(19,27),(19,30),(4,30),(4,29),(0,29),(0,5),(1,5)],1)
card('Hair / crown sweep B',[(-.09,-.224,1.845),(.247,-.224,1.845),(.247,.233,1.845),(-.09,.233,1.845)],24,32,[(2,0),(12,0),(12,1),(20,1),(20,3),(23,3),(23,28),(21,28),(21,31),(5,31),(5,30),(0,30),(0,5),(2,5)],2)
for sign,label in [(1,'L'),(-1,'R')]:
 side('Hair / '+label+' upper sheet',sign*.252,-.238,.112,1.47,1.831,25,26,[(1,0),(18,0),(18,1),(24,1),(24,20),(21,20),(21,23),(18,23),(18,25),(12,25),(12,23),(7,23),(7,21),(3,21),(3,19),(0,19),(0,3),(1,3)],1)
 side('Hair / '+label+' rear sheet',sign*.261,-.035,.248,1.397,1.808,20,29,[(0,0),(17,0),(17,2),(19,2),(19,24),(17,24),(17,27),(13,27),(13,28),(9,28),(9,26),(4,26),(4,24),(1,24),(1,22),(0,22)],2 if sign>0 else 0)
 side('Hair / '+label+' lower flat flick',sign*.268,-.135,.127,1.414,1.644,19,16,[(0,0),(18,0),(18,9),(16,9),(16,12),(13,12),(13,15),(8,15),(8,13),(3,13),(3,10),(0,10)],3)
front('Hair / rear lock A',-.249,.041,1.39,1.822,.252,21,31,[(0,2),(4,2),(4,0),(17,0),(17,2),(20,2),(20,24),(17,24),(17,27),(13,27),(13,30),(6,30),(6,28),(2,28),(2,25),(0,25)],1)
front('Hair / rear lock B',-.020,.252,1.395,1.817,.264,20,30,[(0,0),(16,0),(16,1),(19,1),(19,24),(17,24),(17,27),(14,27),(14,29),(8,29),(8,27),(4,27),(4,25),(0,25)],2)
# Two short flat crown tufts break the roof line without adding solid blocks.
card('Hair / loose crown tuft A',[(-.210,-.06,1.836),(-.070,-.06,1.836),(-.070,.01,1.855),(-.210,.01,1.855)],10,5,[(0,1),(3,1),(3,0),(7,0),(7,1),(9,1),(9,4),(0,4)],seed=1)
card('Hair / loose crown tuft B',[(.045,.10,1.844),(.160,.10,1.844),(.160,.165,1.859),(.045,.165,1.859)],8,5,[(0,1),(2,1),(2,0),(6,0),(6,1),(7,1),(7,4),(0,4)],seed=2)
# Wider flat cloth, tucked UNDER the unchanged central fringe and one side lock.
# Short planar ramps keep the ribbon continuous as it weaves behind the hair.
points=[(-.242,-.272),(-.125,-.272),(-.108,-.257),(.037,-.257),(.055,-.272),(.242,-.272),(.273,-.241),(.273,.010),(.255,.040),(.255,.120),(.273,.150),(.273,.241),(.242,.273),(-.242,.273),(-.273,.241),(-.273,-.241)]
for i,(a,b) in enumerate(zip(points,points[1:]+points[:1])):
 z=1.719 if (a[1]+b[1])/2<-.24 else 1.712
 width=math.dist(a,b);card('Bandana / wrap facet '+str(i+1),[(a[0],a[1],z-.05175),(b[0],b[1],z-.05175),(b[0],b[1],z+.05175),(a[0],a[1],z+.05175)],max(3,round(width/.014)),5,kind='bandana',seed=i%2)
# Flat crossed cloth at rear: no solid/block knot.
card('Bandana / flat tie',[(-.040,.279,1.669),(.040,.279,1.669),(.040,.279,1.733),(-.040,.279,1.733)],6,5,[(1,0),(4,0),(4,1),(5,1),(5,3),(4,3),(4,4),(1,4),(1,3),(0,3),(0,1),(1,1)],'bandana',1)
card('Bandana / tie fold',[(-.025,.282,1.675),(.027,.282,1.684),(.018,.282,1.731),(-.034,.282,1.722)],4,4,kind='bandana',seed=2)
def tail(label,sign):
 pts=[(sign*.014,.281,1.694),(sign*.063,.302,1.560),(sign*.108,.322,1.431 if sign>0 else 1.450)]
 for j,(a,b) in enumerate(zip(pts,pts[1:])):
  dx=b[0]-a[0];dz=b[2]-a[2];length=math.hypot(dx,dz);rx=-dz/length*.023;rz=dx/length*.023;ry=sign*.014
  # All four vertices of each segment are exactly coplanar.
  verts=[(b[0]-rx,b[1]-ry,b[2]-rz),(b[0]+rx,b[1]+ry,b[2]+rz),(a[0]+rx,a[1]+ry,a[2]+rz),(a[0]-rx,a[1]-ry,a[2]-rz)]
  poly=None if j==0 else [(0,0),(3,0),(3,8),(2,8),(2,9),(0,9)]
  card('Bandana / Tail.'+label+' segment '+str(j+1),verts,4,10,poly,'bandana',j+(0 if sign>0 else 1))
tail('L',-1);tail('R',1)
atlas.save(D/'soldier_hair_bandana_atlas.png');(D/'cards.json').write_text(json.dumps({'atlas_size':512,'cards':cards,'binary_alpha':True,'construction':'Single-sided geometric planes rendered double-sided, no extrusion or solidify'},indent=2)+'\n')
print('DESIGNED',sum(c['kind']=='hair' for c in cards),'hair cards',sum(c['kind']=='bandana' for c in cards),'bandana cards')
