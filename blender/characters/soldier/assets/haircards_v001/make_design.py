"""Hand-authored Minecraft hair cards; original pixel atlas, binary cutouts."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,math
D=Path(__file__).resolve().parent
atlas=Image.new('RGBA',(512,512),(55,30,21,0));cards=[]
HAIR=[(56,30,21),(63,34,24),(69,38,26),(49,27,20),(75,41,28)]
CLOTH=[(155,40,34),(171,46,37),(134,32,29),(184,52,41)]
def card(name,verts,w,h,polygon=None,kind='hair',seed=0,pixel_rows=None):
 i=len(cards)
 # Preserve the original44 tile slots, including the red bandana UVs.
 # Small new locks use the otherwise empty right side of each atlas cell.
 if i<44:x=4+(i%7)*72;y=4+(i//7)*72
 else:
  j=i-44;x=44+(j%7)*72;y=4+(j//7)*72
  assert w<=24 and h<=34
 assert y+h+4<512
 # Keep historical unused card slots exact; the new red applies only to bandana.
 palette=HAIR if kind=='hair' else CLOTH if kind=='bandana' else [(113,47,38),(125,53,42),(101,40,33),(133,58,46)]
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
  if h>3:draw.rectangle((0,h-1,w-1,h-1),fill=palette[2]+(255,))
  if h>6:
   for yy in range(5,h,7):draw.rectangle((1,yy,max(1,w-2),yy),fill=palette[(seed+1)%4]+(255,))
  elif w>8:
   draw.line((2,h//2,w//2,h//2),fill=palette[(seed+1)%4]+(255,))
 mask=Image.new('L',(w,h),0)
 if pixel_rows is not None:
  source=Image.new('L',(len(pixel_rows[0]),len(pixel_rows)),0)
  source.putdata([255 if c=='H' else 0 for row in pixel_rows for c in row])
  mask=source.resize((w,h),Image.Resampling.NEAREST)
 else:
  md=ImageDraw.Draw(mask);md.polygon(polygon or [(0,0),(w-1,0),(w-1,h-1),(0,h-1)],fill=255)
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
# New haircut follows the supplied skin's actual8x8 hair/outer-layer silhouettes.
# Only the silhouettes are used; all colour stays in the existing SOLDIER palette.
FRONT=['HHHHHHHH']*4+['HHH..HHH','H......H','H......H','........']
SIDE=['HHHHHHHH']*5+['H..HHHHH','H..HHHHH','..HHHHHH']
HAT_FRONT=['........','.HHHHHH.','HHHHHHHH','HHHHHHHH','HH.HH.HH','H...H..H','........','........']
HAT_R=['..HHH...','.HHHH...','HHHHHH.H','HHHHHHHH','.H.HHHHH','.....H.H','........','........']
HAT_L=['...H..H.','...H.HH.','H.HHHHHH','HHHHHH.H','H.H.HH.H','H...H..H','........','........']
HAT_BACK=['..H.....','.HHHH.H.','HHHHHHHH','HHHHHHHH','HHHHH.H.','H..H....','........','........']
def front_mask(name,x0,x1,z0,z1,y,rows,seed=0):
 card(name,[(x0,y,z0),(x1,y,z0),(x1,y,z1),(x0,y,z1)],32,32,seed=seed,pixel_rows=rows)
def side_mask(name,x,y0,y1,z0,z1,rows,seed=0):
 card(name,[(x,y0,z0),(x,y1,z0),(x,y1,z1),(x,y0,z1)],32,32,seed=seed,pixel_rows=rows)
# Five connected cap faces: compact classic Minecraft shape.
front_mask('Hair / reference front cap',-.237,.237,1.407,1.815,-.237,FRONT,0)
side_mask('Hair / reference R side cap',-.237,-.237,.237,1.35,1.815,SIDE,1)
side_mask('Hair / reference L side cap',.237,-.237,.237,1.35,1.815,SIDE,2)
front_mask('Hair / reference rear cap',-.237,.237,1.35,1.815,.237,['HHHHHHHH']*8,1)
card('Hair / reference crown cap',[(-.237,-.237,1.815),(.237,-.237,1.815),(.237,.237,1.815),(-.237,.237,1.815)],32,32,seed=2)
# The outer hair layer keeps the reference's stepped fringe. Narrow only the
# lowest centre pixel to fit the unchanged Soldier eyes' wider inner spacing.
front_rows=[''.join(c*4 for c in row) for row in HAT_FRONT for _ in range(4)]
for row in range(20,24):front_rows[row]=front_rows[row][:12]+'.'*2+'H'*4+'.'*6+front_rows[row][24:]
front_mask('Hair / reference stepped outer fringe',-.255,.255,1.420,1.826,-.254,front_rows,1)
side_mask('Hair / reference R outer layer',-.255,-.255,.255,1.35,1.826,[row[::-1] for row in HAT_R],2)
side_mask('Hair / reference L outer layer',.255,-.255,.255,1.35,1.826,HAT_L,1)
front_mask('Hair / reference rear outer layer',-.255,.255,1.35,1.826,.255,HAT_BACK,2)
card('Hair / reference outer crown',[(-.255,-.255,1.827),(.255,-.255,1.827),(.255,.255,1.827),(-.255,.255,1.827)],32,32,seed=1)
# Three recognisable uneven bang groups; centre lock stays between the eyes.
front('Hair / reference left bang',-.240,-.081,1.565,1.815,-.265,12,20,[(0,0),(11,0),(11,14),(9,14),(9,18),(6,18),(6,19),(1,19),(1,17),(0,17)],1)
front('Hair / reference long centre bang',-.029,.029,1.516,1.797,-.269,6,24,[(0,0),(5,0),(5,21),(4,21),(4,23),(1,23),(1,22),(0,22)],2)
front('Hair / reference right bang',.127,.241,1.560,1.816,-.265,9,20,[(0,0),(8,0),(8,18),(6,18),(6,19),(2,19),(2,17),(0,17)],1)
for sign,label in [(-1,'R'),(1,'L')]:
 front('Hair / reference '+label+' temple',sign*.231-.015,sign*.231+.015,1.426,1.733,-.261,4,24,[(0,0),(3,0),(3,21),(2,21),(2,23),(0,23)],3)
for sign,label in [(-1,'R'),(1,'L')]:
 side('Hair / reference '+label+' broad side lock',sign*.264,-.179,.110,1.477,1.778,20,22,[(0,0),(19,0),(19,16),(17,16),(17,19),(13,19),(13,21),(6,21),(6,20),(2,20),(2,17),(0,17)],1 if sign>0 else 2)
front('Hair / reference rear left lock',-.248,-.014,1.425,1.778,.262,16,25,[(0,0),(15,0),(15,19),(13,19),(13,23),(9,23),(9,24),(3,24),(3,22),(0,22)],1)
front('Hair / reference rear right lock',.006,.249,1.431,1.781,.264,17,25,[(0,0),(16,0),(16,21),(14,21),(14,23),(10,23),(10,24),(4,24),(4,22),(0,22)],2)
# Three low crown flicks keep the flatter roof line of the new reference.
card('Hair / reference crown flick A',[(-.176,-.119,1.826),(-.061,-.119,1.826),(-.061,-.041,1.851),(-.176,-.041,1.851)],9,7,[(0,0),(8,0),(8,5),(6,5),(6,6),(2,6),(2,5),(0,5)],seed=1)
card('Hair / reference crown flick B',[(.034,.044,1.828),(.146,.044,1.828),(.146,.124,1.851),(.034,.124,1.851)],8,7,seed=2)
card('Hair / reference crown flick C',[(-.083,.163,1.827),(.031,.163,1.827),(.031,.219,1.844),(-.083,.219,1.844)],8,6,seed=1)
assert len(cards)==22,'Keep the existing bandana atlas slots fixed'

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
# User refinement: the whole unchanged red accessory sits20mm lower.
for part in cards:
 if part['kind']=='bandana':
  part['vertices']=[(x,y,z-.020) for x,y,z in part['vertices']]
# Enlarge only the rear tie/fold/tails around the existing attachment point.
# The head wrap, hair, UVs and palette remain unchanged.
rear_tie_anchor=(0.,.279,1.694-.020)
for part in cards:
 if part['kind']=='bandana' and 'wrap facet' not in part['name']:
  part['vertices']=[tuple(rear_tie_anchor[k]+1.5*(v[k]-rear_tie_anchor[k]) for k in range(3)) for v in part['vertices']]

# Restrained bushiness accents around the new compact haircut, not curtain rows.
def tuft(name,top,u,d,width,height,seed=0):
 ul=math.sqrt(sum(a*a for a in u));dl=math.sqrt(sum(a*a for a in d))
 u=tuple(a/ul for a in u);d=tuple(a/dl for a in d)
 def pt(side,down):return tuple(top[k]+side*width*.5*u[k]+down*height*d[k] for k in range(3))
 poly=[(0,0),(9,0),(9,10),(8,10),(8,12),(6,12),(6,13),(2,13),(2,12),(0,12)]
 card('Hair / fluffy '+name,[pt(-1,1),pt(1,1),pt(1,0),pt(-1,0)],10,14,poly,seed=seed)
for i,(x,w,h,angle) in enumerate([(-.194,.061,.093,-9),(-.070,.059,.105,8),(.157,.060,.091,-10)]):
 a=math.radians(angle);tuft('upper fringe '+str(i+1),(x,-.250,1.817),(math.cos(a),0,math.sin(a)),(math.sin(a),-.66,-math.cos(a)),w,h,1+i%2)
for sign,label in [(-1,'R'),(1,'L')]:
 for j,(y,z,w,h) in enumerate([(-.143,1.795,.105,.111),(.027,1.647,.131,.132),(.173,1.516,.103,.102)]):
  tuft(label+' side tip '+str(j+1),(sign*.255,y,z),(0,1,0),(sign*.28,.08 if j%2 else -.09,-1),w,h,1+j%2)
 for j,(z,y) in enumerate([(1.591,-.234),(1.462,-.230)]):
  tuft(label+' temple wisp '+str(j+1),(sign*.239,y,z),(0,1,0),(sign*.27,-.11,-1),.079,.098 if j==0 else .076,1+j)
for i,(x,y,dy) in enumerate([(-.174,.080,-1),(.180,-.074,1),(-.011,-.173,1),(.098,.170,-1)]):
 tuft('roof edge '+str(i+1),(x,y,1.826),(1,0,0),(0,dy,.24),.094,.101,1+i%2)
for row,(z,h) in enumerate([(1.797,.106),(1.528,.112)]):
 for i,x in enumerate([-.174,.177]):
  tuft('rear edge '+str(row+1)+'-'+str(i+1),(x,.252,z),(1,0,0),((i-.5)*.15,.40,-1),.101,h,1+(row+i)%2)

atlas.save(D/'soldier_hair_bandana_atlas.png');(D/'cards.json').write_text(json.dumps({'atlas_size':512,'cards':cards,'binary_alpha':True,'construction':'Single-sided geometric planes rendered double-sided, no extrusion or solidify'},indent=2)+'\n')
print('DESIGNED',sum(c['kind']=='hair' for c in cards),'hair cards',sum(c['kind']=='bandana' for c in cards),'bandana cards')
