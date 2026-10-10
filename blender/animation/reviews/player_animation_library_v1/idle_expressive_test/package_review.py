"""Original-speed Idle review: two complete 144-frame loops, no closing-frame hold."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,sys,cv2,numpy as np,hashlib
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/idle_expressive_test'
VIEWS=['front','three_quarter','side'];P=144;REPEATS=2;COUNT=P*REPEATS
FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24)
SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)

def raw(mode,view,f):
    return Image.open(OUT/'frames'/mode/view/f'{f:03d}.png').convert('RGB')

def composed(j,comparison=False,view=None):
    f=1+j%P;views=[view] if view else VIEWS
    width=1280 if view else 1920;height=720 if view or not comparison else 1440
    im=Image.new('RGB',(width,height),(23,29,35));d=ImageDraw.Draw(im)
    if view:
        d.text((16,5),'OLD IDLE vs EXPRESSIVE IDLE / MATCHED STAGE / ORIGINAL SPEED',font=FONT,fill='white')
        for col,mode in enumerate(['old','new']):
            im.paste(raw(mode,view,1+j%120 if mode=='old' else f),(col*640,42))
            d.text((col*640+12,47),'OLD: preserved native motion' if mode=='old' else 'NEW: Pending review',font=SMALL,fill='white')
            d.text((col*640+12,689),'Native 24 FPS / 4 s loop' if mode=='old' else f'F{f:02d} / 30 FPS / 4.8 s loop',font=SMALL,fill=(178,219,218))
    else:
        for row,mode in enumerate(['old','new'] if comparison else ['new']):
            y=row*720
            title='OLD IDLE: ACTUAL SAVED 4-SECOND LOOP / NATIVE 24 FPS' if mode=='old' else 'IDLE_EXPRESSIVE_TEST / PENDING / ORIGINAL SPEED / 30 FPS'
            d.text((16,y+5),title,font=FONT,fill='white')
            for col,v in enumerate(views):
                im.paste(raw(mode,v,1+j%120 if mode=='old' else f),(col*640,y+42));d.text((col*640+12,y+47),v.replace('_',' ').upper(),font=SMALL,fill='white')
            d.text((16,y+689),'Same camera, lighting, appearance and rig; no animation invented for the old baseline.' if mode=='old' else f'Loop {j//P+1}/{REPEATS} | F{f:02d} | Fixed full soles / quiet weight transfer / no scaling or world travel',font=SMALL,fill=(178,219,218))
    return im

def run():
    baseline=json.loads((OUT/'old_idle_baseline.json').read_text())
    assert len(baseline['samples'])==120 and baseline['source_fps']==24 and baseline['comparison_fps']==30
    checks={};samples=[]
    generators={'idle_all_views_1x':lambda j:composed(j),'comparison_all_views_1x':lambda j:composed(j,True),'comparison_three_quarter_1x':lambda j:composed(j,True,'three_quarter')}
    generators.update({v+'_1x':lambda j,v=v:raw('new',v,1+j%P) for v in VIEWS})
    for name,make in generators.items():
        folder=TMP/'encode'/name;folder.mkdir(parents=True,exist_ok=True)
        for j in range(COUNT):make(j).save(folder/f'{j+1:04d}.png')
        with (TMP/(name+'.log')).open('w') as log:
            subprocess.run([sys.argv[1],'-b','--factory-startup','--python-exit-code','1','--python',str(OUT.parent/'lowerbody_recovery_test/encode_review.py'),'--',str(folder),str(OUT/(name+'.mp4')),str(COUNT)],check=True,stdout=log,stderr=subprocess.STDOUT)
        cap=cv2.VideoCapture(str(OUT/(name+'.mp4')));fps=cap.get(cv2.CAP_PROP_FPS);errors=[];n=0
        while True:
            ok,frame=cap.read()
            if not ok:break
            rgb=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB);expected=np.array(make(n));assert rgb.shape==expected.shape
            errors.append(float(np.abs(rgb.astype('float32')-expected).mean()))
            if name=='comparison_three_quarter_1x' and n+1 in [1,22,37,52,62,90,124,144,145]:samples.append(Image.fromarray(rgb).resize((800,450)))
            n+=1
        cap.release();assert n==COUNT and fps==30 and max(errors)<3,(name,n,fps,max(errors))
        checks[name]={'frames':n,'fps':fps,'size':list(make(0).size),'duration_s':n/fps,'complete_loops':REPEATS,'closing_key_excluded':True,'max_mean_rgb_decode_error':max(errors),'sha256':hashlib.sha256((OUT/(name+'.mp4')).read_bytes()).hexdigest()}
        print('ENCODED AND DECODED',name,flush=True)
    sheet=Image.new('RGB',(1680,800),(23,29,35));d=ImageDraw.Draw(sheet)
    d.text((12,6),'PENDING IDLE / CURIOUS GLANCE + QUIET WEIGHT / STAGGERED SHOULDERS / SAME STAGE AS OLD IDLE',font=FONT,fill='white')
    for col,f in enumerate([1,22,37,52,62,109,144]):
        d.text((col*240+8,40),f'F{f:02d}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):sheet.paste(raw('new',v,f).resize((240,240)),(col*240,65+row*245))
    sheet.save(OUT/'idle_pose_sheet.jpg',quality=95)
    sheet=Image.new('RGB',(1600,2250),(23,29,35))
    for j,im in enumerate(samples):sheet.paste(im,(j%2*800,j//2*450))
    sheet.save(OUT/'decoded_comparison_samples.jpg',quality=95)
    checks['comparison_baseline']='Actual R12_Hold_Unarmed_Upper: 96 frames at native 24 FPS (4 s), sampled at 30 FPS for comparison without retiming; new loop 144 frames at 30 FPS (4.8 s).'
    (OUT/'media_verification.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
if __name__=='__main__':run()
