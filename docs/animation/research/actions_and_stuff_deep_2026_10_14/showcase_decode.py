from pathlib import Path
import cv2, hashlib, json, math
from PIL import Image, ImageDraw, ImageFont
from portable_inputs import source, font as portable_font
SRC=source('showcase')
OUT=Path(__file__).resolve().parent
font=portable_font(17, monospace=True)
cap=cv2.VideoCapture(str(SRC))
fps=cap.get(cv2.CAP_PROP_FPS); declared=int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
w=int(cap.get(cv2.CAP_PROP_FRAME_WIDTH));h=int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
samples=[]; count=0; timestamps=[]
stride=max(1,round(fps))
while True:
 ok,bgr=cap.read()
 if not ok:break
 timestamps.append(cap.get(cv2.CAP_PROP_POS_MSEC))
 if count%stride==0:
  im=Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB))
  samples.append((count,im))
 count+=1
cap.release()
for page in range(math.ceil(len(samples)/24)):
 batch=samples[page*24:(page+1)*24]
 cw,ch=480,310;cols=4;rows=math.ceil(len(batch)/cols)
 canvas=Image.new("RGB",(cols*cw,rows*ch),"#111820");d=ImageDraw.Draw(canvas)
 for j,(idx,im) in enumerate(batch):
  im.thumbnail((cw-8,ch-36))
  x=j%cols*cw;y=j//cols*ch
  canvas.paste(im,(x+(cw-im.width)//2,y))
  d.text((x+6,y+ch-30),f"F{idx} | {idx/fps:.3f}s",font=font,fill="white")
 canvas.save(OUT/f"showcase_overview_{page:02d}.jpg",quality=94)
meta={"path":str(SRC),"sha256":hashlib.sha256(SRC.read_bytes()).hexdigest(),"bytes":SRC.stat().st_size,"fps_reported":fps,"frame_count_declared":declared,"frame_count_decoded":count,"width":w,"height":h,"duration_from_frames_s":count/fps,"last_frame_time_s":(count-1)/fps,"sampled_frames":[i for i,im in samples],"sampling":"Sequential full decode; overview one frame per approximately one second","timestamp_first_ms":timestamps[0],"timestamp_last_ms":timestamps[-1],"clip_speed":"Unknown unless established by visible source UI","audio":"Not inspected"}
(OUT/"showcase_decode_report.json").write_text(json.dumps(meta,indent=2),encoding="utf-8")
print(json.dumps(meta,indent=2))
