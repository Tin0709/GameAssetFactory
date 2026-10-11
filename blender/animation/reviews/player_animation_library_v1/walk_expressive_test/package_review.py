"""Source-bound original-speed repeats and matching-camera review sheets."""
from pathlib import Path
import json,hashlib,os
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/walk_expressive_test';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
v=json.loads((OUT/'validation.json').read_text());stamp=json.loads((OUT/'render_provenance.json').read_text());travel=json.loads((OUT/'travel_provenance.json').read_text())
assert v['passed'] and v['source_sha256']==sha(OUT/'walk_expressive_review.blend')==stamp['source_sha256']==travel['source_sha256'] and v['action_sha256']==stamp['action_sha256']==travel['action_sha256']
assert len(stamp['frames'])==108 and len(travel['frames'])==108
assert all(sha(OUT/p)==h for record in [stamp,travel] for p,h in record['frames'].items())
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
encode=TMP/'encode';encode.mkdir();views=['front','three_quarter','side'];folders={view:encode/view for view in views+['three_views','travel','comparison']}
for folder in folders.values():folder.mkdir()
for f in range(1,145):
 native=(f-1)%36+1;canvas=Image.new('RGB',(1920,700),'#17212a');draw=ImageDraw.Draw(canvas)
 for j,view in enumerate(views):
  p=OUT/'frames'/view/f'{native:04d}.png';os.link(p,folders[view]/f'{f:04d}.png');im=Image.open(p).convert('RGB');assert im.size==(640,640)
  canvas.paste(im,(j*640,60));draw.text((j*640+18,16),view.replace('_',' ').title()+' / Walk Pending / 1x',font=font,fill='white')
 canvas.save(folders['three_views']/f'{f:04d}.png')
for f in range(1,109):os.link(OUT/'travel_frames/side'/f'{f:04d}.png',folders['travel']/f'{f:04d}.png')
previous=TMP/'before_quieter_sway/walk_expressive_test'
previous_proof=json.loads((previous/'render_provenance.json').read_text())
assert sha(previous/'walk_expressive_review.blend')==previous_proof['source_sha256']
for f in range(1,145):
 native=(f-1)%36+1;canvas=Image.new('RGB',(1280,700),'#17212a');draw=ImageDraw.Draw(canvas)
 old=previous/'frames/three_quarter'/f'{native:04d}.png'
 assert sha(old)==previous_proof['frames'][old.relative_to(previous).as_posix()]
 for j,(p,label) in enumerate([(old,'Previous walk / 1x'),(OUT/'frames/three_quarter'/f'{native:04d}.png','Quieter sway / closer legs / Pending / 1x')]):
  canvas.paste(Image.open(p).convert('RGB'),(j*640,60));draw.text((j*640+14,18),label,font=font,fill='white')
 canvas.save(folders['comparison']/f'{f:04d}.png')
keys=[1,5,10,16,19,23,28,34];labels=['L contact','Receive','L support / R pass','Release','R contact','Receive','R support / L pass','Release']
sheet=Image.new('RGB',(2560,1080),'#17212a');draw=ImageDraw.Draw(sheet)
for row,view in enumerate(views):
 for column,(f,label) in enumerate(zip(keys,labels)):
  im=Image.open(OUT/'frames'/view/f'{f:04d}.png').convert('RGB');im.thumbnail((320,320));sheet.paste(im,(column*320,row*360+40));draw.text((column*320+8,row*360+5),f'{view} F{f}: {label}',font=small,fill='white')
sheet.save(OUT/'walk_pose_sheet.jpg',quality=94)
body_compare=Image.new('RGB',(1600,880),'#17212a');draw=ImageDraw.Draw(body_compare)
for row in [0,1]:
 for col,f in enumerate([1,10,19,28]):
  p=(previous if row==0 else OUT)/'frames/front'/f'{f:04d}.png'
  body_compare.paste(Image.open(p).convert('RGB').resize((400,400)),(col*400,row*440+40))
  draw.text((col*400+10,row*440+10),('Previous' if row==0 else 'Quieter / closer')+f' F{f}',font=small,fill='white')
body_compare.save(OUT/'hip_response_pose_comparison.jpg',quality=94)
cycle=Image.new('RGB',(1440,1560),'#17212a');draw=ImageDraw.Draw(cycle)
for f in range(1,37):
 im=Image.open(OUT/'frames/three_quarter'/f'{f:04d}.png').convert('RGB');im.thumbnail((240,240));x=((f-1)%6)*240;y=((f-1)//6)*260
 cycle.paste(im,(x,y+20));draw.text((x+6,y+3),f'F{f} / {(f-1)/30:.3f}s',fill='white')
cycle.save(OUT/'walk_complete_cycle_sheet.jpg',quality=93)
compare=Image.new('RGB',(1920,700),'#17212a');draw=ImageDraw.Draw(compare)
idle=OUT.parent/'idle_expressive_test_v3';idle_proof=json.loads((idle/'checkpoint_provenance.json').read_text());assert idle_proof['source_sha256']==json.loads((TMP/'baseline.json').read_text())['approved_idle_source_sha256']
old=idle/'checkpoint_frames/three_quarter_0001.png';assert sha(old)==idle_proof['frames'][old.relative_to(idle).as_posix()]
for j,(p,label) in enumerate([(old,'Approved Idle v3 / relaxed support'),(OUT/'frames/three_quarter/0001.png','Walk / left receiving'),(OUT/'frames/three_quarter/0028.png','Walk / right support, left passing')]):
 compare.paste(Image.open(p).convert('RGB'),(j*640,60));draw.text((j*640+14,18),label,font=font,fill='white')
compare.save(OUT/'idle_walk_posture.jpg',quality=94)
report={'source_sha256':v['source_sha256'],'action_sha256':v['action_sha256'],'comparison_previous_source_sha256':previous_proof['source_sha256'],'fps':30,'videos':{view:{'folder':str(folder),'frames':108 if view=='travel' else 144,'complete_loops':3 if view=='travel' else 4} for view,folder in folders.items()},'native_closing_frame_excluded':True,'idle_source_hash_verified':True}
(OUT/'package_provenance.json').write_text(json.dumps(report,indent=2));print('PACKAGED SIX ORIGINAL-SPEED REVIEWS',flush=True)
