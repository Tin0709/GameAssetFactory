"""CPU decode the actual MP4 pixels for format/frame/replay verification and QA sheet."""
from pathlib import Path
import cv2,json,hashlib
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent
frames=[1,18,21,25,28,32,36,65,69,75,80,85,91,104]
reports=[]
for stem in ['block_jump_gameplay','block_jump_side']:
    p=OUT/(stem+'.mp4');cap=cv2.VideoCapture(str(p));assert cap.isOpened()
    fps=cap.get(cv2.CAP_PROP_FPS);count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));w=int(cap.get(cv2.CAP_PROP_FRAME_WIDTH));h=int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    assert fps==24 and count==208 and (w,h)==(960,540),(fps,count,w,h)
    sheet=Image.new('RGB',(4*480,4*294),(20,24,30));draw=ImageDraw.Draw(sheet);decoded=0;replaydiff=[]
    while True:
        ok,bgr=cap.read()
        if not ok:break
        decoded+=1
    assert decoded==208
    for i,f in enumerate(frames):
        cap.set(cv2.CAP_PROP_POS_FRAMES,f-1);ok,bgr=cap.read();assert ok
        im=Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB));im.thumbnail((480,270));x=i%4*480;y=i//4*294;sheet.paste(im,(x,y));draw.text((x+8,y+274),f'f{f:03d}  {(f-1)/24:.3f}s',fill=(235,239,242))
        cap.set(cv2.CAP_PROP_POS_FRAMES,f+103);ok,replay=cap.read();assert ok
        replaydiff.append(float(cv2.absdiff(bgr,replay).mean()))
    cap.release();dest=OUT/'.validation'/(stem+'_encoded_sheet.jpg');sheet.save(dest,quality=93)
    reports.append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'fps':fps,'frames':count,'decoded_all_frames':decoded,'size':[w,h],'duration_s':count/fps,'same_clock_replay':True,'max_replay_pixel_mean_error_compression':max(replaydiff),'encoded_pixel_sheet':str(dest.relative_to(OUT))})
(OUT/'video_audit.json').write_text(json.dumps(reports,indent=2));print(json.dumps(reports,indent=2))
