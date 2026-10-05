import json,math,statistics
from pathlib import Path
p=Path(__file__).parent;data=json.loads((p/'run_cadence_samples.json').read_text());samples=data['samples'];T=data['duration'];dt=T/640
intervals=[];velocities=[]
for bone in ['Leg.R','Leg.L']:
 active=[s['feet'][bone]['minimum_y']<=.012 for s in samples[:-1]]
 starts=[i for i in range(640) if active[i] and not active[(i-1)%640]]
 for start in starts:
  ids=[];i=start
  while active[i%640] and len(ids)<640:ids.append(i);i+=1
  start_time=start*dt;end_time=(ids[-1]+1)*dt
  z0=samples[start]['feet'][bone]['z'];z1=samples[(ids[-1]+1)%640]['feet'][bone]['z'];displacement=z1-z0
  vs=[(samples[(j+1)%640]['feet'][bone]['z']-samples[j%640]['feet'][bone]['z'])/dt for j in ids]
  velocities+=vs
  intervals.append(dict(bone=bone,phase_start=start_time/T,phase_end=end_time/T,frame_start=1+start_time*24,frame_end=1+end_time*24,duration_seconds=end_time-start_time,backward_displacement_m=-displacement,mean_local_forward_velocity_mps=statistics.mean(vs)))
v=statistics.mean(velocities);speed=-v;scale=6.25/speed;ls=-6.25*v/statistics.mean(x*x for x in velocities)
def candidate(s):
 world=[6.25+s*x for x in velocities]
 return dict(scale=s,cycle_seconds=T/s,cycles_per_second=s/T,steps_per_second=2*s/T,mean_world_support_velocity_mps=statistics.mean(world),rms_world_support_velocity_mps=math.sqrt(statistics.mean(x*x for x in world)),mean_abs_world_support_velocity_mps=statistics.mean(abs(x) for x in world),slip_direction='forward' if statistics.mean(world)>.01 else 'backward' if statistics.mean(world)<-.01 else 'mean matched',signed_slip_distance_per_support_m=statistics.mean((6.25+s*i['mean_local_forward_velocity_mps'])*i['duration_seconds']/s for i in intervals),absolute_slip_distance_per_support_m=statistics.mean(abs(x) for x in world)*statistics.mean(i['duration_seconds'] for i in intervals)/s)
report=dict(method='641 samples, bottom-center of each rigid 0.675m leg; +Z forward. Support when the lowest sole corner is <=12mm above root-level floor. Smooth center trajectory avoids discontinuous heel/toe corner switching. Intervals are circular across the loop.',support_threshold_m=.012,contact_intervals=intervals,authored_cycle_seconds=T,implied_speed_at_1x_mps=speed,effective_cycle_travel_m=speed*T,effective_step_length_m=speed*T/2,mean_zero_slip_scale=scale,least_squares_slip_scale=ls,local_support_velocity_range_mps=[min(velocities),max(velocities)],matched_candidates=[candidate(scale*(1+d)) for d in [-.15,-.075,0,.075,.15]],visual_candidates=[candidate(s) for s in [1,1.35,1.5,1.6,1.65,1.8,2]],chosen_visual_scale=1.6,chosen_metrics=candidate(1.6),reason='1.60 is close to the 1.580 RMS optimum and keeps 4.8 steps/s. Mean matching at 1.942 has 5.825 steps/s and more backward/forward oscillatory slip; no scalar multiplier can plant every sample.')
(p/'run_cadence_measurement.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
