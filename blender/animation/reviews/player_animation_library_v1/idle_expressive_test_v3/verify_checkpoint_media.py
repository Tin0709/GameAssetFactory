from pathlib import Path
import json,hashlib,cv2,numpy as np
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
v=json.loads((OUT/'validation.json').read_text());stamp=json.loads((OUT/'checkpoint_provenance.json').read_text())
assert v['passed'] and stamp['complete'] and sha(OUT/'idle_expressive_v3_review.blend')==v['sampled_source_sha256']==stamp['source_sha256']
report={'passed':True,'source_sha256':stamp['source_sha256'],'action_sha256':stamp['action_sha256'],'scope':'Two-loop native three-quarter checkpoint and preserved-v2 comparison; three-view stills. Full updated front/side motion set deferred for requested stance feedback.'}
sheet=Image.new('RGB',(1280,680),'#17212a');draw=ImageDraw.Draw(sheet)
for name,folder in [('stance_breath_three_quarter_1x','checkpoint_encode_frames'),('comparison_three_quarter_checkpoint_1x','checkpoint_comparison_frames')]:
 p=OUT/(name+'.mp4');cap=cv2.VideoCapture(str(p));fps=cap.get(cv2.CAP_PROP_FPS);declared=int(cap.get(cv2.CAP_PROP_FRAME_COUNT));errors=[];f=0
 while True:
  ok,img=cap.read()
  if not ok:break
  f+=1;ref=cv2.imread(str(ROOT/'.validation/idle_expressive_test_v3'/folder/f'{f:04d}.png'))
  assert img.shape==ref.shape
  errors.append(float(np.abs(img.astype(np.int16)-ref.astype(np.int16)).mean()))
  if name=='stance_breath_three_quarter_1x' and f in [1,45,74,86,111,129,189,207]:
   i=[1,45,74,86,111,129,189,207].index(f);tile=Image.fromarray(cv2.cvtColor(img,cv2.COLOR_BGR2RGB));tile.thumbnail((320,320));sheet.paste(tile,((i%4)*320,20+(i//4)*330));draw.text(((i%4)*320+8,(i//4)*330+4),f'Decoded frame {f}',fill='white')
 cap.release();assert f==declared==480 and abs(fps-30)<1e-6 and max(errors)<5
 report[name]={'frames':f,'fps':fps,'duration_s':f/fps,'complete_loops':2,'maximum_mean_pixel_error':max(errors),'sha256':sha(p)}
sheet.save(OUT/'checkpoint_motion_samples.jpg',quality=94)
(OUT/'checkpoint_media_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
