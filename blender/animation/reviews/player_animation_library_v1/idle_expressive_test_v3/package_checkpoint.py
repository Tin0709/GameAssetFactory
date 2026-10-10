"""Compose current native-render checkpoint; preserve v2 source pixels."""
from pathlib import Path
import json,hashlib,os
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
stamp=json.loads((OUT/'checkpoint_provenance.json').read_text())
assert sha(OUT/'idle_expressive_v3_review.blend')==stamp['source_sha256']
frames=OUT/'checkpoint_frames'
views=['front','three_quarter','side']
sheet=Image.new('RGB',(1920,700),'#17212a');d=ImageDraw.Draw(sheet)
legs=Image.new('RGB',(1200,420),'#17212a');ld=ImageDraw.Draw(legs)
for i,view in enumerate(views):
 im=Image.open(frames/f'{view}_0001.png').convert('RGB')
 assert im.size==(640,640)
 sheet.paste(im,(i*640,60));d.text((i*640+18,18),view.replace('_',' ').title()+' / Pending v3',font=font,fill='white')
 box=(180,330,465,555) if view!='side' else (220,330,405,555)
 crop=im.crop(box);crop.thumbnail((380,340));legs.paste(crop,((i*400)+(400-crop.width)//2,65))
 ld.text((i*400+18,18),view.replace('_',' ').title(),font=font,fill='white')
ld.text((18,380),'Left slightly forward / right back / 15 deg outward; fixed rigid soles',font=font,fill='white')
sheet.save(OUT/'stance_checkpoint.jpg',quality=94);legs.save(OUT/'stance_legs_checkpoint.jpg',quality=95)
if 'stills' in __import__('sys').argv:
 print('STILLS PACKAGED');raise SystemExit
v=json.loads((OUT/'validation.json').read_text());assert v['passed'] and stamp['complete']
assert stamp['source_sha256']==v['sampled_source_sha256'] and stamp['action_sha256']==v['sampled_action_sha256']
assert all(sha(OUT/p)==h for p,h in stamp['frames'].items())
encoded=ROOT/'.validation/idle_expressive_test_v3/checkpoint_encode_frames';encoded.mkdir()
comparison=ROOT/'.validation/idle_expressive_test_v3/checkpoint_comparison_frames';comparison.mkdir()
oldfolder=OUT.parent/'idle_expressive_test_v2/frames/three_quarter'
for f in range(1,481):
 native=frames/'three_quarter'/f'{(f-1)%240+1:04d}.png';os.link(native,encoded/f'{f:04d}.png')
 old=Image.open(oldfolder/f'{(f-1)%240+1:03d}.png').convert('RGB');new=Image.open(native).convert('RGB');assert old.size==new.size
 canvas=Image.new('RGB',(1280,700),'#17212a');draw=ImageDraw.Draw(canvas)
 canvas.paste(old,(0,60));canvas.paste(new,(640,60))
 draw.text((18,18),'Preserved v2 / original speed',font=font,fill='white');draw.text((658,18),'Latest v3 / 2X breathing / Pending',font=font,fill='white')
 canvas.save(comparison/f'{f:04d}.png')
print('CHECKPOINT AND MATCHED THREE-QUARTER COMPARISON FRAMES READY')
