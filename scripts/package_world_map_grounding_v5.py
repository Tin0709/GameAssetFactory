"""Package actual Godot V4/V5 pixels and preservation checks."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image, ImageChops, ImageDraw, ImageStat

ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'game_mobile_3d/.validation/world_map/grounding_v5'
OUT=ROOT/'docs/validation/world_map/grounding_v5'
OUT.mkdir(parents=True,exist_ok=True)

def panel(label,crop=None,width=640):
    frames=[Image.open(RAW/f'{p}_{label}.png').convert('RGB') for p in ['before','after']]
    if crop:frames=[im.crop(crop) for im in frames]
    h=round(frames[0].height*width/frames[0].width)
    canvas=Image.new('RGB',(width*2,h+32),(25,29,28));draw=ImageDraw.Draw(canvas)
    for i,im in enumerate(frames):
        canvas.paste(im.resize((width,h),Image.Resampling.NEAREST if crop else Image.Resampling.LANCZOS),(i*width,32))
        draw.text((i*width+12,10),'BEFORE - V4' if i==0 else 'AFTER - V5 TIGHT CONTACT',fill='white')
    name='closeup' if crop else 'comparison'
    canvas.save(OUT/f'{name}.png')

metrics={'phone_verified':False,'synthetic_frames':False,'views':{}}
for name in ['gameplay','stairs','stone','cliffs','grove']:
    frames=[]
    for prefix in ['before','after']:
        source=RAW/f'{prefix}_{name}.png';shutil.copyfile(source,OUT/source.name)
        frames.append(Image.open(source).convert('RGB'))
    diff=ImageChops.difference(*frames)
    metrics['views'][name]={'mean_abs_rgb_delta_255':ImageStat.Stat(diff).mean,'changed_pixels':sum(c!=(0,0,0) for c in diff.get_flattened_data())}
panel('stairs')
panel('stairs',crop=(710,285,950,480),width=480)
for prefix in ['before','after']:
    shutil.copyfile(RAW/f'{prefix}_checks.json',OUT/f'{prefix}_checks.json')
metrics['probe']=json.loads((RAW/'after_checks.json').read_text())
assert not metrics['probe']['failures']
shutil.copyfile(ROOT/'game_mobile_3d/.validation/world_map/seams/checks.json',OUT/'seam_checks.json')
manifest_path=ROOT/'game_mobile_3d/assets/environment/world_map_v1/manifest.json'
assets=json.loads(manifest_path.read_text())['assets']
for asset in assets.values():
    assert hashlib.sha256((manifest_path.parent/asset['file']).read_bytes()).hexdigest()==asset['sha256']
metrics['preserved_source_glbs']=len(assets)
metrics['frozen_v1_sha256']=hashlib.sha256((ROOT/'exports/graphics/meadow_daylight_v1.zip').read_bytes()).hexdigest()
assert metrics['frozen_v1_sha256']=='a6521b281f82bd3ab9be46a62d303cf968affb842b658a4d4120508f868963a4'
v4=(ROOT/'game_mobile_3d/assets/graphics/meadow_daylight_v4/preset.tres').read_text()
v5=(ROOT/'game_mobile_3d/assets/graphics/meadow_daylight_v5/preset.tres').read_text()
assert v4.split('sun_settings = ')[1].split('shadow_atlas_size')[0]==v5.split('sun_settings = ')[1].split('shadow_atlas_size')[0]
metrics['sun_settings_unchanged']=True
(OUT/'pixel_checks.json').write_text(json.dumps(metrics,indent=2))
print(json.dumps(metrics,indent=2))
