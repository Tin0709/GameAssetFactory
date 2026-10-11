from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;stamp=json.loads((OUT/'attention_provenance.json').read_text());v=json.loads((OUT/'validation.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert stamp['source_sha256']==v['sampled_source_sha256']==sha(OUT/'idle_expressive_v3_review.blend') and stamp['action_sha256']==v['sampled_action_sha256']
assert len(stamp['frames'])==12 and all(sha(OUT/'attention_frames'/p)==h for p,h in stamp['frames'].items())
sheet=Image.new('RGB',(1920,2800),'#17212a');draw=ImageDraw.Draw(sheet);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25)
labels={32:'Viewer right',70:'Top right / 0.25s hold',92:'Bottom left / 0.25s hold',120:'Viewer left'}
for row,frame in enumerate([32,70,92,120]):
 for col,view in enumerate(['front','three_quarter','side']):
  im=Image.open(OUT/'attention_frames'/f'{view}_{frame:04d}.png').convert('RGB');assert im.size==(640,640);sheet.paste(im,(col*640,row*700+60));draw.text((col*640+18,row*700+18),f'{view.replace("_"," ").title()} / {labels[frame]}',font=font,fill='white')
sheet.save(OUT/'lookaround_three_views.jpg',quality=94)
p=OUT/'README.md';t=p.read_text(encoding='utf8')
if '(lookaround_three_views.jpg)' not in t:t=t.replace('- [Leg closeups](stance_legs_checkpoint.jpg).','- [Leg closeups](stance_legs_checkpoint.jpg).\n- [Both stronger looks: front / three-quarter / side](lookaround_three_views.jpg).')
p.write_text(t,encoding='utf8')
print('Packaged twelve source-bound attention poses')
