import json,math
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent/'turning_study_r3_review';bounds=json.loads((OUT/'pose_bounds.json').read_text());meta=json.loads((OUT/'preview_metadata.json').read_text());font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
for gait in ['Walk','Sprint']:
 sheet=Image.new('RGB',(1440,1320),'#111922');d=ImageDraw.Draw(sheet)
 for j,f in enumerate([13,37,61,109,181,265,289,313,337,397,421,445]):
  im=Image.open(OUT/'ab_raw'/('%04d.png'%f));bs=[bounds[gait+'_'+v+'_'+str(f)] for v in ['A','B']];ww=math.ceil(max(b[2]-b[0] for b in bs))+24;hh=math.ceil(max(b[3]-b[1] for b in bs))+24;x=j%3*480;y=j//3*330
  for k,b in enumerate(bs):
   cx=(b[0]+b[2])/2;cy=(b[1]+b[3])/2;crop=im.crop((round(cx-ww/2),round(cy-hh/2),round(cx+ww/2),round(cy+hh/2)));crop.thumbnail((232,270),Image.Resampling.LANCZOS);sheet.paste(crop,(x+k*240+(240-crop.width)//2,y+30));d.text((x+k*240+8,y+5),'A path only' if k==0 else 'B + turn',font=font,fill='white')
  row=meta['gaits'][gait]['rows'][f-1];d.text((x+8,y+303),f"{row['case']} f{f} / {row['time']:.2f}s / phi {row['phase']:.2f}",font=font,fill='#a7dfec')
 sheet.save(OUT/(gait.lower()+'_detail_sequence.jpg'),quality=95)
print('R3_DETAIL_SHEETS_DONE',flush=True)
