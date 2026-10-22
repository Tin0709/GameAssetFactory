"""Derive restrained broad-pixel tiles from the actual local resource-pack members."""
from pathlib import Path
from collections import Counter
from zipfile import ZipFile
from PIL import Image
import io,hashlib,json
D=Path(__file__).resolve().parent
archive=Path('/Users/tin/Desktop/Game Dev/local_references/Dungeons II Style 0.7 JE.zip')
with ZipFile(archive) as z:
 raw={key:z.read('assets/minecraft/textures/block/'+key+'.png') for key in ['grass_block_top','grass_block_side','grass_block_side_overlay','dirt','stone']}
source={key:Image.open(io.BytesIO(value)).convert('RGBA') for key,value in raw.items()}
mask=source['grass_block_side_overlay']
grass=Counter(source['grass_block_side'].getpixel((x,y))[:3] for y in range(16) for x in range(16) if mask.getpixel((x,y))[3]).most_common(1)[0][0]
bases={'Grass':grass,'Dirt':Counter(source['dirt'].get_flattened_data()).most_common(1)[0][0][:3],'Stone':Counter(source['stone'].get_flattened_data()).most_common(1)[0][0][:3]}
strength=.25

def subdued(image,base,reference=None):
 out=Image.new('RGBA',(16,16))
 reference=reference or base
 for y in range(16):
  for x in range(16):
   pixel=image.getpixel((x,y))
   out.putpixel((x,y),tuple(round(max(0,min(255,base[c]+strength*(pixel[c]-reference[c])))) for c in range(3))+(255,))
 return out

top=subdued(source['grass_block_top'],grass,(148,148,148))
dirt=subdued(source['dirt'],bases['Dirt'])
stone=subdued(source['stone'],bases['Stone'])
side=subdued(source['grass_block_side'],bases['Dirt'])
for y in range(16):
 for x in range(16):
  if mask.getpixel((x,y))[3]:
   # Retain the exact pack boundary and low-contrast broad source patches.
   pixel=source['grass_block_side'].getpixel((x,y))
   side.putpixel((x,y),tuple(round(grass[c]+strength*(pixel[c]-grass[c])) for c in range(3))+(255,))
tiles={'GrassTop':top,'GrassSide':side,'Dirt':dirt,'Stone':stone}
atlas=Image.new('RGBA',(80,20));rects={}
for i,(key,im) in enumerate(tiles.items()):
 for y in range(20):
  for x in range(20):atlas.putpixel((i*20+x,y),im.getpixel((max(0,min(15,x-2)),max(0,min(15,y-2)))))
 rects[key]=[(i*20+2)/80,2/20,(i*20+18)/80,18/20]
atlas.save(D/'Soft_Blocks_MD2_Atlas.png')
manifest={'status':'Pending','revision':'soft_texture_r2','source_zip':str(archive),'source_zip_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'source_sha256':{key:hashlib.sha256(value).hexdigest() for key,value in raw.items()},'contrast_strength':strength,'logical_tile_pixels':16,'padding_pixels':2,'atlas_size':[80,20],'atlas_rects':rects,'grass_edge':'Exact original grass_block_side_overlay alpha silhouette, cap depth3–6/16block','blocks':{}}
for key,base in bases.items():
 manifest['blocks'][key]={'srgb':list(base),'hex':'#'+''.join(f'{c:02X}' for c in base),'method':'Most frequent RGB in actual pack '+('grass_block_side pixels masked by grass_block_side_overlay' if key=='Grass' else key.lower()+'.png'),'material_count':1,'texture_nodes':1,'size_m':[1,1,1],'triangles':12}
(D/'palette.json').write_text(json.dumps(manifest,indent=2))
print('Soft blocks palette',bases,'contrast',strength)
