"""Package rendered pixels at authored speed; decode every output for validation."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,sys,cv2,numpy as np,hashlib
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/jump_landing_test'
VIEWS=['front','three_quarter','side'];FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24);SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
KEYS=[1,6,9,11,16,20,26,34,40,44]

def frame(mode,f):
    im=Image.new('RGB',(1920,720),(23,29,35));d=ImageDraw.Draw(im)
    title='PENDING LANDING / SOFT ABSORPTION + RIGID SUPPORT / 1x SPEED' if mode=='landing' else 'APPROVED TAKEOFF + AIRPOSE -> PENDING LANDING / SEPARATE ACTIONS / 1x SPEED'
    d.text((16,5),title,font=FONT,fill='white')
    for i,v in enumerate(VIEWS):
        im.paste(Image.open(OUT/'frames'/mode/v/f'{f:03d}.png').convert('RGB'),(i*640,42));d.text((i*640+12,47),v.replace('_',' ').upper(),font=SMALL,fill=(228,235,240))
    name='Jump_Landing_Test' if mode=='landing' or f>45 else 'Jump_Takeoff_Test' if f<=24 else 'Jump_AirPose_Test'
    local=f if mode=='landing' or f<=24 else f-23 if f<=45 else f-44
    phase='APPROACH' if local<9 else 'LEAD CONTACT' if local<11 else 'TWO SUPPORTS / ABSORPTION' if local<17 else 'OVERLAP' if local<23 else 'REBOUND' if local<30 else 'RECOVERY'
    note=phase if name=='Jump_Landing_Test' else 'APPROVED REFERENCE'
    d.text((16,689),f'{name} F{local:02d} | 30 FPS | {note} | Preview descent separate from pose Action',font=SMALL,fill=(178,219,218))
    return im

def encode(images,name):
    folder=TMP/'encode'/name;folder.mkdir(parents=True,exist_ok=True)
    for count,im in enumerate(images,1):im.save(folder/f'{count:04d}.png')
    with (TMP/(name+'.log')).open('w') as log:subprocess.run([sys.argv[1],'-b','--factory-startup','--python-exit-code','1','--python',str(OUT.parent/'lowerbody_recovery_test/encode_review.py'),'--',str(folder),str(OUT/(name+'.mp4')),str(count)],check=True,stdout=log,stderr=subprocess.STDOUT)
    return count

def run():
    assert all((OUT/'frames'/mode/v/f'{f:03d}.png').is_file() for mode,count in [('landing',44),('sequence',88)] for v in VIEWS for f in range(1,count+1))
    land=[frame('landing',f) for f in range(1,45)];seq=[frame('sequence',f) for f in range(1,89)]
    replay=[]
    for repeat in range(2):
        replay+=seq;hold=seq[-1].copy();d=ImageDraw.Draw(hold);d.rectangle((0,682,1920,720),fill=(23,29,35));d.text((16,689),'END OF ISOLATED STUDY / labeled hold + replay cut / no gameplay integration',font=SMALL,fill='white');replay += [hold]*16
    originals={'jump_landing_1x':land,'takeoff_airpose_landing_1x':seq,'takeoff_airpose_landing_review':replay}
    for v in VIEWS:originals[v+'_1x']=[Image.open(OUT/'frames/landing'/v/f'{f:03d}.png').convert('RGB') for f in range(1,45)]
    counts={name:encode(images,name) for name,images in originals.items()}
    sheet=Image.new('RGB',(1800,600),(23,29,35));d=ImageDraw.Draw(sheet);d.text((12,4),'LANDING / CONTACT -> SOFT DIP -> ONE RESTRAINED RECOVERY',font=FONT,fill='white')
    for col,f in enumerate(KEYS):
        d.text((col*180+5,39),f'LAND F{f:02d}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):sheet.paste(Image.open(OUT/'frames/landing'/v/f'{f:03d}.png').convert('RGB').resize((180,180)),(col*180,60+row*180))
    sheet.save(OUT/'landing_pose_sheet.jpg',quality=95)
    for v in VIEWS:
        sheet=Image.new('RGB',(1600,1320),(23,29,35));d=ImageDraw.Draw(sheet)
        for j in range(44):
            x=j%8*200;y=j//8*220;d.text((x+5,y),f'{v} F{j+1:02d}',font=SMALL,fill='white');sheet.paste(Image.open(OUT/'frames/landing'/v/f'{j+1:03d}.png').convert('RGB').resize((200,200)),(x,y+20))
        sheet.save(OUT/f'{v}_all_frames.jpg',quality=95)
    # Compare the approved absorption language without altering either source's timing.
    compare=Image.new('RGB',(1600,855),(23,29,35));d=ImageDraw.Draw(compare);d.text((12,4),'APPROVED RECOVERY vs PENDING LANDING / PHASE SAMPLES, NOT RETIMED MOTION',font=FONT,fill='white')
    for col,(label,lb,landing) in enumerate([('CONTACT',13,9),('SOFT DIP',18,16),('REBOUND',33,26),('SETTLE',42,40)]):
        d.text((col*400+8,40),f'{label} | Recovery F{lb} / Landing F{landing}',font=SMALL,fill='white')
        compare.paste(Image.open(OUT.parent/'lowerbody_recovery_test/frames/three_quarter'/f'{lb:03d}.png').convert('RGB').resize((400,400)),(col*400,65))
        compare.paste(Image.open(OUT/'frames/landing/three_quarter'/f'{landing:03d}.png').convert('RGB').resize((400,400)),(col*400,455))
    compare.save(OUT/'recovery_comparison.jpg',quality=95)
    checks={};samples=[]
    for name,count in counts.items():
        path=OUT/(name+'.mp4');cap=cv2.VideoCapture(str(path));fps=cap.get(cv2.CAP_PROP_FPS);size=[int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))];n=0;errors=[]
        while True:
            ok,im=cap.read()
            if not ok:break
            rgb=cv2.cvtColor(im,cv2.COLOR_BGR2RGB);errors.append(float(np.abs(rgb.astype('float32')-np.array(originals[name][n])).mean()))
            if name=='takeoff_airpose_landing_1x' and n+1 in [24,25,44,45,46,50,53,55,60,64,70,84,88]:samples.append(Image.fromarray(rgb).resize((960,360)))
            n+=1
        cap.release();assert n==count and fps==30,(name,n,fps)
        assert size==list(originals[name][0].size) and max(errors)<3
        checks[name]={'frames':n,'fps':fps,'size':size,'duration_s':n/fps,'max_mean_rgb_decode_error':max(errors),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    source=OUT.parent/'jump_airpose_test/frames/sequence'
    checks['approved_phase_review_pixels_preserved']=all((OUT/'frames/sequence'/v/f'{f:03d}.png').read_bytes()==(source/v/f'{f:03d}.png').read_bytes() for v in VIEWS for f in range(1,46));assert checks['approved_phase_review_pixels_preserved']
    im=Image.new('RGB',(960,360*len(samples)))
    for j,p in enumerate(samples):im.paste(p,(0,j*360))
    im.save(OUT/'decoded_transition_samples.jpg',quality=94)
    (OUT/'media_verification.json').write_text(json.dumps(checks,indent=2));print('ENCODED + DECODED: landing and three independent Action review',flush=True)
if __name__=='__main__':run()
