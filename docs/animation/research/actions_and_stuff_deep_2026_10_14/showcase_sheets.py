from pathlib import Path
import cv2,math,json,numpy as np
from PIL import Image,ImageDraw,ImageFont
from portable_inputs import source, font as portable_font
OUT=Path(__file__).resolve().parent
SRC=source('showcase')
cap=cv2.VideoCapture(str(SRC)); frames=[]
while True:
 ok,bgr=cap.read()
 if not ok:break
 frames.append(Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)))
cap.release()
font=portable_font(14, monospace=True)
def sheet(prefix,ids,perpage=30,cw=200,ch=318,cols=5):
 for p in range(math.ceil(len(ids)/perpage)):
  batch=ids[p*perpage:(p+1)*perpage]
  canvas=Image.new("RGB",(cw*cols,ch*math.ceil(len(batch)/cols)),"#111820");d=ImageDraw.Draw(canvas)
  for j,i in enumerate(batch):
   im=frames[i].copy();im.thumbnail((cw-4,ch-32))
   x=j%cols*cw;y=j//cols*ch
   canvas.paste(im,(x+(cw-im.width)//2,y))
   d.text((x+3,y+ch-27),f"F{i} {i/30:.3f}s",font=font,fill="white")
  canvas.save(OUT/f"{prefix}_{p:02d}.jpg",quality=95)
sheet("showcase_temporal_index",list(range(0,len(frames),6)))
diff=[]
for i in range(1,len(frames)):
 a=np.asarray(frames[i].resize((89,126)),dtype=np.int16); b=np.asarray(frames[i-1].resize((89,126)),dtype=np.int16)
 diff.append((i,float(np.abs(a-b).mean())))
print("largest image differences",sorted(diff,key=lambda x:-x[1])[:25])
# Consecutive complete playback windows, authored labels intentionally absent.
for label,start,end in [("showcase_entry",0,48),("showcase_rear_locomotion",49,109),("showcase_step_jump",110,179),("showcase_turn_land",180,269),("showcase_rear_repeat",270,359),("showcase_turn_run",420,479),("showcase_front_exit",550,637)]:
 sheet(label,list(range(start,end+1)))
sheet('showcase_view_boundary',list(range(540,550)))
for i in [0,30,60,85,90,101,120,150,180,210,213,228,240,242,250,270,276,287,300,328,330,360,390,420,450,480,510,540,545,546,570,600,617,618,630]:
 frames[i].save(OUT/f"showcase_frame_{i:04d}.png")
(OUT/"showcase_index_manifest.json").write_text(json.dumps({"index_stride_frames":6,"index_sampled_frames":list(range(0,len(frames),6)),"consecutive_windows":[[0,48],[49,109],[110,179],[180,269],[270,359],[420,479],[540,549],[550,637]],"visually_inspected_consecutive_intervals":[[0,359],[420,479],[540,637]],"visually_inspected_consecutive_frame_count":518,"native_stills_inspected":[85,242,276],"perspective_boundaries_verified":[28,38,546,618],"audio_inspected":False,"difference_candidates":sorted(diff,key=lambda x:-x[1])[:25],"note":"Pixel differences locate review candidates only; not automated shot or motion classifications. Inspection fields record the 2026-10-14 human/model visual review, not an automatic analysis performed by this script."},indent=2),encoding="utf-8")
