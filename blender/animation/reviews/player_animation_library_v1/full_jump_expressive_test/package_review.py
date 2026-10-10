"""Original-speed full-jump review, decoded-frame verification and pose sheets."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,sys,cv2,numpy as np,hashlib
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/full_jump_expressive_test'
VIEWS=['front','three_quarter','side'];FONT=ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf',24);SMALL=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
KEYS=[1,7,14,19,24,29,33,38,46,51,55,67,89,93]
def raw(v,f):return Image.open(OUT/'frames'/v/f'{f:03d}.png').convert('RGB')
def phase(f):
    for end,label in [(9,'LIGHT LOAD / SOFT COUNTER'),(14,'SOFT PREPARATION'),(19,'UPWARD PUSH'),(24,'LIFTOFF / EARLY AIR'),(38,'EXPRESSIVE AIR'),(45,'DESCENT PREPARATION'),(47,'DECISIVE CONTACT'),(55,'HEAVY SOFT ABSORPTION'),(67,'CONTROLLED REBOUND'),(93,'WEIGHTED RECOVERY')]:
        if f<=end:return label
def combined(f):
    im=Image.new('RGB',(1920,720),(23,29,35));d=ImageDraw.Draw(im)
    d.text((16,5),'FULL JUMP EXPRESSIVE TEST / PENDING REVIEW / ORIGINAL SPEED',font=FONT,fill='white')
    for i,v in enumerate(VIEWS):im.paste(raw(v,f),(640*i,42));d.text((640*i+12,47),v.replace('_',' ').upper(),font=SMALL,fill='white')
    d.text((16,689),f'F{f:02d}/93 | 30 FPS | {phase(f)} | Height travel: Blender preview only; reusable Action stays in place',font=SMALL,fill=(178,219,218));return im
def sheets():
    im=Image.new('RGB',(2240,600),(23,29,35));d=ImageDraw.Draw(im)
    d.text((12,5),'FULL JUMP / ONE CONTINUOUS MOTION / PREVIEW TRAVEL SEPARATE FROM POSE',font=FONT,fill='white')
    for col,f in enumerate(KEYS):
        d.text((col*160+5,40),f'F{f:02d}',font=SMALL,fill='white')
        for row,v in enumerate(VIEWS):im.paste(raw(v,f).resize((160,160)),(col*160,65+row*175))
    im.save(OUT/'full_jump_pose_sheet.jpg',quality=95)
    im=Image.new('RGB',(1600,1200),(23,29,35));d=ImageDraw.Draw(im)
    for j,f in enumerate([14,19,24,29,33,38,46,51,55,67,89,93]):
        x=j%4*400;y=j//4*400;im.paste(raw('three_quarter',f).resize((400,400)),(x,y));d.text((x+10,y+10),f'F{f:02d} / '+phase(f),font=SMALL,fill='white')
    im.save(OUT/'three_quarter_pose_sheet.jpg',quality=95)
def encode(images,name):
    folder=TMP/'encode'/name;folder.mkdir(parents=True,exist_ok=True)
    for n,im in enumerate(images,1):im.save(folder/f'{n:04d}.png')
    with (TMP/(name+'.log')).open('w') as log:subprocess.run([sys.argv[1],'-b','--factory-startup','--python-exit-code','1','--python',str(OUT.parent/'lowerbody_recovery_test/encode_review.py'),'--',str(folder),str(OUT/(name+'.mp4')),str(n)],check=True,stdout=log,stderr=subprocess.STDOUT)
def run():
    sheets()
    if 'keys' in sys.argv:return
    originals={'full_jump_all_views_1x':[combined(f) for f in range(1,94)]}
    for v in VIEWS:originals[v+'_1x']=[raw(v,f) for f in range(1,94)]
    checks={};decoded=[]
    for name,images in originals.items():
        encode(images,name);path=OUT/(name+'.mp4');cap=cv2.VideoCapture(str(path));fps=cap.get(cv2.CAP_PROP_FPS);size=[int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))];n=0;errors=[]
        while True:
            ok,frame=cap.read()
            if not ok:break
            rgb=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB);errors.append(float(np.abs(rgb.astype('float32')-np.array(images[n])).mean()))
            if name=='full_jump_all_views_1x' and n+1 in KEYS:decoded.append(Image.fromarray(rgb).resize((960,360)))
            n+=1
        cap.release();assert n==93 and fps==30 and size==list(images[0].size),(name,n,fps,size);assert max(errors)<3
        checks[name]={'frames':n,'fps':fps,'size':size,'duration_s':n/fps,'max_mean_rgb_decode_error':max(errors),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    im=Image.new('RGB',(1920,2520),(23,29,35))
    for j,p in enumerate(decoded):im.paste(p,(j%2*960,j//2*360))
    im.save(OUT/'decoded_video_samples.jpg',quality=95)
    checks['passed']=True;(OUT/'media_verification.json').write_text(json.dumps(checks,indent=2),encoding='utf8');print('ALL FOUR FULL-JUMP VIDEOS ENCODED + DECODED, 93 FRAMES AT 30 FPS',flush=True)
if __name__=='__main__':run()
