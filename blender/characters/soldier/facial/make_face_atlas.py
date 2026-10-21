"""Create a reversible review overlay; never edits the Soldier's original atlas."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
D=Path(__file__).resolve().parent;SRC=D.parents[1]/'player/reviews/survivor_reference_v001'
# D = soldier/facial; the original sibling player folder is under characters.
SRC=D.parents[1]/'player/reviews/survivor_reference_v001'
im=Image.open(SRC/'survivor_atlas.png').convert('RGBA');regions=json.loads((SRC/'atlas_regions.json').read_text());x,y,w,h=regions['head_front'];face=im.crop((x,y,x+w,y+h));fringe=[26,22,16,15,12,11,15,12,8,10,14,15,15,18,24,26]
for left in [4,19]:
 for yy in range(15,25):
  for xx in range(left,left+9):
   if yy==17:continue
   if yy<fringe[xx//2]:color=face.getpixel((xx,max(0,min(13,fringe[xx//2]-2))))
   else:
    # Same local skin palette, broad clean pixels; replace painted eye/brow only.
    color=face.getpixel((max(13,min(17,xx)),22))
   face.putpixel((xx,yy),color)
im.paste(face,(x,y));palette={'white':(249,241,222,255),'iris':(54,43,29,255),'iris_top':(28,27,23,255),'brow':(69,35,21,255),'brow_light':(81,42,25,255),'lid':(157,92,61,255)}
draw=ImageDraw.Draw(im);swatches={}
for i,(name,color) in enumerate(palette.items()):
 sx=480+(i%3)*10;sy=480+(i//3)*10;draw.rectangle((sx,sy,sx+7,sy+7),fill=color);swatches[name]=[(sx+3.5)/512,1-(sy+3.5)/512]
im.save(D/'soldier_face_atlas.png');(D/'face_atlas_regions.json').write_text(json.dumps({'head_front':regions['head_front'],'swatches':swatches},indent=2)+'\n');print('FACE_ATLAS_READY')
