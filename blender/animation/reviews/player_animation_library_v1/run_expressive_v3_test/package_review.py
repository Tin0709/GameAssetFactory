from pathlib import Path
import json,hashlib,shutil
from PIL import Image,ImageDraw,ImageFont
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/run_expressive_v3_test';V=O.parent/'run_expressive_v2_test';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=json.loads((O/'render_provenance.json').read_text());v=json.loads((O/'validation.json').read_text());old=json.loads((V/'render_provenance.json').read_text());b=json.loads((T/'baseline.json').read_text())
assert p['source_sha256']==v['source_sha256']==sha(O/'run_expressive_v3_review.blend') and len(p['frames'])==120
assert all(sha(O/f)==h for f,h in p['frames'].items()) and sha(V/'run_expressive_v2_review.blend')==b['basis_source_sha256']==old['source_sha256']
for view in ['front','three_quarter','side']:
 for f in range(1,23):assert sha(V/'frames'/view/f'{f:04d}.png')==old['frames'][f'frames/{view}/{f:04d}.png']
E=T/'encode_copy';E.mkdir();font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',25);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
counts={'front':120,'three_quarter':120,'side':120,'three_views':120,'travel':60,'v2_comparison':220};folders={k:E/k for k in counts}
for d in folders.values():d.mkdir()
for f in range(1,121):
 n=(f-1)%20+1;canvas=Image.new('RGB',(1920,700),'#17212a');draw=ImageDraw.Draw(canvas)
 for j,view in enumerate(['front','three_quarter','side']):
  path=O/'frames'/view/f'{n:04d}.png';shutil.copy2(path,folders[view]/f'{f:04d}.png');canvas.paste(Image.open(path).convert('RGB'),(j*640,60));draw.text((j*640+14,18),view.replace('_',' ').title()+' / Run v3 Pending / 1x',font=font,fill='white')
 canvas.save(folders['three_views']/f'{f:04d}.png',compress_level=1)
for f in range(1,61):shutil.copy2(O/'travel_frames/side'/f'{f:04d}.png',folders['travel']/f'{f:04d}.png')
for f in range(1,221):
 n=(f-1)%20+1;oldf=(f-1)%22+1;canvas=Image.new('RGB',(1280,700),'#17212a');draw=ImageDraw.Draw(canvas)
 for j,(im,label) in enumerate([(V/'frames/three_quarter'/f'{oldf:04d}.png','Preserved Run v2 / 1x'),(O/'frames/three_quarter'/f'{n:04d}.png','Run v3 / faster + stronger arms / 1x')]):
  canvas.paste(Image.open(im).convert('RGB'),(j*640,60));draw.text((j*640+14,18),label,font=font,fill='white')
 canvas.save(folders['v2_comparison']/f'{f:04d}.png',compress_level=1)
keys=[1,3,6,9,10,11,13,16,19,20];sheet=Image.new('RGB',(3000,960),'#17212a');draw=ImageDraw.Draw(sheet)
for row,view in enumerate(['front','three_quarter','side']):
 for col,f in enumerate(keys):
  im=Image.open(O/'frames'/view/f'{f:04d}.png').convert('RGB').resize((300,300));sheet.paste(im,(col*300,row*320+20));draw.text((col*300+5,row*320+2),f'{view} F{f}',font=small,fill='white')
sheet.save(O/'run_v3_pose_sheet.jpg',quality=94)
report={'source_sha256':p['source_sha256'],'action_sha256':p['action_sha256'],'previous_source_sha256':old['source_sha256'],'fps':30,'videos':{k:{'folder':str(folders[k]),'frames':c} for k,c in counts.items()},'comparisons_original_speed_no_retiming':True,'matching_stage_camera_lighting':True,'closing_keys_excluded':True}
(O/'package_provenance.json').write_text(json.dumps(report,indent=2));print('PACKAGED6 ORIGINAL-SPEED VIDEOS / V2 UNCHANGED')
