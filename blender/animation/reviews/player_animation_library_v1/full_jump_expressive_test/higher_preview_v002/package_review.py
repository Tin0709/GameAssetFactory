"""Same-speed higher preview plus direct comparison, with frame-level media QA."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,sys,cv2,numpy as np,hashlib
OUT=Path(__file__).resolve().parent;BASE=OUT.parent;ROOT=BASE.parents[4];TMP=ROOT/'.validation/full_jump_higher_preview_v002'
VIEWS=['front','three_quarter','side'];FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24);SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
KEYS=[1,14,19,24,29,33,38,43,46,51,55,67,89,93]
def raw(v,f,base=False):return Image.open((BASE if base else OUT)/'frames'/v/f'{f:03d}.png').convert('RGB')
def combined(f):
    im=Image.new('RGB',(1920,720),(23,29,35));d=ImageDraw.Draw(im)
    d.text((16,5),'HIGHER BLENDER REVIEW PREVIEW V002 / 0.72 m / PENDING / ORIGINAL SPEED',font=FONT,fill='white')
    for i,v in enumerate(VIEWS):im.paste(raw(v,f),(i*640,42));d.text((i*640+12,47),v.replace('_',' ').upper(),font=SMALL,fill='white')
    d.text((16,689),f'F{f:02d}/93 | 30 FPS | Preview height +14 cm only | Full_Jump_Expressive_Test, poses and landing timing unchanged',font=SMALL,fill=(178,219,218));return im
def comparison(f):
    im=Image.new('RGB',(1280,720),(23,29,35));d=ImageDraw.Draw(im)
    d.text((16,5),'SAME ACTION / SAME CAMERA / SAME TIMING / PREVIEW HEIGHT ONLY',font=FONT,fill='white')
    for col,(base,title) in enumerate([(True,'ORIGINAL: 0.58 m'),(False,'HIGHER REVIEW: 0.72 m')]):
        im.paste(raw('three_quarter',f,base),(col*640,42));d.text((col*640+12,47),title,font=FONT,fill='white')
    d.text((16,689),f'F{f:02d}/93 | 30 FPS / 1x speed | No motion variant, retiming, camera zoom or gameplay change',font=SMALL,fill=(178,219,218));return im
def sheets():
    im=Image.new('RGB',(2240,600),(23,29,35));d=ImageDraw.Draw(im)
    d.text((12,5),'HIGHER REVIEW V002 / 0.58 -> 0.72 m / SAME POSES + TIMING',font=FONT,fill='white')
    for col,f in enumerate(KEYS):
        d.text((col*160+5,40),f'F{f:02d}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):im.paste(raw(v,f).resize((160,160)),(col*160,65+row*175))
    im.save(OUT/'higher_preview_pose_sheet.jpg',quality=95)
    im=Image.new('RGB',(1800,560),(23,29,35));d=ImageDraw.Draw(im)
    for col,(v,f) in enumerate([(v,f) for v in VIEWS for f in [24,33,38]]):
        for row,(base,label) in enumerate([(True,'ORIGINAL 0.58 m'),(False,'HIGHER 0.72 m')]):
            x=col*200;y=row*280;im.paste(raw(v,f,base).resize((200,200)),(x,y+35));d.text((x+4,y+5),f'{v.replace("three_quarter","3/4")} F{f}',font=SMALL,fill='white');d.text((x+4,y+242),label,font=SMALL,fill='white')
    im.save(OUT/'height_comparison.jpg',quality=95)
def encode(images,name):
    folder=TMP/'encode'/name;folder.mkdir(parents=True,exist_ok=True)
    for n,im in enumerate(images,1):im.save(folder/f'{n:04d}.png')
    with (TMP/(name+'.log')).open('w') as log:subprocess.run([sys.argv[1],'-b','--factory-startup','--python-exit-code','1','--python',str(BASE.parent/'lowerbody_recovery_test/encode_review.py'),'--',str(folder),str(OUT/(name+'.mp4')),str(n)],check=True,stdout=log,stderr=subprocess.STDOUT)
def run():
    sheets()
    if 'keys' in sys.argv:return
    checks={};decoded=[]
    originals={'higher_preview_all_views_1x':[combined(f) for f in range(1,94)],'height_comparison_three_quarter_1x':[comparison(f) for f in range(1,94)]}
    for v in VIEWS:originals[v+'_1x']=[raw(v,f) for f in range(1,94)]
    for name,images in originals.items():
        encode(images,name);path=OUT/(name+'.mp4');cap=cv2.VideoCapture(str(path));fps=cap.get(cv2.CAP_PROP_FPS);size=[int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))];n=0;errors=[]
        while True:
            ok,frame=cap.read()
            if not ok:break
            rgb=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB);errors.append(float(np.abs(rgb.astype('float32')-np.array(images[n])).mean()))
            if name=='height_comparison_three_quarter_1x' and n+1 in KEYS:decoded.append(Image.fromarray(rgb).resize((800,450)))
            n+=1
        cap.release();assert n==93 and fps==30 and size==list(images[0].size),(name,n,fps,size);assert max(errors)<3
        checks[name]={'frames':n,'fps':fps,'size':size,'duration_s':n/fps,'max_mean_rgb_decode_error':max(errors),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    # With unchanged stage and poses, every grounded frame must match the old pixels.
    errors=[]
    for v in VIEWS:
        for f in list(range(1,20))+list(range(46,94)):
            aa=np.array(raw(v,f));bb=np.array(raw(v,f,True));errors.append(int(np.abs(aa.astype('int16')-bb.astype('int16')).max()))
    assert max(errors)==0,'Grounded phase render changed'
    checks['all_201_grounded_frames_pixel_exact']=True
    im=Image.new('RGB',(1600,3150),(23,29,35))
    for j,p in enumerate(decoded):im.paste(p,(j%2*800,j//2*450))
    im.save(OUT/'decoded_comparison_samples.jpg',quality=95)
    checks['passed']=True;(OUT/'media_verification.json').write_text(json.dumps(checks,indent=2),encoding='utf8');print('FIVE VIDEOS DECODED AT 30 FPS; ALL 201 GROUNDED RENDERS PIXEL EXACT',flush=True)
if __name__=='__main__':run()
