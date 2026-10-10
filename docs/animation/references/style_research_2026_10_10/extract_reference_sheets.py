"""Read existing reference media; write research-only sheets and timing metadata.

No game assets or animation data are generated. Frame indices are zero based.
Run from any directory with Python, Pillow and OpenCV.
"""
from pathlib import Path
import hashlib
import json
import math
import cv2
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
LIB = ROOT / 'blender/animation/reviews/player_animation_library_v1'
FONT = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 15)

def sheet(name, frames, labels, cols=5, cell=(240, 300)):
    w,h = cell
    canvas = Image.new('RGB', (w*cols, (h+32)*math.ceil(len(frames)/cols)), '#23262c')
    draw = ImageDraw.Draw(canvas)
    for i,(frame,label) in enumerate(zip(frames,labels)):
        frame = frame.convert('RGBA')
        frame.thumbnail((w-8,h-8))
        x,y = (i%cols)*w, (i//cols)*(h+32)
        canvas.paste(frame,(x+(w-frame.width)//2,y+(h-frame.height)//2),frame)
        draw.text((x+5,y+h+4),label,font=FONT,fill='white')
    canvas.save(OUT / (name+'.jpg'), quality=94)

records = []
for name in ['Player_Jump_(Dungeons_II)', 'Player_Jump_Land_(Dungeons_II)']:
    path = LIB / 'jump_dungeons_gif_v004/references' / (name+'.gif')
    im = Image.open(path)
    frames,labels,times = [],[],[]
    elapsed = 0
    for i in range(im.n_frames):
        im.seek(i)
        duration = im.info.get('duration',0)
        frames.append(im.convert('RGBA').copy())
        labels.append(f'f{i:02d} {elapsed/1000:.3f}s +{duration}ms')
        times.append({'frame':i,'start_ms':elapsed,'duration_ms':duration})
        elapsed += duration
    sheet(name,frames,labels)
    records.append({'id':name,'path':path.relative_to(ROOT).as_posix(),
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'frames':times,
        'duration_ms':elapsed,'sheet':name+'.jpg',
        'provenance':'Existing user-provided GIF; filename identifies Dungeons II; original web URL not recorded.'})

for kind in ['stationary','walk','run']:
    path=LIB / 'jump_set_v002/references' / kind / 'source.mp4'
    cap=cv2.VideoCapture(str(path))
    fps=cap.get(cv2.CAP_PROP_FPS)
    decoded=[]
    while True:
        ok,bgr=cap.read()
        if not ok:break
        decoded.append(Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)))
    cap.release()
    indices=list(range(0,len(decoded),max(1,round(fps/2))))
    sheet(kind+'_overview',[decoded[i] for i in indices],
          [f'f{i:03d} {i/fps:.3f}s' for i in indices],cols=6,cell=(160,200))
    records.append({'id':kind,'path':path.relative_to(ROOT).as_posix(),
       'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'fps':fps,
       'decoded_frames':len(decoded),'duration_s':len(decoded)/fps,
       'sampled_frames':indices,'sheet':kind+'_overview.jpg',
       'provenance':'Existing user screen recording; original web URL/build not recorded. Identity must be judged from pixels, not earlier study conclusions.'})

(OUT/'media_manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps([{k:v for k,v in r.items() if k not in ['frames','sampled_frames']} for r in records],indent=2))
