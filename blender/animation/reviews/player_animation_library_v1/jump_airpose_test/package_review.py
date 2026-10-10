"""Encode actual rendered frames, then decode and verify the review videos."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,sys,cv2,numpy as np,hashlib
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/jump_airpose_test'
VIEWS=['front','three_quarter','side'];FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24);SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
KEYS=[1,4,7,9,13,16,19,22]
def frame(mode,f):
    im=Image.new('RGB',(1920,720),(23,29,35));d=ImageDraw.Draw(im)
    title='JUMP AIRPOSE / IN-PLACE ARTICULATION / 1x SPEED' if mode=='air' else 'APPROVED TAKEOFF -> PENDING AIRPOSE / SEPARATE ACTIONS / 1x SPEED'
    d.text((16,5),title,font=FONT,fill='white')
    for i,v in enumerate(VIEWS):
        im.paste(Image.open(OUT/'frames'/mode/v/f'{f:03d}.png').convert('RGB'),(i*640,42));d.text((i*640+12,47),v.replace('_',' ').upper(),font=SMALL,fill=(228,235,240))
    name='Jump_AirPose_Test' if mode=='air' or f>24 else 'Jump_Takeoff_Test'
    local=f if mode=='air' or f<=24 else f-23
    note='Fixed preview stage / no trajectory in AirPose Action' if mode=='air' else 'External preview height only / no apex, descent or landing'
    d.text((16,689),f'{name} F{local:02d} | 30 FPS | {note}',font=SMALL,fill=(178,219,218))
    return im
def encode(images,name):
    folder=TMP/'encode'/name;folder.mkdir(parents=True,exist_ok=True)
    for count,im in enumerate(images,1):im.save(folder/f'{count:04d}.png')
    with (TMP/(name+'.log')).open('w') as log:subprocess.run([sys.argv[1],'-b','--factory-startup','--python-exit-code','1','--python',str(OUT.parent/'lowerbody_recovery_test/encode_review.py'),'--',str(folder),str(OUT/(name+'.mp4')),str(count)],check=True,stdout=log,stderr=subprocess.STDOUT)
    return count
def run():
    assert all((OUT/'frames'/mode/v/f'{f:03d}.png').is_file() for mode,count in [('air',22),('sequence',45)] for v in VIEWS for f in range(1,count+1))
    air=[frame('air',f) for f in range(1,23)];seq=[frame('sequence',f) for f in range(1,46)]
    counts={'jump_airpose_1x':encode(air,'jump_airpose_1x'),'takeoff_to_airpose_1x':encode(seq,'takeoff_to_airpose_1x')}
    for v in VIEWS:counts[v+'_1x']=encode([Image.open(OUT/'frames/air'/v/f'{f:03d}.png').convert('RGB') for f in range(1,23)],v+'_1x')
    replay=[]
    for repeat in range(3):
        replay+=seq;hold=seq[-1].copy();d=ImageDraw.Draw(hold);d.rectangle((0,682,1920,720),fill=(23,29,35));d.text((16,689),'END OF AIRPOSE STUDY / labeled hold + replay cut / no landing authored',font=SMALL,fill='white');replay += [hold]*12
    counts['takeoff_to_airpose_review']=encode(replay,'takeoff_to_airpose_review')
    sheet=Image.new('RGB',(1600,710),(23,29,35));d=ImageDraw.Draw(sheet);d.text((12,4),'AIRPOSE / CONTINUATION - OPEN SILHOUETTE - CONTROLLED OVERLAP',font=FONT,fill='white')
    for col,f in enumerate(KEYS):
        d.text((col*200+5,39),f'AIR F{f:02d}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):sheet.paste(Image.open(OUT/'frames/air'/v/f'{f:03d}.png').convert('RGB').resize((200,200)),(col*200,65+row*210))
    sheet.save(OUT/'air_pose_sheet.jpg',quality=95)
    for v in VIEWS:
        sheet=Image.new('RGB',(1600,660),(23,29,35));d=ImageDraw.Draw(sheet)
        for j in range(22):
            x=j%8*200;y=j//8*220;d.text((x+5,y),f'{v} F{j+1:02d}',font=SMALL,fill='white');sheet.paste(Image.open(OUT/'frames/air'/v/f'{j+1:03d}.png').convert('RGB').resize((200,200)),(x,y+20))
        sheet.save(OUT/f'{v}_all_frames.jpg',quality=95)
    compare=Image.new('RGB',(1280,720),(23,29,35));d=ImageDraw.Draw(compare);d.text((12,4),'APPROVED TAKEOFF F24 / AIRPOSE F1 + SEPARATE PREVIEW OFFSET',font=FONT,fill='white')
    for i,p in enumerate([OUT/'frames/sequence/three_quarter/024.png',OUT/'boundary_air_first.png']):compare.paste(Image.open(p).convert('RGB'),(i*640,42))
    d.text((12,689),'Same camera / lighting / pose boundary / shared endpoint is not duplicated in the sequence',font=SMALL,fill=(178,219,218));compare.save(OUT/'boundary_pose_comparison.jpg',quality=95)
    checks={};samples=[]
    for name,count in counts.items():
        path=OUT/(name+'.mp4');cap=cv2.VideoCapture(str(path));fps=cap.get(cv2.CAP_PROP_FPS);size=[int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))];n=0;errors=[]
        original=air if name=='jump_airpose_1x' else seq if name=='takeoff_to_airpose_1x' else None
        while True:
            ok,im=cap.read()
            if not ok:break
            if original:
                rgb=cv2.cvtColor(im,cv2.COLOR_BGR2RGB);errors.append(float(np.abs(rgb.astype('float32')-np.array(original[n])).mean()))
                if name=='takeoff_to_airpose_1x' and n+1 in [19,23,24,25,27,32,39,45]:samples.append(Image.fromarray(rgb).resize((960,360)))
            n+=1
        cap.release();assert n==count and fps==30,(name,n,fps)
        if errors:assert max(errors)<3
        checks[name]={'frames':n,'fps':fps,'size':size,'duration_s':n/fps,'max_mean_rgb_decode_error':max(errors) if errors else None,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    # Approved takeoff footage is reused byte-for-byte, without reauthoring/retiming.
    source=OUT.parent/'jump_takeoff_test/frames'
    checks['approved_takeoff_pixels_preserved']=all((OUT/'frames/sequence'/v/f'{f:03d}.png').read_bytes()==(source/v/f'{f:03d}.png').read_bytes() for v in VIEWS for f in range(1,25))
    assert checks['approved_takeoff_pixels_preserved']
    im=Image.new('RGB',(960,360*len(samples)))
    for j,p in enumerate(samples):im.paste(p,(0,j*360))
    im.save(OUT/'decoded_transition_samples.jpg',quality=94)
    (OUT/'media_verification.json').write_text(json.dumps(checks,indent=2));print('ENCODED + DECODED: airpose and separate-action transition',flush=True)
if __name__=='__main__':run()
