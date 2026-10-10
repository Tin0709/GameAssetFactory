"""Package actual Blender renders into review images and H.264 clips."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,cv2,hashlib
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/lowerbody_recovery_test'
FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24)
SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
VIEWS=['front','three_quarter','side']
PHASES=[(1,'READY'),(7,'LEFT LOAD'),(10,'REPLANT'),(13,'CONTACT'),(18,'ABSORB'),(22,'FOLLOW'),(33,'RECOVER'),(42,'SETTLE')]

def frame(f):
    im=Image.new('RGB',(1920,720),(23,29,35));d=ImageDraw.Draw(im)
    d.text((20,5),'LOWERBODY RECOVERY TEST / FRONT + THREE-QUARTER + SIDE / 1x SPEED',font=FONT,fill='white')
    for i,v in enumerate(VIEWS):
        im.paste(Image.open(OUT/'frames'/v/f'{f:03d}.png').convert('RGB'),(i*640,42))
        d.text((i*640+14,48),v.replace('_',' ').upper(),font=SMALL,fill=(228,235,240))
    phase=next(label for start,label in reversed(PHASES) if f>=start)
    d.text((20,689),f'F{f:02d}/48 | {phase} | 30 FPS | Grounded one-shot / Blender only / pending review',font=SMALL,fill=(178,219,218))
    return im

def encode(images,path,blender):
    folder=TMP/'encode'/path.stem;folder.mkdir(parents=True,exist_ok=True)
    count=0
    for count,im in enumerate(images,1):im.save(folder/f'{count:04d}.png')
    assert count
    with (TMP/f'encode_{path.stem}.log').open('w') as log:
        subprocess.run([blender,'-b','--factory-startup','--python',str(OUT/'encode_review.py'),'--',str(folder),str(path),str(count)],stdout=log,stderr=subprocess.STDOUT,check=True)

def run(blender):
    assert all((OUT/'frames'/v/f'{f:03d}.png').exists() for v in VIEWS for f in range(1,49))
    composite=[frame(f) for f in range(1,49)]
    encode(composite,OUT/'lowerbody_recovery_1x.mp4',blender)
    for view in VIEWS:
        encode((Image.open(OUT/'frames'/view/f'{f:03d}.png').convert('RGB') for f in range(1,49)),OUT/f'{view}_1x.mp4',blender)
    # Each reset is explicitly a replay cut, not a claimed seamless gait cycle.
    def replays():
        for repeat in range(3):
            for im in composite:
                im=im.copy();ImageDraw.Draw(im).text((1530,689),f'PLAY {repeat+1}/3',font=SMALL,fill='white');yield im
            hold=composite[-1].copy();ImageDraw.Draw(hold).rectangle((0,682,1920,720),fill=(23,29,35))
            ImageDraw.Draw(hold).text((20,689),'END OF ONE-SHOT / replay cut to initial stance follows',font=SMALL,fill='white')
            for _ in range(15):yield hold
    encode(replays(),OUT/'lowerbody_recovery_review.mp4',blender)
    sheet=Image.new('RGB',(1600,690),(23,29,35));d=ImageDraw.Draw(sheet)
    d.text((12,5),'LOWER BODY / WEIGHT SHIFT - CONTACT - ABSORPTION - RECOVERY',font=FONT,fill='white')
    for col,(f,label) in enumerate(PHASES):
        d.text((col*200+5,39),f'F{f:02d} {label}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):sheet.paste(Image.open(OUT/'frames'/v/f'{f:03d}.png').convert('RGB').resize((200,200),Image.Resampling.LANCZOS),(col*200,65+row*205))
    sheet.save(OUT/'recovery_pose_sheet.jpg',quality=95)
    for v in VIEWS:
        sheet=Image.new('RGB',(1600,1320),(23,29,35));d=ImageDraw.Draw(sheet)
        for j in range(48):
            x=j%8*200;y=j//8*220;d.text((x+5,y),f'{v} F{j+1:02d}',font=SMALL,fill='white')
            sheet.paste(Image.open(OUT/'frames'/v/f'{j+1:03d}.png').convert('RGB').resize((200,200)),(x,y+20))
        sheet.save(OUT/f'{v}_all_frames.jpg',quality=94)
    # Same setup as approved run. Shows support phases, without claiming equal tasks.
    compare=Image.new('RGB',(1600,930),(23,29,35));d=ImageDraw.Draw(compare)
    d.text((12,4),'APPROVED RUN SUPPORT (TOP) / NEW GROUNDED RECOVERY (BOTTOM)',font=FONT,fill='white')
    d.text((12,37),'Same camera, lighting, mesh and scale. Different tasks; source run is not retimed or edited.',font=SMALL,fill=(178,219,218))
    for row,(folder,fs) in enumerate([(OUT.parent/'run_expressive_test/frames/test/three_quarter',[1,2,3,4,5]),(OUT/'frames/three_quarter',[13,16,18,27,42])]):
        for col,f in enumerate(fs):
            compare.paste(Image.open(folder/f'{f:03d}.png').convert('RGB').resize((320,320)),(col*320,90+row*400))
            d.text((col*320+8,70+row*400),f'F{f:02d}',font=SMALL,fill='white')
    compare.save(OUT/'baseline_support_comparison.jpg',quality=95)
    checks={}
    for name,count in [('lowerbody_recovery_1x',48),('front_1x',48),('three_quarter_1x',48),('side_1x',48),('lowerbody_recovery_review',189)]:
        p=OUT/f'{name}.mp4';cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);width=int(cap.get(cv2.CAP_PROP_FRAME_WIDTH));height=int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT));n=0;errors=[];decoded=[]
        while True:
            ok,im=cap.read()
            if not ok:break
            if name=='lowerbody_recovery_1x':
                import numpy as np
                src=np.array(composite[n]);errors.append(float(np.abs(cv2.cvtColor(im,cv2.COLOR_BGR2RGB).astype('float32')-src).mean()))
                if n in [0,6,9,12,17,21,32,41]:decoded.append((n+1,Image.fromarray(cv2.cvtColor(im,cv2.COLOR_BGR2RGB))))
            n+=1
        cap.release();assert n==count and fps==30,(name,n,fps)
        if errors:assert max(errors)<3,(name,max(errors))
        checks[name]={'frames':n,'fps':fps,'size':[width,height],'duration_s':n/fps,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'max_mean_rgb_error':max(errors) if errors else None}
        if decoded:
            # Full-width reduced rows retain all views for decoded-media QA.
            ds=Image.new('RGB',(960,360*len(decoded)))
            for j,(f,im) in enumerate(decoded):ds.paste(im.resize((960,360)),(0,j*360))
            ds.save(OUT/'decoded_review_samples.jpg',quality=94)
    (OUT/'media_verification.json').write_text(json.dumps(checks,indent=2))
    print('PACKAGED AND DECODED: all three views, 48 actual frames each; 189-frame labeled replay review.')

if __name__=='__main__':
    import sys
    run(sys.argv[1])
