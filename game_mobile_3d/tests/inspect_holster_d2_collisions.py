"""Offline triangle/box SAT for actual Godot-composed Idle/Run poses."""
import json
from pathlib import Path
import numpy as np
BASE=Path(__file__).parent
data=json.loads((BASE/'holster_d2_collision_samples.json').read_text())
boxes=json.loads((BASE/'holster_d2_body_boxes.json').read_text())
def triangles(weapon):
 out=[]
 for mesh in data['meshes'][str(weapon)]:
  all_tris=[]
  for s in mesh:
   vertices=np.array(s['vertices']);inds=np.array(s['indices'],dtype=int)
   if not len(inds):inds=np.arange(len(vertices))
   all_tris.append(vertices[inds.reshape(-1,3)])
  out.append(np.concatenate(all_tris))
 return out
def intersects(tris,lo,hi):
 center=(hi+lo)/2;extent=(hi-lo)/2;v=tris-center
 edges=np.roll(v,-1,axis=1)-v
 box_axes=np.broadcast_to(np.eye(3),(len(v),3,3))
 normals=np.cross(edges[:,0],edges[:,1])[:,None,:]
 crosses=np.cross(edges[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)
 axes=np.concatenate([box_axes,normals,crosses],axis=1)
 projections=np.einsum('ntd,nad->nta',v,axes);r=np.abs(axes)@extent
 separating=(projections.min(axis=1)>r+1e-8)|(projections.max(axis=1)<-r-1e-8)
 return np.logical_not(separating.any(axis=1))
weapon_tris={w:triangles(w) for w in [1,2]};cases={}
for s in data['samples']:
 item=cases.setdefault(s['case'],{'samples':0,'head_hits':[],'deep_chest_hits':[]});item['samples']+=1
 for name,box in boxes.items():
  inv=np.linalg.inv(s['body'][name]);margin=.01 if name=='Head' else .035
  lo=np.array(box['min'])+margin;hi=np.array(box['max'])-margin;hits=0
  for tris,mat in zip(weapon_tris[s['weapon']],s['meshes']):
   t=inv@np.array(mat);posed=tris@t[:3,:3].T+t[:3,3];hits+=int(intersects(posed,lo,hi).sum())
  if hits:item['head_hits' if name=='Head' else 'deep_chest_hits'].append({'time':s['time'],'triangles':hits})
report={'cases':cases,'samples':len(data['samples']),'passed':all(not c['head_hits'] and not c['deep_chest_hits'] for c in cases.values()),'method':'Actual weapon triangles vs rigid head/chest boxes, SAT; head inset 1cm, chest inset 3.5cm'}
(BASE/'holster_d2_collision_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
