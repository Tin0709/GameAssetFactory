import cv2,json,re
import numpy as np
from pathlib import Path
OUT=Path(__file__).resolve().parent/'straight_study_r2s_review';report={}
for job in json.loads((OUT/'video_manifest.json').read_text()):
 cap=cv2.VideoCapture(str(OUT/(job['stem']+'.mp4')));fps=cap.get(cv2.CAP_PROP_FPS);codec=int(cap.get(cv2.CAP_PROP_FOURCC));fs=[]
 while True:
  ok,f=cap.read()
  if not ok:break
  fs.append(f)
 cap.release();assert len(fs)==job['frames'] and fps==24 and list(fs[0].shape[1::-1])==job['size']
 errors=[]
 for i in [0,len(fs)//2,len(fs)-1]:
  raw=cv2.imread(str(OUT/job['folder']/('%04d.png'%(i+1))));errors.append(float(np.abs(raw.astype(float)-fs[i].astype(float)).mean()))
 assert max(errors)<5 and np.abs(fs[0].astype(float)-fs[3].astype(float)).mean()>.005
 report[job['stem']]={'decoded_frames':len(fs),'fps':fps,'codec':''.join(chr((codec>>(8*i))&255) for i in range(4)),'size':job['size'],'sampled_encode_mae':errors}
page=(OUT/'index.html').read_text(encoding='utf-8')
for link in re.findall(r'(?:src|href)="([^"]+)"',page):assert (OUT/link).exists(),link
(OUT/'video_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));print('R2S_MEDIA_VALIDATED',flush=True)
