from pathlib import Path
import json,hashlib,cv2,numpy as np
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();proof=json.loads((OUT/'package_provenance.json').read_text())
assert sha(OUT/'walk_expressive_review.blend')==proof['source_sha256']
names={'front':'walk_front_1x','three_quarter':'walk_three_quarter_1x','side':'walk_side_1x','three_views':'walk_three_views_1x','travel':'walk_contact_travel_1x','comparison':'hip_response_comparison_1x'}
report={'passed':True,'source_sha256':proof['source_sha256'],'action_sha256':proof['action_sha256'],'videos':{}}
sheet=Image.new('RGB',(1280,1010),'#17212a');draw=ImageDraw.Draw(sheet)
for view,name in names.items():
 record=proof['videos'][view];path=OUT/(name+'.mp4');cap=cv2.VideoCapture(str(path));fps=cap.get(cv2.CAP_PROP_FPS);count=0;error=0.
 while True:
  ok,img=cap.read()
  if not ok:break
  count+=1;ref=cv2.imread(str(Path(record['folder'])/f'{count:04d}.png'));assert ref is not None and img.shape==ref.shape
  error=max(error,float(np.abs(img.astype(np.int16)-ref.astype(np.int16)).mean()))
  if view in ['three_quarter','travel'] and count in [1,10,19,28]:
   j=[1,10,19,28].index(count);row=0 if view=='three_quarter' else 1;im=Image.fromarray(cv2.cvtColor(img,cv2.COLOR_BGR2RGB));im.thumbnail((320,320));sheet.paste(im,(j*320,row*340+30));draw.text((j*320+6,row*340+6),f'{view} / F{count}',fill='white')
 cap.release();assert count==record['frames'] and fps==30 and error<5
 report['videos'][view]={'path':path.name,'sha256':sha(path),'frames':count,'fps':fps,'duration_s':count/fps,'complete_loops':record['complete_loops'],'max_mean_pixel_error':error}
sheet.crop((0,0,1280,680)).save(OUT/'decoded_review_samples.jpg',quality=94)
(OUT/'media_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
