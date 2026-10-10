"""Package and decode actual three-view renders; no synthesized frames."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,cv2,numpy as np,hashlib,sys
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/jump_takeoff_test'
FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24);SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
VIEWS=['front','three_quarter','side'];PHASES=[(1,'READY'),(7,'LIGHT LOAD'),(9,'SOFT BOUNCE'),(14,'COMPRESS'),(17,'PUSH'),(19,'LAST SUPPORT'),(20,'LIFTOFF'),(24,'EARLY FLIGHT')]
def composite(f):
    im=Image.new('RGB',(1920,720),(23,29,35));d=ImageDraw.Draw(im)
    d.text((16,5),'JUMP TAKEOFF TEST / FRONT + THREE-QUARTER + SIDE / 1x SPEED',font=FONT,fill='white')
    for i,view in enumerate(VIEWS):
        im.paste(Image.open(OUT/'frames'/view/f'{f:03d}.png').convert('RGB'),(i*640,42))
        d.text((i*640+12,47),view.replace('_',' ').upper(),font=SMALL,fill=(228,235,240))
    phase=next(label for start,label in reversed(PHASES) if f>=start)
    d.text((16,689),f'F{f:02d}/24 | {phase} | 30 FPS | Takeoff only / early flight / PENDING REVIEW',font=SMALL,fill=(178,219,218))
    return im
def encode(images,name):
    folder=TMP/'encode'/name;folder.mkdir(parents=True,exist_ok=True)
    for count,im in enumerate(images,1):im.save(folder/f'{count:04d}.png')
    encoder=OUT.parent/'lowerbody_recovery_test/encode_review.py'
    with (TMP/f'encode_{name}.log').open('w') as log:subprocess.run([sys.argv[1],'-b','--factory-startup','--python-exit-code','1','--python',str(encoder),'--',str(folder),str(OUT/(name+'.mp4')),str(count)],stdout=log,stderr=subprocess.STDOUT,check=True)
    return count
def run():
    assert all((OUT/'frames'/v/f'{f:03d}.png').is_file() for v in VIEWS for f in range(1,25))
    frames=[composite(f) for f in range(1,25)]
    counts={'jump_takeoff_1x':encode(frames,'jump_takeoff_1x')}
    for v in VIEWS:counts[v+'_1x']=encode([Image.open(OUT/'frames'/v/f'{f:03d}.png').convert('RGB') for f in range(1,25)],v+'_1x')
    replay=[]
    for cycle in range(3):
        replay+=frames
        hold=frames[-1].copy();d=ImageDraw.Draw(hold);d.rectangle((0,682,1920,720),fill=(23,29,35));d.text((16,689),'TEST ENDS IN EARLY FLIGHT / HOLD / replay cut follows - no landing authored',font=SMALL,fill='white')
        replay += [hold]*12
    counts['jump_takeoff_review']=encode(replay,'jump_takeoff_review')
    sheet=Image.new('RGB',(1600,710),(23,29,35));d=ImageDraw.Draw(sheet)
    d.text((12,4),'SOFT LOAD / COMPRESSION / PUSH / LIFTOFF - TAKEOFF ONLY',font=FONT,fill='white')
    for col,(f,label) in enumerate(PHASES):
        d.text((col*200+5,39),f'F{f:02d} {label}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):sheet.paste(Image.open(OUT/'frames'/v/f'{f:03d}.png').convert('RGB').resize((200,200),Image.Resampling.LANCZOS),(col*200,65+row*210))
    sheet.save(OUT/'takeoff_pose_sheet.jpg',quality=95)
    # Same exact pose/camera setup comparison with the approved recovery source.
    compare=Image.new('RGB',(1280,720),(23,29,35));d=ImageDraw.Draw(compare)
    d.text((12,4),'APPROVED RECOVERY F18 / NEW TAKEOFF COMPRESSION F14',font=FONT,fill='white')
    for i,p in enumerate([OUT.parent/'lowerbody_recovery_test/frames/three_quarter/018.png',OUT/'frames/three_quarter/014.png']):compare.paste(Image.open(p).convert('RGB'),(i*640,42))
    d.text((12,689),'Same character, camera, lighting and scale; different task poses / new takeoff pending review',font=SMALL,fill=(178,219,218));compare.save(OUT/'compression_comparison.jpg',quality=95)
    checks={};decoded=[]
    for name,count in counts.items():
        p=OUT/(name+'.mp4');cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);size=[int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))];n=0;errors=[]
        while True:
            ok,im=cap.read()
            if not ok:break
            if name=='jump_takeoff_1x':
                rgb=cv2.cvtColor(im,cv2.COLOR_BGR2RGB);errors.append(float(np.abs(rgb.astype('float32')-np.array(frames[n])).mean()))
                if n+1 in [1,9,14,19,20,24]:decoded.append(Image.fromarray(rgb).resize((960,360)))
            n+=1
        cap.release();assert n==count and fps==30,(name,n,fps)
        if errors:assert max(errors)<3
        checks[name]={'frames':n,'fps':fps,'size':size,'duration_s':n/fps,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'max_mean_rgb_decode_error':max(errors) if errors else None}
    strip=Image.new('RGB',(960,360*len(decoded)))
    for j,im in enumerate(decoded):strip.paste(im,(0,j*360))
    strip.save(OUT/'decoded_review_samples.jpg',quality=94)
    (OUT/'media_verification.json').write_text(json.dumps(checks,indent=2));print('Encoded and decoded all review videos',flush=True)
if __name__=='__main__':run()
