from pathlib import Path
import cv2,math,json,numpy as np
from PIL import Image,ImageDraw,ImageFont
OUT=Path("C:/Users/ADMIN/Desktop/GameAssetFactory/docs/animation/research/actions_and_stuff_deep_2026_10_14")
SRC=Path("C:/Users/ADMIN/Videos/Screen Recordings/Screen Recording 2026-10-14 045502.mp4")
cap=cv2.VideoCapture(str(SRC)); frames=[]
while True:
 ok,bgr=cap.read()
 if not ok:break
 frames.append(Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)))
cap.release()
font=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",14)
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
for i in [0,30,60,90,120,150,180,210,240,270,300,330,360,390,420,450,480,510,540,570,600,630]:
 frames[i].save(OUT/f"showcase_frame_{i:04d}.png")
(OUT/"showcase_index_manifest.json").write_text(json.dumps({"index_stride_frames":6,"index_sampled_frames":list(range(0,len(frames),6)),"consecutive_windows":[[0,48],[49,109],[110,179],[180,269],[270,359],[420,479],[550,637]],"difference_candidates":sorted(diff,key=lambda x:-x[1])[:25],"note":"Pixel differences locate review candidates only; not automated shot or motion classifications."},indent=2),encoding="utf-8")

