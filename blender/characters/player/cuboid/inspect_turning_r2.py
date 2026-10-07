import cv2,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
BASE=Path(__file__).resolve().parent;OUT=BASE/'turning_study_r2_review';OUT.mkdir(exist_ok=True)
REF=BASE.parents[3]/'references/animation/minecraft_turning_reference'
m=json.loads((REF/'metadata.json').read_text());p=REF/'originals'/m['file']
assert hashlib.sha256(p.read_bytes()).hexdigest()==m['original_sha256']
c=cv2.VideoCapture(str(p));frames=[]
while True:
    ok,f=c.read()
    if not ok:break
    frames.append(Image.fromarray(cv2.cvtColor(f,cv2.COLOR_BGR2RGB)))
c.release();assert len(frames)==589
indexes=[38,42,50,250,254,263,360,375,390,405,528,537,547]
sheet=Image.new('RGB',(1000,3*315),(24,28,34));d=ImageDraw.Draw(sheet)
for j,i in enumerate(indexes):
    im=frames[i].copy();im.thumbnail((195,280));x=j%5*200;y=j//5*315
    sheet.paste(im,(x+(200-im.width)//2,y+25));d.text((x+5,y+5),f'f{i} / {i/30:.3f}s',fill='white')
sheet.save(OUT/'source_fullframe_evidence.jpg',quality=95)
(OUT/'source_verification.json').write_text(json.dumps({'metadata':m,'decoded_frames':len(frames),'sha256_verified':True,'additional_full_frames':indexes,'method':'Decoded frames and supplied sheets; no claim of continuous playback observation'},indent=2))
print('R2_SOURCE_VERIFIED',len(frames))
