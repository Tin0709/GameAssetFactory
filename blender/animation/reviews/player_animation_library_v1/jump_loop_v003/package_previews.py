"""Package real sequential renders, no holds/cuts/duplicated closing frame."""
from pathlib import Path
import json,shutil,hashlib
import cv2
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/jump_loop_v003'
M=json.loads((OUT/'manifest.json').read_text());font=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
ref=OUT/'references';ref.mkdir(exist_ok=True)
source=Path('C:/Users/ADMIN/Videos/Screen Recordings/Screen Recording 2026-10-10 131138.mp4')
shutil.copy2(source,ref/'user_runtime_problem.mp4')
for name in ['clip_overview.jpg','clip_detail.jpg','v002_loop_failure.json']:shutil.copy2(TMP/name,ref/name)
metadata={'reference':{'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'frames':218,'fps':30,'size':[324,364]},'previews':{}}
for kind,c in M['cases'].items():
    folder=TMP/'encode'/kind;folder.mkdir(parents=True,exist_ok=True)
    for f in range(1,c['preview_end']+1):
        canvas=Image.new('RGB',(1280,586),(20,28,37));d=ImageDraw.Draw(canvas)
        for x,view in [(0,'gameplay'),(640,'side')]:canvas.paste(Image.open(TMP/'frames'/kind/view/f'{f:03d}.png'),(x,66))
        d.text((18,8),f'{kind.upper()} + JUMP LOOP V003  /  3/4 + SIDE',font=font,fill='white')
        phase=(f-1)%c['period'];cycle=(f-1)//c['period']+1
        d.text((18,38),'1x speed / 30 FPS / three continuous cycles / no hold or cut',font=small,fill=(141,218,208))
        d.text((18,552),f'Cycle {cycle}/3 | Phase F{phase+1:02d} | '+('GROUND / STEP' if phase<=c['take'] or phase>=c['land'] else 'AIR / FOOTWORK CONTINUES'),font=small,fill='white')
        canvas.save(folder/f'{f:04d}.png')
    metadata['previews'][kind]={'file':f'{kind}_loop_1x.mp4','frames':c['preview_end'],'fps':30,'size':[1280,586],'cycles':3}
    frames=[1,c['take']+1,c['take']+5,(c['take']+c['land'])//2+1,c['land']-3,c['land']+1,c['period'],c['period']+1]
    sheet=Image.new('RGB',(1280,600),(20,28,37));d=ImageDraw.Draw(sheet)
    d.text((18,8),kind.upper()+' + JUMP LOOP V003 / step through the air + actual loop join',font=font,fill='white')
    for i,f in enumerate(frames):
        x=i%4*320;y=48+i//4*272
        d.text((x+8,y+2),f'F{f:02d}'+(' / LOOP JOIN' if i>5 else ''),font=small,fill=(141,218,208))
        sheet.paste(Image.open(TMP/'frames'/kind/'side'/f'{f:03d}.png').resize((316,237),Image.Resampling.LANCZOS),(x+2,y+30))
    sheet.save(OUT/f'{kind}_contact_sheet.jpg',quality=94)
(OUT/'media_manifest.json').write_text(json.dumps(metadata,indent=2));print(json.dumps(metadata['previews'],indent=2))
