"""CPU audit of actual encoded pixels. Second journey is opposite phase, not replay."""
from pathlib import Path
import cv2,json,hashlib
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent
frames=[18,21,22,28,32,75,79,83,87,126,132,183,187,191,208]
reports=[]
for stem in ['block_jump_gameplay','block_jump_side']:
    p=OUT/(stem+'.mp4');cap=cv2.VideoCapture(str(p));assert cap.isOpened()
    fps=cap.get(cv2.CAP_PROP_FPS);count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));w=int(cap.get(cv2.CAP_PROP_FRAME_WIDTH));h=int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    assert fps==24 and count==208 and (w,h)==(960,540),(fps,count,w,h)
    decoded=0
    while True:
        ok,bgr=cap.read()
        if not ok:break
        decoded+=1
    assert decoded==208
    sheet=Image.new('RGB',(4*480,4*294),(20,24,30));draw=ImageDraw.Draw(sheet);phase_differences=[]
    for i,f in enumerate(frames):
        cap.set(cv2.CAP_PROP_POS_FRAMES,f-1);ok,bgr=cap.read();assert ok
        im=Image.fromarray(cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB));im.thumbnail((480,270));x=i%4*480;y=i//4*294;sheet.paste(im,(x,y));draw.text((x+8,y+274),f'f{f:03d}  phase '+('A' if f<105 else 'B / opposite lead'),fill=(235,239,242))
        if f in [22,28,79,83,87]:
            cap.set(cv2.CAP_PROP_POS_FRAMES,f+103);ok,opposite=cap.read();assert ok
            phase_differences.append({'first_frame':f,'opposite_frame':f+104,'mean_pixel_difference':float(cv2.absdiff(bgr,opposite).mean())})
    cap.release();dest=OUT/'.validation'/(stem+'_encoded_sheet.jpg');sheet.save(dest,quality=93)
    reports.append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'fps':fps,'frames':count,'decoded_all_frames':decoded,'size':[w,h],'duration_s':count/fps,'second_journey_offset8_opposite_lead':True,'phase_comparison_compression_included':phase_differences,'encoded_pixel_sheet':str(dest.relative_to(OUT))})
(OUT/'video_audit.json').write_text(json.dumps(reports,indent=2));print(json.dumps(reports,indent=2))
