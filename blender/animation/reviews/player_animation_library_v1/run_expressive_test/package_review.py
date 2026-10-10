from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
OUT=Path(__file__).resolve().parent
TMP=OUT.parents[4]/'.validation/run_expressive_test'
font=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',25)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
views=['front','three_quarter','side']

def run():
    (TMP/'encode').mkdir(parents=True,exist_ok=True)
    for f in range(1,19):
        im=Image.new('RGB',(1920,720),(23,29,35));d=ImageDraw.Draw(im)
        d.text((20,6),'RUN_EXPRESSIVE_TEST  /  FRONT + THREE-QUARTER + SIDE  /  1x SPEED',font=font,fill='white')
        for j,v in enumerate(views):im.paste(Image.open(OUT/'frames/test'/v/f'{f:03d}.png').convert('RGB'),(j*640,42))
        d.text((20,689),f'F{f:02d}/18 | 30 FPS | 0.60 s cycle | six repeats | Blender-only / awaiting run review',font=small,fill=(178,219,218))
        for repeat in range(6):im.save(TMP/'encode'/f'{repeat*18+f:04d}.png')
    keyframes=[1,4,7,8,10,13,16,17]
    sheet=Image.new('RGB',(1600,690),(23,29,35));d=ImageDraw.Draw(sheet)
    d.text((12,4),'RUN / CONTACT - PASS - RELEASE - FLIGHT / LEFT-RIGHT ALTERNATION',font=font,fill='white')
    for col,f in enumerate(keyframes):
        d.text((col*200+8,40),f'F{f:02d}',font=small,fill='white')
        for row,v in enumerate(views):
            sheet.paste(Image.open(OUT/'frames/test'/v/f'{f:03d}.png').convert('RGB').resize((200,200),Image.Resampling.LANCZOS),(col*200,65+row*205))
    sheet.save(OUT/'run_pose_sheet.jpg',quality=95)
    for v in views:
        sheet=Image.new('RGB',(1440,780),(23,29,35));d=ImageDraw.Draw(sheet)
        for i in range(18):
            x=i%6*240;y=i//6*260
            d.text((x+6,y),f'{v} / F{i+1:02d}',font=small,fill='white')
            sheet.paste(Image.open(OUT/'frames/test'/v/f'{i+1:03d}.png').convert('RGB').resize((240,240)),(x,y+20))
        sheet.save(OUT/f'{v}_all_frames.jpg',quality=94)
    compare=Image.new('RGB',(1280,750),(23,29,35));d=ImageDraw.Draw(compare)
    d.text((12,4),'SOURCE SPRINT (TOP) / NEW RUN (BOTTOM) / MATCHED CAMERA',font=font,fill='white')
    for row,(variant,frames) in enumerate([('sprint',[1,4,7,10]),('test',[1,5,10,14])]):
        for col,f in enumerate(frames):
            compare.paste(Image.open(OUT/'frames'/variant/'three_quarter'/f'{f:03d}.png').convert('RGB').resize((320,320)),(col*320,65+row*345))
            d.text((col*320+8,40+row*345),f'{variant.upper()} / F{f:02d}',font=small,fill='white')
    compare.save(OUT/'baseline_comparison.jpg',quality=95)
    (OUT/'media_manifest.json').write_text(json.dumps({'video':'run_expressive_1x.mp4','views':views,'size':[1920,720],'fps':30,'frames':108,'cycles':6,'period_frames':18,'closing_frame_19_excluded':True,'kind':'Actual sequential Blender renders; no Godot integration'},indent=2))
    print('Packaged 54 final renders into three-view video frames and pose sheets.')
if __name__=='__main__':run()
