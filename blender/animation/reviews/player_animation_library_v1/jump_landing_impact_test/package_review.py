"""Original-speed, contact-aligned comparison of two separate landing Actions."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,sys,cv2,numpy as np,hashlib,shutil,runpy
OUT=Path(__file__).resolve().parent;BASE=OUT.parent/'jump_landing_test';TMP=OUT.parents[4]/'.validation/jump_landing_impact_test'
VIEWS=['front','three_quarter','side'];FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24);SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
KEYS=[1,6,9,10,14,18,26,30,42,52,56]
BP=runpy.run_path(str(BASE/'package_review.py'))

def raw(mode,v,f):return Image.open(OUT/'frames'/mode/v/f'{f:03d}.png').convert('RGB')
def single(f):
    im=Image.new('RGB',(1920,720),(23,29,35));d=ImageDraw.Draw(im);d.text((16,5),'PENDING IMPACT LANDING / RIGID SUPPORT + HEAVIER SOFT ABSORPTION / 1x SPEED',font=FONT,fill='white')
    for i,v in enumerate(VIEWS):im.paste(raw('impact',v,f),(640*i,42));d.text((640*i+12,47),v.replace('_',' ').upper(),font=SMALL,fill='white')
    d.text((16,689),f'Jump_Landing_Impact_Test F{f:02d} | 30 FPS | Local ground absorption only / no world jump trajectory',font=SMALL,fill=(178,219,218));return im
def comparison(f,view=None):
    if view:
        im=Image.new('RGB',(1280,720),(23,29,35));d=ImageDraw.Draw(im)
        d.text((16,5),f'ORIGINAL vs IMPACT / {view.replace("_"," ").upper()} / BOTH 1x SPEED',font=FONT,fill='white')
        for i,(mode,name) in enumerate([('baseline','Jump_Landing_Test'),('impact','Jump_Landing_Impact_Test')]):
            local=min(f,44) if mode=='baseline' else f;im.paste(raw(mode,view,local),(i*640,42));d.text((i*640+12,47),name,font=SMALL,fill='white')
            d.text((i*640+12,689),f'F{local:02d}'+(' / ORIGINAL ENDED: LABELED HOLD' if mode=='baseline' and f>44 else ' / ORIGINAL TIMING'),font=SMALL,fill=(178,219,218))
    else:
        im=Image.new('RGB',(1920,1440),(23,29,35));d=ImageDraw.Draw(im)
        for row,(mode,name) in enumerate([('baseline','ORIGINAL: Jump_Landing_Test'),('impact','VARIANT: Jump_Landing_Impact_Test')]):
            local=min(f,44) if mode=='baseline' else f;y=row*720
            d.text((16,y+5),name+' / 1x SPEED / PENDING',font=FONT,fill='white')
            for col,v in enumerate(VIEWS):im.paste(raw(mode,v,local),(col*640,y+42));d.text((col*640+12,y+47),v.replace('_',' ').upper(),font=SMALL,fill='white')
            d.text((16,y+689),f'F{local:02d} | 30 FPS'+(' | ORIGINAL ENDED AT F44: LABELED COMPARISON HOLD' if mode=='baseline' and f>44 else ' | AUTHORED TIMING, NO RETIMING'),font=SMALL,fill=(178,219,218))
    return im
def encode(images,name):
    folder=TMP/'encode'/name;folder.mkdir(parents=True,exist_ok=True)
    for count,im in enumerate(images,1):im.save(folder/f'{count:04d}.png')
    with (TMP/(name+'.log')).open('w') as log:subprocess.run([sys.argv[1],'-b','--factory-startup','--python-exit-code','1','--python',str(OUT.parent/'lowerbody_recovery_test/encode_review.py'),'--',str(folder),str(OUT/(name+'.mp4')),str(count)],check=True,stdout=log,stderr=subprocess.STDOUT)
    return count
def run():
    assert all((OUT/'frames'/mode/v/f'{f:03d}.png').is_file() for mode,count in [('baseline',44),('impact',56)] for v in VIEWS for f in range(1,count+1))
    recheck=np.array(Image.open(OUT/'baseline_recheck.png').convert('RGB'));original=np.array(raw('baseline','three_quarter',16))
    assert np.array_equal(recheck,original),'Baseline stage/action pixels changed'
    originals={'jump_landing_impact_1x':[single(f) for f in range(1,57)],'comparison_all_views_1x':[comparison(f) for f in range(1,57)]}
    for v in VIEWS:
        originals['impact_'+v+'_1x']=[raw('impact',v,f) for f in range(1,57)]
        originals['comparison_'+v+'_1x']=[comparison(f,v) for f in range(1,57)]
    counts={name:encode(images,name) for name,images in originals.items()}
    originals['baseline_all_views_1x']=[BP['frame']('landing',f) for f in range(1,45)]
    copies={'baseline_all_views_1x':'jump_landing_1x'}
    for v in VIEWS:copies['baseline_'+v+'_1x']=v+'_1x';originals['baseline_'+v+'_1x']=[raw('baseline',v,f) for f in range(1,45)]
    for dest,source in copies.items():shutil.copy2(BASE/(source+'.mp4'),OUT/(dest+'.mp4'));counts[dest]=44
    checks={};samples=[]
    for name,count in counts.items():
        path=OUT/(name+'.mp4');cap=cv2.VideoCapture(str(path));fps=cap.get(cv2.CAP_PROP_FPS);size=[int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))];n=0;errors=[]
        while True:
            ok,frame=cap.read()
            if not ok:break
            rgb=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB);errors.append(float(np.abs(rgb.astype('float32')-np.array(originals[name][n])).mean()))
            if name=='comparison_three_quarter_1x' and n+1 in [1,9,10,14,16,18,26,30,42,44,52,56]:samples.append(Image.fromarray(rgb).resize((800,450)))
            n+=1
        cap.release();assert n==count and fps==30 and size==list(originals[name][0].size),(name,n,fps,size);assert max(errors)<3
        checks[name]={'frames':n,'fps':fps,'size':size,'duration_s':n/fps,'max_mean_rgb_decode_error':max(errors),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    checks['baseline_review_pixels_preserved']=all((OUT/'frames/baseline'/v/f'{f:03d}.png').read_bytes()==(BASE/'frames/landing'/v/f'{f:03d}.png').read_bytes() for v in VIEWS for f in range(1,45));assert checks['baseline_review_pixels_preserved']
    checks['baseline_sample_rerender_pixel_exact']=True
    checks['baseline_videos_byte_exact']=all((OUT/(dest+'.mp4')).read_bytes()==(BASE/(source+'.mp4')).read_bytes() for dest,source in copies.items());assert checks['baseline_videos_byte_exact']
    sheet=Image.new('RGB',(1760,600),(23,29,35));d=ImageDraw.Draw(sheet);d.text((12,5),'IMPACT STUDY / DEEPER ABSORPTION -> CONTROLLED WEIGHTED RECOVERY',font=FONT,fill='white')
    for col,f in enumerate(KEYS):
        d.text((col*160+5,40),f'IMPACT F{f:02d}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):sheet.paste(raw('impact',v,f).resize((160,160)),(col*160,65+row*175))
    sheet.save(OUT/'impact_pose_sheet.jpg',quality=95)
    sheet=Image.new('RGB',(1600,855),(23,29,35));d=ImageDraw.Draw(sheet);d.text((12,5),'ORIGINAL (TOP) vs IMPACT (BOTTOM) / PHASE SAMPLES / NOT RETIMED',font=FONT,fill='white')
    for col,(name,base,imp) in enumerate([('CONTACT',9,9),('DEEPEST DIP',16,14),('REBOUND',26,30),('RECOVERED',44,56)]):
        d.text((col*400+8,40),f'{name} | Original F{base} / Impact F{imp}',font=SMALL,fill='white');sheet.paste(raw('baseline','three_quarter',base).resize((400,400)),(col*400,65));sheet.paste(raw('impact','three_quarter',imp).resize((400,400)),(col*400,455))
    sheet.save(OUT/'phase_comparison.jpg',quality=95)
    sheet=Image.new('RGB',(1600,450*6),(23,29,35))
    for j,im in enumerate(samples):sheet.paste(im,(j%2*800,j//2*450))
    sheet.save(OUT/'decoded_comparison_samples.jpg',quality=95)
    (OUT/'media_verification.json').write_text(json.dumps(checks,indent=2));print('ALL 12 COMPARISON VIDEOS ENCODED/COPIED + DECODED',flush=True)
if __name__=='__main__':run()
