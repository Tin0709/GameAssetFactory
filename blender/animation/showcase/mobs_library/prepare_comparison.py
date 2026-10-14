from pathlib import Path
from PIL import Image,ImageDraw
import json
OUT=Path(__file__).resolve().parent
records=[]
for kind,old,new,count in [('Idle',90,120,360),('Walk',48,42,336)]:
    folder=OUT/'comparison_frames'/kind;folder.mkdir(parents=True,exist_ok=True)
    for j in range(count):
        canvas=Image.new('RGB',(896,480),(24,29,34));d=ImageDraw.Draw(canvas)
        a=Image.open(OUT/'baseline_frames'/kind/f'{j%old+1:04}.png').convert('RGB')
        b=Image.open(OUT/'motion_frames'/f'{kind}_THREE_QUARTER'/f'{j%new+1:04}.png').convert('RGB')
        canvas.paste(a,(0,32));canvas.paste(b,(448,32))
        d.text((12,9),f'Existing Zombie_{kind} | {old/30:.2f}s cycle',fill='white')
        d.text((460,9),f'Zombie_{kind}_Original_V1 | Pending | {new/30:.2f}s',fill='white')
        canvas.save(folder/f'{j+1:04}.png')
    records.append({'kind':kind,'frames':count,'fps':30,'width':896,'height':480,'folder':str(folder),'output':str(OUT/'review'/f'Zombie_{kind}_Existing_vs_Original_V1_1x.mp4')})
(OUT/'comparison_manifest.json').write_text(json.dumps(records,indent=2))
print('COMPARISON_FRAMES_READY')
