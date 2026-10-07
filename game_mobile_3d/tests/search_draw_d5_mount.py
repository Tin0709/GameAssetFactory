from pathlib import Path
import json, numpy as np
p=Path('game_mobile_3d/tests/inspect_draw_d5_collisions.py')
s=p.read_text();exec(s[:s.index('weapon_tris=')])
tris=triangles(2);box=boxes['Head'];lo=np.array(box['min'])+.01;hi=np.array(box['max'])-.01
samples=[s for s in data['samples'] if s['weapon']==2 and .18<s['time']<.4]
def smooth(a,b,t):
 u=np.clip((t-a)/(b-a),0,1);return u*u*(3-2*u)
def score(delta):
 hits=[]
 for s in samples:
  inv=np.linalg.inv(s['body']['Head']);off=np.array(s['carrier_world'])[:3,:3]@delta*smooth(22/120,22/120+.08,s['time'])
  n=0
  for ts,m in zip(tris,s['meshes']):
   m=np.array(m);m[:3,3]+=off;t=inv@m;posed=ts@t[:3,:3].T+t[:3,3];n+=int(intersects(posed,lo,hi).sum())
  if n:hits.append((s['case'],s['time'],n))
 return hits
for delta in [[0,0,0],[0,.01,0],[0,.02,0],[0,.03,0],[0,0,.01],[0,0,.02],[.01,0,0],[-.01,0,0]]:
 print(delta,score(np.array(delta,dtype=float)))
