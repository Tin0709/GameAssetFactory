"""Package native GPU contact comparisons; never regenerate or edit source art."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image, ImageChops, ImageDraw, ImageStat

ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'game_mobile_3d/.validation/world_map/contact_v4'
OUT=ROOT/'docs/validation/world_map/contact_v4'
OUT.mkdir(parents=True,exist_ok=True)

def panel(first,second,output,crop=None,width=640):
    frames=[Image.open(p).convert('RGB') for p in [first,second]]
    if crop:frames=[im.crop(crop) for im in frames]
    height=round(frames[0].height*width/frames[0].width)
    canvas=Image.new('RGB',(width*2,height+32),(25,29,28))
    draw=ImageDraw.Draw(canvas)
    for i,im in enumerate(frames):
        canvas.paste(im.resize((width,height),Image.Resampling.NEAREST if crop else Image.Resampling.LANCZOS),(i*width,32))
        draw.text((i*width+12,10),'BEFORE' if i==0 else 'AFTER - CONTACT V4',fill='white')
    canvas.save(output)

metrics={'phone_verified':False,'synthetic_game_frames':False,'views':{}}
for name in ['gameplay','stairs','stone','cliffs','grove']:
    for prefix in ['before','after']:
        shutil.copyfile(RAW/f'{prefix}_{name}.png',OUT/f'{prefix}_{name}.png')
    a=Image.open(RAW/f'before_{name}.png').convert('RGB')
    b=Image.open(RAW/f'after_{name}.png').convert('RGB')
    diff=ImageChops.difference(a,b)
    metrics['views'][name]={'mean_abs_rgb_delta_255':ImageStat.Stat(diff).mean,
                           'changed_pixels':sum(p!=(0,0,0) for p in diff.get_flattened_data())}
panel(RAW/'before_stairs.png',RAW/'after_stairs.png',OUT/'comparison.png')
panel(RAW/'before_stone.png',RAW/'after_stone.png',OUT/'stone_closeup.png',crop=(400,100,850,420))
panel(RAW/'before_corner_fix/after_stairs.png',RAW/'after_stairs.png',OUT/'corner_gap_fix.png',crop=(710,285,950,480),width=480)
for prefix in ['before','after']:
    shutil.copyfile(RAW/f'{prefix}_checks.json',OUT/f'{prefix}_checks.json')
shutil.copyfile(ROOT/'game_mobile_3d/.validation/world_map/seams/checks.json',OUT/'seam_checks.json')
metrics['probe']=json.loads((RAW/'after_checks.json').read_text())
assert not metrics['probe']['failures']
manifest_path=ROOT/'game_mobile_3d/assets/environment/world_map_v1/manifest.json'
manifest=json.loads(manifest_path.read_text())
for asset in manifest['assets'].values():
    path=manifest_path.parent/asset['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==asset['sha256'],path
metrics['source_glbs_preserved']=len(manifest['assets'])
archive=ROOT/'exports/graphics/meadow_daylight_v1.zip'
metrics['frozen_v1_sha256']=hashlib.sha256(archive.read_bytes()).hexdigest()
assert metrics['frozen_v1_sha256']=='a6521b281f82bd3ab9be46a62d303cf968affb842b658a4d4120508f868963a4'
(OUT/'pixel_checks.json').write_text(json.dumps(metrics,indent=2))
print(json.dumps(metrics,indent=2))
