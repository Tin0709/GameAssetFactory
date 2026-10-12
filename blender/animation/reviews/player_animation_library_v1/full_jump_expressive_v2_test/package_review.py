from pathlib import Path
import json,hashlib,shutil
from PIL import Image,ImageDraw,ImageFont
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/full_jump_expressive_v2_test';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();p=json.loads((O/'render_provenance.json').read_text());v=json.loads((O/'validation.json').read_text());assert p['source_sha256']==v['source_sha256']==sha(O/'full_jump_expressive_v2_review.blend') and len(p['frames'])==279 and all(sha(O/f)==h for f,h in p['frames'].items())
E=T/'encode';E.mkdir();font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',23);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17);folders={view:E/view for view in ['front','three_quarter','side','three_views']}
for d in folders.values():d.mkdir()
for f in range(1,94):
 canvas=Image.new('RGB',(1920,700),'#17212a');draw=ImageDraw.Draw(canvas)
 for j,view in enumerate(['front','three_quarter','side']):
  path=O/'frames'/view/f'{f:03d}.png';shutil.copy2(path,folders[view]/f'{f:04d}.png');canvas.paste(Image.open(path).convert('RGB'),(j*640,60));draw.text((j*640+12,16),view.replace('_',' ').title()+' / Full Jump v2 / Pending / 1x',font=font,fill='white')
 canvas.save(folders['three_views']/f'{f:04d}.png',compress_level=1)
keys=[1,14,19,24,29,33,38,43,46,51,55,67,93];sheet=Image.new('RGB',(2600,660),'#17212a');draw=ImageDraw.Draw(sheet)
for row,view in enumerate(['front','three_quarter','side']):
 for col,f in enumerate(keys):
  sheet.paste(Image.open(O/'frames'/view/f'{f:03d}.png').convert('RGB').resize((200,200)),(col*200,row*220+20));draw.text((col*200+3,row*220+2),f'{view} F{f}',font=small,fill='white')
sheet.save(O/'full_jump_v2_pose_sheet.jpg',quality=94)
peak=Image.new('RGB',(1920,700),'#17212a');d=ImageDraw.Draw(peak)
for j,view in enumerate(['front','three_quarter','side']):peak.paste(Image.open(O/'frames'/view/'033.png').convert('RGB'),(j*640,60));d.text((j*640+12,16),view.replace('_',' ').title()+' / raised arms F33',font=font,fill='white')
peak.save(O/'raised_arm_peak.jpg',quality=95)
report={'source_sha256':p['source_sha256'],'action_sha256':p['action_sha256'],'fps':30,'videos':{view:{'folder':str(path),'frames':93} for view,path in folders.items()},'original_speed':True,'all_new_frames_rendered':len(p['rendered_frames'])==279,'preview_height_m':p['preview_height_m'],'camera_ortho_scale':p['camera_ortho_scale']};(O/'package_provenance.json').write_text(json.dumps(report,indent=2));print('PACKAGED FOUR ORIGINAL-SPEED REVIEWS')
