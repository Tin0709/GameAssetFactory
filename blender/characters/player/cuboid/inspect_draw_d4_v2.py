import json,numpy as np
from pathlib import Path
BASE=Path(__file__).parent
d=json.loads((BASE/'draw_d4_v2_samples.json').read_text())
triangles=[np.array(m['vertices'])[np.array(m['triangles'])] for m in d['geometry']]
def intersects(tris,lo,hi):
 center=(lo+hi)/2;extent=(hi-lo)/2;v=tris-center
 e=np.roll(v,-1,axis=1)-v
 axes=np.concatenate([np.broadcast_to(np.eye(3),(len(v),3,3)),np.cross(e[:,0],e[:,1])[:,None,:],np.cross(e[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)],axis=1)
 p=np.einsum('ntd,nad->nta',v,axes);r=np.abs(axes)@extent
 return ~((p.min(1)>r+1e-8)|(p.max(1)<-r-1e-8)).any(1)
cases={}
for s in d['samples']:
 c=cases.setdefault(f"{s['layer']}_{s['phase']}",{'head_chest_hits':[],'arm_samples':0})
 counts={}
 for n,b in d['boxes'].items():
  margin=.01 if n=='Head' else .035 if n=='Chest' else .025
  lo=np.array(b['min'])+margin;hi=np.array(b['max'])-margin
  if n.startswith('Arm.'):hi[1]-=.20 # Exclude intended terminal grip/catch region.
  inv=np.linalg.inv(s['body'][n]);hits=0
  for tris,world in zip(triangles,s['meshes']):
   t=inv@np.array(world);hits+=int(intersects(tris@t[:3,:3].T+t[:3,3],lo,hi).sum())
  counts[n]=hits
 if counts['Head'] or counts['Chest']:c['head_chest_hits'].append({'frame':s['frame'],'Head':counts['Head'],'Chest':counts['Chest']})
 if counts['Arm.L'] or counts['Arm.R']:c['arm_samples']+=1
report={'cases':cases,'samples':len(d['samples']),'lower_keys':d['lower_keys'],'lower_overlay_error':d['lower_overlay_error'],'passed':all(not c['head_chest_hits'] for c in cases.values())}
(BASE/'draw_d4_v2_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))

