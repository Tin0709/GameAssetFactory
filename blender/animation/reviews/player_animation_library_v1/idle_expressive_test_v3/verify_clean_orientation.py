"""Measured forward foot yaw, asymmetric whole-leg angle and fixed contact check."""
from pathlib import Path
import json,math,hashlib
OUT=Path(__file__).resolve().parent
v=json.loads((OUT/'validation.json').read_text());assert v['passed']
assert hashlib.sha256((OUT/'idle_expressive_v3_review.blend').read_bytes()).hexdigest()==v['sampled_source_sha256']
yaws={'L':[],'R':[]};leans={'L':[],'R':[]}
for frame in v['frames']:
 p=frame['vertices']
 for side,i in [('L',16),('R',24)]:
  edge=[b-a for a,b in zip(p[i],p[i+1])];yaws[side].append(math.degrees(math.atan2(edge[1],edge[0])))
  axis=[b-a for a,b in zip(p[i],p[i+4])];leans[side].append(math.degrees(math.atan2(math.hypot(axis[0],axis[1]),axis[2])))
report={'passed':all(max(abs(x-target) for x in yaws[side])<.1 for side,target in [('L',15),('R',-15)]) and 4.7<min(leans['L'])<=max(leans['L'])<4.9 and 8.8<min(leans['R'])<=max(leans['R'])<8.95 and all(len(ids)>=1 for ids in v['support_contact_vertex_ids'].values()) and v['sole_centers']['L'][1]<-.02 and v['sole_centers']['R'][1]>.02 and .0119<v['body_breathing_rise_m']<.0121,'source_sha256':v['sampled_source_sha256'],'action_sha256':v['sampled_action_sha256'],'measured_foot_yaw_ranges_deg':{s:[min(a),max(a)] for s,a in yaws.items()},'whole_leg_lean_ranges_deg':{s:[min(a),max(a)] for s,a in leans.items()},'forward_stagger_m':abs(v['sole_centers']['L'][1]-v['sole_centers']['R'][1]),'contact':'Both fixed lowest sole corners of rigid angled blocks; no invented ankle or flattened soles.','stable_sole_drift_m':v['max_full_sole_drift_m'],'width_m':v['sole_center_separation_m'],'body_breathing_rise_m':v['body_breathing_rise_m'],'support':'Explicit latest review: mainly sideways L3/R8deg; LEFT slightly forward/RIGHT slightly back, both15deg outward. Breathing amplitude2X:12mm body rise and3.6mm chest lift over unchanged4s. No invented joints.'}
(OUT/'clean_stance_orientation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));assert report['passed']
