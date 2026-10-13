from pathlib import Path
import hashlib, json
import cv2
import numpy as np
from PIL import Image, ImageDraw

BASE = Path(__file__).resolve().parent
SOURCE = Path(r'C:/Users/ADMIN/Videos/Screen Recordings/Screen Recording 2026-10-13 043804.mp4')
cap = cv2.VideoCapture(str(SOURCE))
fps = cap.get(cv2.CAP_PROP_FPS)
reported = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
frames = []
timestamps = []
while True:
    ok, frame = cap.read()
    if not ok:
        break
    timestamps.append(cap.get(cv2.CAP_PROP_POS_MSEC))
    frames.append(Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)))
cap.release()
if not frames:
    raise RuntimeError('No frames decoded')
diffs = [float(np.abs(np.asarray(b, dtype=np.float32)-np.asarray(a, dtype=np.float32)).mean()) for a,b in zip(frames,frames[1:])]

def sheet(indices, name, cols=6, width=240, crop=None):
    if crop:
        fw,fh=crop[2]-crop[0],crop[3]-crop[1]
    else:
        fw,fh=frames[0].size
    height=round(fh*width/fw)
    rows=(len(indices)+cols-1)//cols
    canvas=Image.new('RGB',(cols*width,rows*(height+24)),(24,26,31))
    draw=ImageDraw.Draw(canvas)
    for j,i in enumerate(indices):
        x,y=(j%cols)*width,(j//cols)*(height+24)
        im=frames[i].crop(crop) if crop else frames[i]
        im=im.resize((width,height),Image.Resampling.LANCZOS)
        canvas.paste(im,(x,y+24))
        draw.text((x+5,y+5),f'F{i:03d}  {i/fps:.3f}s',(245,245,245))
    canvas.save(BASE/name,quality=94)

overview=list(range(0,len(frames),15))
if overview[-1]!=len(frames)-1: overview.append(len(frames)-1)
sheet(overview,'supplement2_overview.jpg',cols=4,width=360)
for start in range(0,len(frames),36):
    sheet(list(range(start,min(start+36,len(frames)))),f'supplement2_all_frames_{start:03d}.jpg')
report={'source':str(SOURCE),'sha256':hashlib.file_digest(SOURCE.open('rb'),'sha256').hexdigest(),'fps':fps,'reported_frame_count':reported,'decoded_frame_count':len(frames),'width':frames[0].width,'height':frames[0].height,'duration_from_count_s':len(frames)/fps,'first_to_last_sample_span_s':(len(frames)-1)/fps,'decode_backend':'OpenCV sequential decode','frame_numbering':'zero-based; nominal time = F/fps','timestamps_msec':timestamps,'adjacent_mean_absolute_rgb_difference':diffs,'exact_adjacent_repeats':[i+1 for i,d in enumerate(diffs) if d==0.0],'source_pack_version':'unknown','playback_speed_and_input':'unknown; encoded fps is not proof of original engine timing'}
(BASE/'supplement2_decode.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ('sha256','fps','decoded_frame_count','width','height','duration_from_count_s','exact_adjacent_repeats')},indent=2))
