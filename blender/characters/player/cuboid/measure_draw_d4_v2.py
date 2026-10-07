import json,numpy as np
from pathlib import Path
BASE=Path(__file__).parent
report={}
for version in [1,2]:
 d=json.loads((BASE/f'draw_d4_v{version}_samples.json').read_text())
 samples=[s for s in d['samples'] if s['layer']=='None']
 f=np.array([s['frame'] for s in samples]);m=np.array([s['meshes'][0] for s in samples])
 speed=np.linalg.norm(np.diff(m[:,:3,3],axis=0),axis=1)*192;mid=(f[1:]+f[:-1])/2
 r=m[:,:3,:3]/1.12
 angular=np.arccos(np.clip((np.einsum('nij,nij->n',r[1:],r[:-1])-1)/2,-1,1))*180/np.pi*192
 bins={}
 for name,lo,hi in [('secured',1,5),('contact_release',5,5.5),('pull',5.5,7.3),('sweep',7.3,10.5),('catch',10.5,11.5),('settle',11.5,14)]:
  mask=(mid>=lo)&(mid<hi)
  bins[name]={'mean_m_s':float(speed[mask].mean()),'peak_m_s':float(speed[mask].max()),'mean_deg_s':float(angular[mask].mean()),'peak_deg_s':float(angular[mask].max())}
 local=[np.linalg.inv(s['body']['Chest'])@np.array(s['meshes'][0]) for s in samples if s['frame']<=5.25]
 secured_error=max(float(np.abs(t-local[0]).max()) for t in local)
 report[f'V{version}']={'velocity_bins':bins,'secured_chest_relative_matrix_error':secured_error}
(BASE/'draw_d4_v2_velocity_comparison.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert report['V2']['secured_chest_relative_matrix_error']<2e-6
