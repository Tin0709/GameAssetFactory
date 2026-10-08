"""CPU-only decode of the user-supplied jump reference; no Blender or game access."""
from pathlib import Path
import json, hashlib, sys
import cv2
from PIL import Image, ImageDraw

SOURCE = Path(r'C:\Users\ADMIN\Videos\Screen Recordings\Screen Recording 2026-10-09 042310.mp4')
OUT = Path(__file__).resolve().parent
RAW = OUT/'.validation/reference_frames'
RAW.mkdir(parents=True,exist_ok=True)
cap = cv2.VideoCapture(str(SOURCE))
assert cap.isOpened()
fps = cap.get(cv2.CAP_PROP_FPS)
count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
times = [float(x) for x in sys.argv[1:]] if len(sys.argv)>1 else [i*.25 for i in range(int(count/fps/.25)+1)]
items=[]
for t in times:
    index=min(count-1, round(t*fps))
    cap.set(cv2.CAP_PROP_POS_FRAMES,index)
    ok,frame=cap.read()
    if not ok: continue
    im=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
    im.save(RAW/f'reference_f{index:04d}.png')
    im.thumbnail((480,270))
    items.append((index,index/fps,im))
cap.release()
cols=4; rows=(len(items)+cols-1)//cols
sheet=Image.new('RGB',(cols*480,rows*302),(22,26,31));draw=ImageDraw.Draw(sheet)
for n,(index,t,im) in enumerate(items):
    x=n%cols*480;y=n//cols*302
    sheet.paste(im,(x,y+25));draw.text((x+8,y+5),f'f{index} / {t:.3f}s',fill=(235,239,243))
stem='reference_overview' if len(sys.argv)==1 else f'reference_detail_f{items[0][0]:04d}'
sheet.save(OUT/(stem+'.jpg'),quality=94)
for start in range(0,len(items),16):
    batch=items[start:start+16]
    close=Image.new('RGB',(4*255,4*348),(22,26,31));dd=ImageDraw.Draw(close)
    for n,(index,t,thumb) in enumerate(batch):
        full=Image.open(RAW/f'reference_f{index:04d}.png')
        full=full.resize((255,323))
        x=n%4*255;y=n//4*348
        close.paste(full,(x,y+25));dd.text((x+8,y+5),f'f{index} / {t:.3f}s',fill=(235,239,243))
    close.save(OUT/f'{stem}_{start//16:02d}.jpg',quality=96)
metadata={'source':str(SOURCE),'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'fps':fps,'frames':count,'duration_s':count/fps,'dimensions':[width,height],'sampled_frames':[i for i,t,im in items],'sheet':stem+'.jpg'}
(OUT/(stem+'.json')).write_text(json.dumps(metadata,indent=2))
print(json.dumps(metadata))
