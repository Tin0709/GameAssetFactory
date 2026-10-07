"""Read both original recordings; verify cadence without claiming recovered 3D motion."""
import cv2,json,hashlib
import numpy as np
from pathlib import Path
from PIL import Image,ImageDraw
BASE=Path(__file__).resolve().parent
REF=BASE.parents[3]/'references/animation/minecraft_locomotion_reference'
OUT=BASE/'reference_study_r1_review';OUT.mkdir(exist_ok=True)
metadata=json.loads((REF/'notes/reference_metadata.json').read_text())
videos={};report={}
for tag in ['093200','093249']:
    path=REF/'originals'/metadata[tag]['file'];assert path.exists()
    assert hashlib.sha256(path.read_bytes()).hexdigest()==metadata['analysis']['source_sha256'][path.name]
    cap=cv2.VideoCapture(str(path));frames=[]
    while True:
        ok,f=cap.read()
        if not ok:break
        frames.append(cv2.cvtColor(f,cv2.COLOR_BGR2RGB))
    fps=cap.get(cv2.CAP_PROP_FPS);cap.release()
    assert len(frames)==metadata[tag]['nframes']
    videos[tag]=frames;report[tag]={'fps':fps,'decoded_frames':len(frames),'shape':list(frames[0].shape),'hash_verified':True}
windows=[('rear_walk','093200',57,174),('rear_sprint','093200',195,336),('front_walk','093249',6,72),('front_sprint','093249',90,225)]
for label,tag,start,end in windows:
    fs=np.array(videos[tag][start:end+1],dtype=np.float32)
    # Brown/dark character weighting, excluding most green ground / blue sky.
    r,g,b=fs[:,:,:,0],fs[:,:,:,1],fs[:,:,:,2]
    mask=(r>g*.92)&(b<g*1.30)&(r<220)&(g<190)
    w=fs.shape[2];mask[:,:,:int(w*.15)]=False;mask[:,:,int(w*.85):]=False
    scores={}
    for lag in range(12,25):
        m=mask[:-lag]|mask[lag:]
        scores[lag]=float(np.abs(fs[:-lag]-fs[lag:]).mean(3)[m].mean())
    report[label]={'window':[start/30,end/30],'lag_scores':scores,'best_full_cycle_lags':sorted(scores,key=scores.get)[:3]}
    # Each row follows one take; these are never presented as synchronized cameras.
    anchor={'rear_walk':65,'rear_sprint':205,'front_walk':25,'front_sprint':90}[label]
    lag=min(scores,key=scores.get)
    indexes=[anchor,anchor+lag,anchor+2*lag]
    if label=='front_walk':indexes=[25,45,65]
    sheet=Image.new('RGB',(660,438),(24,28,32));d=ImageDraw.Draw(sheet)
    for j,i in enumerate(indexes):
        im=Image.fromarray(videos[tag][i]);im.thumbnail((216,396))
        sheet.paste(im,(j*220+(216-im.width)//2,30))
        d.text((j*220+4,7),f'{tag} f{i} / {i/30:.3f}s',fill='white')
    sheet.save(OUT/(label+'_repeat_check.png'))
# Twelve consecutive source frames around the forward-arm/recovery changes.
for label,tag,start in [('front_sprint_consecutive','093249',90),('rear_walk_consecutive','093200',65)]:
    sheet=Image.new('RGB',(960,650),(24,28,32));d=ImageDraw.Draw(sheet)
    for j,i in enumerate(range(start,start+12)):
        im=Image.fromarray(videos[tag][i]);im.thumbnail((154,295))
        x=(j%6)*160;y=(j//6)*325
        sheet.paste(im,(x+(154-im.width)//2,y+26));d.text((x+3,y+5),f'f{i} {i/30:.3f}s',fill='white')
    sheet.save(OUT/(label+'.png'))
(OUT/'source_verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
