"""Two complete 8s v2 loops; current v1 repeats its native 4.8s period unchanged."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,sys,cv2,numpy as np,hashlib
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/idle_expressive_test_v2';OLD=OUT.with_name('idle_expressive_test')
VIEWS=['front','three_quarter','side'];P=240;REPEATS=2;COUNT=P*REPEATS
FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',23);SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
def raw(mode,view,f):
    path=OLD/'frames/new'/view/f'{f:03d}.png' if mode=='v1' else OUT/'frames'/view/f'{f:03d}.png'
    with Image.open(path) as im:return im.convert('RGB')
def composed(j,comparison=False,view=None):
    f=1+j%P;width=1280 if view else 1920;height=1440 if comparison and not view else 720
    im=Image.new('RGB',(width,height),(23,29,35));d=ImageDraw.Draw(im)
    if view:
        d.text((16,5),'CURRENT IDLE vs V2 / MATCHED STAGE / BOTH ORIGINAL SPEED',font=FONT,fill='white')
        for col,mode in enumerate(['v1','v2']):
            frame=1+j%144 if mode=='v1' else f
            im.paste(raw(mode,view,frame),(col*640,42))
            d.text((col*640+12,47),'V1: preserved single observation' if mode=='v1' else 'V2: two-sided curiosity / Pending',font=SMALL,fill='white')
            d.text((col*640+12,689),f'F{frame:03d} / 30 FPS / '+('4.8 s native loop' if mode=='v1' else '8 s native loop'),font=SMALL,fill=(178,219,218))
    else:
        for row,mode in enumerate(['v1','v2'] if comparison else ['v2']):
            y=row*720;frame=1+j%144 if mode=='v1' else f
            d.text((16,y+5),'CURRENT IDLE V1 / PRESERVED / ORIGINAL SPEED / 4.8 s' if mode=='v1' else 'IDLE_EXPRESSIVE_TEST_V2 / PENDING / ORIGINAL SPEED / 8 s',font=FONT,fill='white')
            for col,v in enumerate(VIEWS):
                im.paste(raw(mode,v,frame),(col*640,y+42));d.text((col*640+12,y+47),v.replace('_',' ').upper(),font=SMALL,fill='white')
            d.text((16,y+689),f'F{frame:03d} | '+('Unchanged Action, source and render frames; no retiming or frozen padding.' if mode=='v1' else 'Wider planted stance / two distinct interests / quiet rigid breath / closing key excluded'),font=SMALL,fill=(178,219,218))
    return im
def run():
    validation=json.loads((OUT/'validation.json').read_text());assert validation['passed'] and validation['v1_source_vertex_error_m']<2e-6
    assert hashlib.sha256((OUT/'idle_expressive_v2_review.blend').read_bytes()).hexdigest()==validation['sampled_source_sha256']
    for view in VIEWS:assert all((OUT/'frames'/view/f'{f:03d}.png').exists() for f in range(1,P+1))
    checks={};samples=[]
    generators={'idle_v2_all_views_1x':lambda j:composed(j),'comparison_all_views_1x':lambda j:composed(j,True),'comparison_three_quarter_1x':lambda j:composed(j,True,'three_quarter')}
    generators.update({v+'_1x':lambda j,v=v:raw('v2',v,1+j%P) for v in VIEWS})
    for name,make in generators.items():
        folder=TMP/'encode'/name;folder.mkdir(parents=True,exist_ok=True)
        if '--verify-existing' not in sys.argv:
            for j in range(COUNT):make(j).save(folder/f'{j+1:04d}.png')
            with (TMP/(name+'.log')).open('w') as log:
                subprocess.run([sys.argv[1],'-b','--factory-startup','--python-exit-code','1','--python',str(OUT.parent/'lowerbody_recovery_test/encode_review.py'),'--',str(folder),str(OUT/(name+'.mp4')),str(COUNT)],check=True,stdout=log,stderr=subprocess.STDOUT)
        cap=cv2.VideoCapture(str(OUT/(name+'.mp4')));fps=cap.get(cv2.CAP_PROP_FPS);errors=[];n=0
        while True:
            ok,frame=cap.read()
            if not ok:break
            rgb=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB);expected=np.array(make(n));assert rgb.shape==expected.shape
            errors.append(float(np.abs(rgb.astype('float32')-expected).mean()))
            if name=='comparison_three_quarter_1x' and n+1 in [1,49,65,115,146,158,218,240,241]:samples.append(Image.fromarray(rgb).resize((800,450)))
            n+=1
        cap.release();assert n==COUNT and fps==30 and max(errors)<3,(name,n,fps,max(errors))
        checks[name]={'frames':n,'fps':fps,'size':list(make(0).size),'duration_s':n/fps,'v2_complete_loops':REPEATS,'v1_native_period_frames':144 if 'comparison' in name else None,'closing_key_excluded':True,'max_mean_rgb_decode_error':max(errors),'sha256':hashlib.sha256((OUT/(name+'.mp4')).read_bytes()).hexdigest()}
        print('ENCODED AND DECODED',name,flush=True)
    sheet=Image.new('RGB',(1920,800),(23,29,35));d=ImageDraw.Draw(sheet)
    for col,f in enumerate([1,49,65,115,146,158,218,240]):
        d.text((col*240+8,5),f'V2 F{f}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):sheet.paste(raw('v2',v,f).resize((240,240)),(col*240,35+row*250))
    sheet.save(OUT/'idle_v2_pose_sheet.jpg',quality=95)
    sheet=Image.new('RGB',(1600,2250),(23,29,35))
    for j,im in enumerate(samples):sheet.paste(im,(j%2*800,j//2*450))
    sheet.save(OUT/'decoded_comparison_samples.jpg',quality=95)
    checks['comparison']='Preserved Idle_Expressive_Test: 144 frames/30FPS/4.8s. V2:240frames/30FPS/8s. Both original speed; matching stage. Two complete v2 loops, no closing-key hold.'
    checks['source_sha256']=validation['sampled_source_sha256'];checks['action_sha256']=validation['sampled_action_sha256']
    (OUT/'media_verification.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
if __name__=='__main__':run()
