import numpy as np
from pathlib import Path
code=(Path(__file__).parent/'inspect_holster_d2_collisions.py').read_text()
exec(code.split('weapon_tris=')[0])
tris_list=triangles(2)
samples=[s for s in data['samples'] if s['case']=='2_-1_0']
for offset in [.025,.05,.075,.10,.125,.15]:
 hits={'Head':0,'Chest':0};late={'Head':0,'Chest':0}
 for s in samples:
  u=min(1,s['time']/.10);weight=u*u*(3-2*u)
  delta=(np.array(s['weapon_world'])[:3,1]*.025-np.array(s['weapon_world'])[:3,2]*offset)/1.14*weight
  for name,box in boxes.items():
   inv=np.linalg.inv(s['body'][name]);margin=.01 if name=='Head' else .035;lo=np.array(box['min'])+margin;hi=np.array(box['max'])-margin
   for tris,mat in zip(tris_list,s['meshes']):
    world=np.array(mat);world[:3,3]+=delta;t=inv@world;posed=tris@t[:3,:3].T+t[:3,3]
    count=int(intersects(posed,lo,hi).sum());hits[name]+=count
    if s['time']>.1:late[name]+=count
 print(offset,hits,'after .10',late)

