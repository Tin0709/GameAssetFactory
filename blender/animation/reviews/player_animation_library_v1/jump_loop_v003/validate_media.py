"""Decode every delivered frame and compare equivalent rendered loop phases."""
from pathlib import Path
import cv2,json,hashlib,numpy as np
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent;TMP=OUT.parents[4]/'.validation/jump_loop_v003'
m=json.loads((OUT/'media_manifest.json').read_text());cases=json.loads((OUT/'manifest.json').read_text())['cases']
report={};grid=Image.new('RGB',(1280,586),(20,28,37));draw=ImageDraw.Draw(grid)
for row,(kind,p) in enumerate(m['previews'].items()):
    path=OUT/p['file'];cap=cv2.VideoCapture(str(path));fps=cap.get(cv2.CAP_PROP_FPS)
    size=[int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))]
    n=0;period=cases[kind]['period'];select=[period-2,period-1,period,period+1]
    while True:
        ok,frame=cap.read()
        if not ok:break
        if n in select:
            im=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB)).resize((320,147),Image.Resampling.LANCZOS)
            x=select.index(n)*320;y=row*293
            grid.paste(im,(x,y+35));draw.text((x+8,y+10),f'{kind} frame{n+1} / '+('next loop' if n>=period else 'end loop'),fill='white')
        n+=1
    cap.release();assert n==p['frames'] and fps==30 and size==p['size'],(kind,n,fps,size)
    phase_error={}
    for view in ['gameplay','side']:
        folder=TMP/'frames'/kind/view;a=np.asarray(Image.open(folder/'001.png')).astype(float)
        errors=[]
        for cycle in [1,2]:
            b=np.asarray(Image.open(folder/f'{1+cycle*period:03d}.png')).astype(float)
            errors.append(float(np.abs(a-b).mean()))
        assert max(errors)<.1,(kind,view,'Lighting/pose pop between cycles',errors)
        phase_error[view]=errors
    report[kind]={'decoded_frames':n,'fps':fps,'size':size,'seconds':n/fps,'cuts_or_holds_added':False,
                  'rendered_equivalent_phase_pixel_mae_0_255':phase_error,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(OUT/'media_validation.json').write_text(json.dumps(report,indent=2))
grid.save(TMP/'decoded_loop_joins.jpg',quality=94);print(json.dumps(report,indent=2))
