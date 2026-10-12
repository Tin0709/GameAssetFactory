from pathlib import Path
import json,hashlib,os
from PIL import Image,ImageDraw,ImageFont
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/run_expressive_v2_test';W=O.parent/'walk_expressive_test';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=json.loads((O/'render_provenance.json').read_text());v=json.loads((O/'validation.json').read_text());wp=json.loads((W/'render_provenance.json').read_text())
assert p['source_sha256']==v['source_sha256']==sha(O/'run_expressive_v2_review.blend') and len(p['frames'])==150
assert all(sha(O/f)==h for f,h in p['frames'].items());assert wp['source_sha256']==p['walk_source_sha256']==sha(W/'walk_expressive_review.blend')
E=T/'encode';E.mkdir();font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
counts={'front':132,'three_quarter':132,'side':132,'three_views':132,'travel':66,'old_comparison':198,'walk_comparison':396};folders={k:E/k for k in counts}
for d in folders.values():d.mkdir()
for f in range(1,133):
 n=(f-1)%22+1;canvas=Image.new('RGB',(1920,700),'#17212a');draw=ImageDraw.Draw(canvas)
 for j,view in enumerate(['front','three_quarter','side']):
  path=O/'frames'/view/f'{n:04d}.png';os.link(path,folders[view]/f'{f:04d}.png');canvas.paste(Image.open(path).convert('RGB'),(j*640,60));draw.text((j*640+14,18),view.replace('_',' ').title()+' / Run v2 Pending / 1x',font=font,fill='white')
 canvas.save(folders['three_views']/f'{f:04d}.png')
for f in range(1,67):os.link(O/'travel_frames/side'/f'{f:04d}.png',folders['travel']/f'{f:04d}.png')
for kind,count in [('old_comparison',198),('walk_comparison',396)]:
 for f in range(1,count+1):
  n=(f-1)%22+1;canvas=Image.new('RGB',(1280,700),'#17212a');draw=ImageDraw.Draw(canvas)
  if kind=='old_comparison':
   old=(f-1+9)%18+1;path=O/'old_run_frames/three_quarter'/f'{old:04d}.png';label='Approved original Run / 1x'
  else:
   old=(f-1)%36+1;path=W/'frames/three_quarter'/f'{old:04d}.png';label='Approved refined Walk / 1x';assert sha(path)==wp['frames'][path.relative_to(W).as_posix()]
  for j,(im,label) in enumerate([(path,label),(O/'frames/three_quarter'/f'{n:04d}.png','Run v2 / Pending / 1x')]):
   canvas.paste(Image.open(im).convert('RGB'),(j*640,60));draw.text((j*640+14,18),label,font=font,fill='white')
  canvas.save(folders[kind]/f'{f:04d}.png')
keys=[1,3,6,10,11,12,14,17,21,22];sheet=Image.new('RGB',(3000,960),'#17212a');draw=ImageDraw.Draw(sheet)
for row,view in enumerate(['front','three_quarter','side']):
 for col,f in enumerate(keys):
  im=Image.open(O/'frames'/view/f'{f:04d}.png').convert('RGB').resize((300,300));sheet.paste(im,(col*300,row*320+20));draw.text((col*300+5,row*320+2),f'{view} F{f}',font=small,fill='white')
sheet.save(O/'run_v2_pose_sheet.jpg',quality=94)
cycle=Image.new('RGB',(1680,1200),'#17212a');draw=ImageDraw.Draw(cycle)
for f in range(1,23):
 x=((f-1)%6)*280;y=((f-1)//6)*300;im=Image.open(O/'frames/three_quarter'/f'{f:04d}.png').convert('RGB').resize((280,280));cycle.paste(im,(x,y+20));draw.text((x+4,y+2),f'F{f} / {(f-1)/30:.3f}s',fill='white')
cycle.save(O/'run_v2_complete_cycle.jpg',quality=94)
report={'source_sha256':p['source_sha256'],'action_sha256':p['action_sha256'],'walk_source_sha256':wp['source_sha256'],'old_run_action_sha256':p['old_run_action_sha256'],'fps':30,'videos':{k:{'folder':str(folders[k]),'frames':c} for k,c in counts.items()},'old_run_starting_frame':10,'comparisons_original_speed_no_retiming':True,'matching_stage_camera_lighting':True,'closing_keys_excluded':True}
(O/'package_provenance.json').write_text(json.dumps(report,indent=2));print('PACKAGED7 ORIGINAL-SPEED VIDEOS; NATIVE TIMING PRESERVED')
