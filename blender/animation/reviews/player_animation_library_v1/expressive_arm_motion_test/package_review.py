"""Package actual Blender pixels, retaining the 30 FPS source timing."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
OUT=Path(__file__).resolve().parent
TMP=OUT.parents[4]/'.validation/expressive_arm_motion_test/encode'
TMP.mkdir(parents=True,exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',23)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
views=['front','three_quarter']
for f in range(1,25):
    image=Image.new('RGB',(1280,720),(23,29,35));d=ImageDraw.Draw(image)
    d.text((20,7),'EXPRESSIVE ARM MOTION TEST  /  FRONT + THREE-QUARTER',font=font,fill='white')
    for j,v in enumerate(views):image.paste(Image.open(OUT/'frames'/v/f'{f:03d}.png').convert('RGB'),(j*640,42))
    d.text((20,689),f'F{f:02d}/24  |  30 FPS / 1x speed  |  original Blender-only study / pending review',font=small,fill=(178,219,218))
    for repeat in range(3):image.save(TMP/f'{repeat*24+f:04d}.png')
sheet=Image.new('RGB',(1200,860),(23,29,35));d=ImageDraw.Draw(sheet)
for col,(f,label) in enumerate([(1,'NEUTRAL'),(7,'BACKWARD SWING'),(14,'FORWARD / OUTWARD')]):
    d.text((col*400+12,8),f'F{f:02d} / {label}',font=small,fill='white')
    for row,v in enumerate(views):
        im=Image.open(OUT/'frames'/v/f'{f:03d}.png').convert('RGB').resize((400,400),Image.Resampling.LANCZOS)
        sheet.paste(im,(col*400,35+row*405))
sheet.save(OUT/'three_pose_review.jpg',quality=95)
for v in views:
    sheet=Image.new('RGB',(1440,1000),(23,29,35));d=ImageDraw.Draw(sheet)
    for i in range(24):
        x=i%6*240;y=i//6*250
        sheet.paste(Image.open(OUT/'frames'/v/f'{i+1:03d}.png').convert('RGB').resize((230,230)),(x,y+20))
        d.text((x+8,y),f'{v} / F{i+1:02d}',font=small,fill='white')
    sheet.save(OUT/f'{v}_all_frames.jpg',quality=94)
(OUT/'media_manifest.json').write_text(json.dumps({'views':views,'source_frames_each':24,'fps':30,'mp4_frames':72,'repeats':3,'clip_seconds':2.4,'action_key_span_seconds':23/30,'encoded_one_pass_seconds':.8,'size':[1280,720],'kind':'Actual Blender Cycles renders; no runtime integration'},indent=2))
print('Packaged 48 rendered frames, 3-pose sheet and both complete frame sheets.')
