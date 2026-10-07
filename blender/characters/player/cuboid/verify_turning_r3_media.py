import cv2,json,re
import numpy as np
from urllib.parse import unquote
from pathlib import Path
OUT=Path(__file__).resolve().parent/'turning_study_r3_review';report={}
for job in json.loads((OUT/'video_manifest.json').read_text()):
 cap=cv2.VideoCapture(str(OUT/(job['stem']+'.mp4')));fps=cap.get(cv2.CAP_PROP_FPS);codec=int(cap.get(cv2.CAP_PROP_FOURCC));n=0;errors=[];first=None;motion=0
 while True:
  ok,f=cap.read()
  if not ok:break
  assert list(f.shape[1::-1])==job['size']
  if n==0:first=f.copy()
  if n==3:motion=float(np.abs(first.astype(float)-f.astype(float)).mean())
  if n in [0,job['frames']//2,job['frames']-1]:
   raw=cv2.imread(str(OUT/job['folder']/('%04d.png'%(n+1))));errors.append(float(np.abs(raw.astype(float)-f.astype(float)).mean()))
  n+=1
 cap.release();assert n==job['frames'] and fps==24 and max(errors)<5 and motion>.005
 report[job['stem']]={'frames':n,'fps':fps,'codec':''.join(chr((codec>>(8*i))&255) for i in range(4)),'size':job['size'],'sampled_encode_mae':errors,'motion_difference':motion}
page=(OUT/'index.html').read_text(encoding='utf-8')
for link in re.findall(r'(?:src|href)="([^"]+)"',page):assert (OUT/unquote(link)).exists(),link
(OUT/'video_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));print('R3_MEDIA_VALIDATED',flush=True)
