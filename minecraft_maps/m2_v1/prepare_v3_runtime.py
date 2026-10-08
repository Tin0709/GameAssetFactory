"""Migrate approved V3 visuals while retaining all saved M2 source cells exactly."""
from pathlib import Path
from PIL import Image
import json,shutil,hashlib
ROOT=Path(__file__).resolve().parents[2]
STUDY=ROOT/'blender/environment/studies/dungeons_ground_style_v2'
OUT=ROOT/'game_mobile_3d/assets/environment/litematic_m2_v2'
OLD=OUT.parent/'litematic_m2_v1'
OUT.mkdir(exist_ok=True)
REGIONS={'grass_top_0':(2,2,32,32),'grass_top_1':(38,2,32,32),'grass_top_2':(74,2,32,32),'grass_top_3':(110,2,32,32),'dirt':(146,2,32,32),'stone':(182,2,32,32),'grass_side':(218,2,32,32),'grass':(2,38,32,32),'tall_grass':(38,38,32,64)}
atlas=Image.new('RGBA',(256,128))
for n,(x,y,w,h) in REGIONS.items():
    im=Image.open(STUDY/'v3_textures'/(n+'.png')).convert('RGBA')
    assert im.size==(w,h)
    atlas.paste(im,(x,128-y-h))
    for dy in range(-2,h+2):
        for dx in range(-2,w+2):
            atlas.putpixel((x+dx,128-y-h+dy),im.getpixel((min(w-1,max(0,dx)),min(h-1,max(0,dy)))))
atlas.save(OUT/'meadow_m2_atlas.png')
shutil.copyfile(OLD/'m2_grass.gdshader',OUT/'m2_grass.gdshader')
(OUT/'atlas_regions.json').write_text(json.dumps({'size':[256,128],'blender_bottom_up_regions':REGIONS,'source':'approved V3 original textures'},indent=2))
# Keep current cells, dimensions, pairing, source SHA and metadata byte-for-byte semantically.
r=json.loads((OLD/'runtime_map.json').read_text())
files={'minecraft:dirt':'dirt_block_di_v3.glb','minecraft:grass_block[snowy=false]':'grass_block_di_v3.glb','minecraft:stone':'stone_block_di_v3.glb','minecraft:short_grass':'grass_di_v3.glb','minecraft:tall_grass[half=lower]':'tall_grass_2block_di_v3.glb','minecraft:tall_grass[half=upper]':'tall_grass_2block_di_v3.glb'}
for e in r['registry']:
    name=files[e['state']];e['asset']='res://assets/environment/litematic_m2_v2/'+name
    e['sha256']=hashlib.sha256((OUT/name).read_bytes()).hexdigest() if (OUT/name).exists() else 'pending export'
(OUT/'runtime_map.json').write_text(json.dumps(r,separators=(',',':')))
(OUT/'asset_registry.json').write_text(json.dumps({'entries':r['registry'],'unsupported':[],'style':'User-approved Dungeons V3'},indent=2))
shutil.copyfile(OLD/'missing_assets.json',OUT/'missing_assets.json')
print('V3 atlas/package ready; source cells preserved:',len(r['cells']))
