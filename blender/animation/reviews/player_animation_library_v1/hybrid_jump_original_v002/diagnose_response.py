"""Compare original authored response curves; no scene or game writes."""
import sys,json,math
from pathlib import Path
H=Path(__file__).resolve().parent;sys.path.insert(0,str(H));import motion as m
def measure(module):
 dt=1/10000;end=module.LANDING;ts=[i*dt for i in range(round(end/dt)+1)];poses=[module.landing(t)for t in ts]
 def peak_time(key,minimum=False):return ts[min(range(len(ts)),key=lambda i:poses[i][key])if minimum else max(range(len(ts)),key=lambda i:poses[i][key])]
 speed=max(abs((b['hip']-a['hip'])/dt)for a,b in zip(poses,poses[1:]));accel=max(abs((c['hip']-2*b['hip']+a['hip'])/dt**2)for a,b,c in zip(poses,poses[1:],poses[2:]))
 return {'landing_s':end,'hip_minimum_mm':min(p['hip']for p in poses)*1000,'first_hip_minimum_s':peak_time('hip',True),'torso_maximum_s':peak_time('lean'),'head_maximum_s':peak_time('head'),'head_pitch_max_deg':max(p['head']for p in poses),'head_lag_after_torso_maximum_ms':1000*(peak_time('head')-peak_time('lean')),'hip_speed_max_m_s':speed,'hip_acceleration_max_m_s2':accel,'hip_velocity_at_210ms_m_s':(module.landing(.21001)['hip']-module.landing(.20999)['hip'])/.00002}
out={'v001':measure(m.old),'v002':measure(m),'scope':'Analytical original response curves, not recovered native physics. Actual saved rig measurements are separate. Same presentation arc and original takeoff/airborne in A-B.'}
assert out['v002']['hip_speed_max_m_s']<out['v001']['hip_speed_max_m_s']*.6
assert out['v002']['head_lag_after_torso_maximum_ms']>80
assert out['v002']['hip_velocity_at_210ms_m_s']>.15
(H/'response_comparison.json').write_text(json.dumps(out,indent=2),encoding='utf8');print(json.dumps(out,indent=2))
