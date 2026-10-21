"""Authored coarse dirt, real cutout rips and rigid flat cloth tabs; no noise."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import json, math

D = Path(__file__).resolve().parent
R = D.parents[4]
regions = json.loads((R / 'blender/characters/player/reviews/survivor_reference_v001/atlas_regions.json').read_text())
source = Image.open(D / 'source_skin_atlas.png').convert('RGB')
dirty = source.copy()

def stain(tile, patches, strength=.48):
    x,y,w,h = regions[tile]
    im = dirty.crop((x,y,x+w,y+h))
    for px,py,pw,ph in patches:
        mask = Image.new('L', (w,h), 0)
        d = ImageDraw.Draw(mask)
        d.polygon([(px+1,py),(px+pw-1,py),(px+pw-1,py+2),(px+pw,py+2),
                   (px+pw,py+ph-2),(px+pw-2,py+ph-2),(px+pw-2,py+ph),
                   (px,py+ph),(px,py+2),(px+1,py+2)], fill=round(255*strength))
        im.paste(Image.new('RGB',(w,h),(80,73,58)), (0,0), mask)
    dirty.paste(im,(x,y))

stain('shirt_front', [(2,5,5,7),(13,12,4,6),(3,28,4,9),(24,30,5,6),(11,40,5,5),(26,43,4,4)])
stain('shirt_back', [(5,7,5,7),(23,16,4,6),(2,30,5,8),(15,37,5,7)], .40)
stain('shirt_side', [(4,12,4,9),(20,27,5,8),(9,42,6,5)], .42)
stain('shirt_top', [(2,3,5,5),(22,8,5,6)], .32)
for side in ['L','R']:
    for face in ['front','back','side','inside']:
        stain('arm_'+side+'_'+face, [(2 if side=='L' else 10,3,3,6),(8,11,4,4)], .39)
        stain('leg_'+side+'_'+face, [(2,5,4,5),(9,21,4,7),(1,31,5,6)], .22)
        x,y,w,h = regions['leg_'+side+'_'+face]
        im=dirty.crop((x,y,x+w,y+h));d=ImageDraw.Draw(im)
        d.rectangle((2,42,6,42),fill=(121,99,75));d.rectangle((10,44,14,44),fill=(101,85,65))
        d.line((1,40,5,40),fill=(71,68,53));dirty.paste(im,(x,y))

# Polygon coordinates are logical pixels in the existing garment UV tiles.
rips = {
 'shirt_front': [ [(24,6),(26,6),(26,8),(28,8),(28,9),(25,9),(25,11),(23,11),(23,8),(24,8)],
                  [(6,37),(8,37),(8,40),(6,40),(6,42),(4,42),(4,40),(5,40),(5,38),(6,38)],
                  [(24,45),(26,45),(26,47),(28,47),(28,48),(22,48),(22,47),(24,47)] ],
 'shirt_back': [ [(9,18),(12,18),(12,20),(14,20),(14,21),(10,21),(10,22),(8,22),(8,20),(9,20)],
                [(3,46),(5,46),(5,48),(1,48),(1,47),(3,47)] ],
 'shirt_side': [ [(20,45),(23,45),(23,48),(18,48),(18,47),(20,47)] ],
 'arm_L_front': [ [(1,13),(3,13),(3,15),(5,15),(5,16),(0,16),(0,15),(1,15)],
                   [(12,14),(14,14),(14,16),(11,16),(11,15),(12,15)] ],
 'arm_R_front': [ [(10,13),(12,13),(12,15),(14,15),(14,16),(9,16),(9,15),(10,15)],
                   [(1,14),(3,14),(3,16),(0,16),(0,15),(1,15)] ],
 'arm_L_side': [ [(5,14),(8,14),(8,16),(4,16),(4,15),(5,15)] ],
 'arm_R_side': [ [(9,14),(12,14),(12,16),(8,16),(8,15),(9,15)] ],
 'leg_R_front': [ [(3,16),(7,16),(7,18),(5,18),(5,19),(2,19),(2,18),(3,18)] ],
 'leg_L_front': [ [(10,27),(12,27),(12,28),(14,28),(14,30),(12,30),(12,31),(9,31),(9,29),(10,29)] ],
 'leg_L_side': [ [(4,20),(6,20),(6,22),(3,22),(3,21),(4,21)] ],
 'leg_R_back': [ [(9,24),(11,24),(11,26),(8,26),(8,25),(9,25)] ]
}
body = dirty.copy()
cloth = dirty.convert('RGBA')
hole_pixels = 0
for name,polys in rips.items():
    x,y,w,h=regions[name];mask=Image.new('L',(w,h),0);draw=ImageDraw.Draw(mask)
    for poly in polys:draw.polygon(poly,fill=255)
    # The opaque inner cuboid has a slightly larger skin patch below the hole.
    # The outer garment really cuts out, so the exposed skin sits 15-28mm deeper.
    expanded=mask.filter(ImageFilter.MaxFilter(3))
    inner=body.crop((x,y,x+w,y+h));inner.paste((226,157,124),(0,0,w,h),expanded)
    body.paste(inner,(x,y))
    outer=cloth.crop((x,y,x+w,y+h));rim=Image.new('L',(w,h),0)
    ImageDraw.Draw(rim).bitmap((0,0),expanded,fill=255)
    outer.paste((38,38,31,255),(0,0,w,h),rim)
    alpha=Image.new('L',(w,h),255)
    alpha.paste(0,(0,0,w,h),mask);outer.putalpha(alpha);cloth.paste(outer,(x,y))
    hole_pixels += sum(v>0 for v in mask.getdata())

cards=[]
def tab(name,bone,top,u,down,width,length,kind='shirt',seed=0):
    ul=math.sqrt(sum(v*v for v in u));dl=math.sqrt(sum(v*v for v in down))
    u=tuple(v/ul for v in u);down=tuple(v/dl for v in down)
    def pt(a,b):return [top[k]+a*width*.5*u[k]+b*length*down[k] for k in range(3)]
    verts=[pt(-1,1),pt(1,1),pt(1,0),pt(-1,0)]
    i=len(cards);x=4+(i%15)*32;y=134+(i//15)*32;w=10;h=14
    tile=Image.new('RGBA',(w,h),(39,41,38,255) if kind=='shirt' else (50,53,47,255))
    d=ImageDraw.Draw(tile)
    if kind=='pants':
        d.rectangle((1,2,4,5),fill=(101,92,73,255));d.rectangle((6,7,9,10),fill=(81,77,62,255))
    else:d.rectangle((2,4,5,8),fill=(56+seed%3*3,55+seed%3*2,45+seed%3,255))
    d.line((1,0,8,0),fill=(67,64,51,255));d.rectangle((3,10,6,12),fill=(58,56,45,255))
    mask=Image.new('L',(w,h));md=ImageDraw.Draw(mask)
    md.polygon([(0,0),(9,0),(9,7),(8,7),(8,10),(6,10),(6,13),(4,13),(4,11),(1,11),(1,9),(0,9)],fill=255)
    tile.putalpha(mask)
    cloth.paste(tile.resize((w+4,h+4),Image.Resampling.NEAREST),(x-2,y-2));cloth.paste(tile,(x,y))
    cards.append({'name':name,'bone':bone,'vertices':verts,'region':[x,y,w,h],'garment':kind})

for i,(x,w,h) in enumerate([(-.208,.046,.047),(-.133,.054,.058),(-.018,.042,.037),(.103,.064,.051),(.211,.043,.045)]):
    tab('Shirt / loose front hem '+str(i+1),'Chest',(x,-.127, .710),(1,0,0),(.07 if i%2 else -.07,-.31,-1),w,h,seed=i)
for i,x in enumerate([-.180,.012,.174]):tab('Shirt / rear hem '+str(i+1),'Chest',(x,.128,.707),(1,0,0),(.10,.28,-1),.051,.046+i*.006,seed=i)
for sign,label in [(-1,'R'),(1,'L')]:
    tab('Shirt / '+label+' side hem','Chest',(sign*.239,.006,.711),(0,1,0),(sign*.33,.08,-1),.059,.048,seed=1)
    cx=sign*.309375;bone='Arm.'+label
    for j,dx in enumerate([-.054,.052]):tab('Sleeve / '+label+' front edge '+str(j+1),bone,(cx+dx,-.128,1.154),(1,0,0),(.08,-.32,-1),.034+j*.009,.046+j*.009,seed=j)
    tab('Sleeve / '+label+' outer edge',bone,(cx+sign*.099,.011,1.151),(0,1,0),(sign*.40,0,-1),.046,.048,seed=2)
    tab('Sleeve / '+label+' back edge',bone,(cx,.128,1.151),(1,0,0),(-.12,.29,-1),.048,.041,seed=1)
    lx=sign*.1125;leg='Leg.'+label
    for j,(y,z) in enumerate([(-.061,.588),(.051,.402),(-.008,.279)]):
        tab('Trousers / '+label+' frayed side '+str(j+1),leg,(sign*.242,y,z),(0,1,0),(sign*.42,.09,-1),.046,.036+j*.005,'pants',j)
    for j,dx in enumerate([-.056,.062]):tab('Trousers / '+label+' cuff '+str(j+1),leg,(lx+dx,-.126,.172),(1,0,0),(.08,-.29,-1),.031,.040-j*.007,'pants',j)
    tab('Trousers / '+label+' rear nick',leg,(lx,.126,.377),(1,0,0),(.1,.25,-1),.042,.037,'pants',1)
tab('Shirt / chest torn flap','Chest',(.120,-.128,1.274),(1,0,0),(.18,-.45,-1),.044,.041,seed=2)
tab('Shirt / lower tear flap','Chest',(-.145,-.129,.808),(1,0,0),(-.16,-.33,-1),.032,.039,seed=1)
tab('Shirt / rear tear flap','Chest',(-.084,.129,1.090),(1,0,0),(.14,.35,-1),.038,.033,seed=0)
tab('Trousers / R knee torn flap','Leg.R',(-.151,-.141,.436),(1,0,0),(-.1,-.35,-1),.065,.036,'pants',0)
tab('Trousers / L shin torn flap','Leg.L',(.157,-.142,.294),(1,0,0),(.14,-.37,-1),.047,.041,'pants',1)

for name in ['head_front','head_left','head_right','head_back','head_top','head_bottom','wrap3d','band3d']:
    x,y,w,h=regions[name];box=(x,y,x+w,y+h)
    assert source.crop(box).tobytes()==body.crop(box).tobytes(),name
    assert source.crop(box).tobytes()==cloth.crop(box).convert('RGB').tobytes(),name
body.save(D/'worn_body_atlas.png');cloth.save(D/'worn_cloth_atlas.png')
(D/'cloth_cards.json').write_text(json.dumps({'atlas_size':512,'cards':cards,'rips':rips,'hole_pixels':hole_pixels},indent=2)+'\n')
print('WORN_ATLASES',len(cards),'flat cloth tabs;',hole_pixels,'logical cutout pixels; protected face/wrist tiles exact')
