"""Validate the existing preview system, including matched-sample slide deltas."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'turning_study_r3_review';protected=json.loads((OUT/'preservation_before.json').read_text());check_preserved(protected)
src=(BASE/'validate_turning_r2.py').read_text();exec(src[src.index('def box('):src.index('report=')])
src=(BASE/'build_turning_r2_preview.py').read_text();exec(src[src.index('CASES='):src.index("metadata={'fps'")].replace('ReferenceStudy_V1','ReferenceStudy_V2').replace('_Reference_V1','_Reference_V2'))
meta=json.loads((OUT/'preview_metadata.json').read_text());report={'cases':{},'circles':[],'phase_entries':[],'matched_sliding':{}};allfeet={}
for gait,period in PERIOD.items():
 rows=meta['gaits'][gait]['rows'];sa=bpy.data.scenes['R3_'+gait+'_A'];sb=bpy.data.scenes['R3_'+gait+'_B'];ra=bpy.data.objects['R3_'+gait+'_A_Rig'];rb=bpy.data.objects['R3_'+gait+'_B_Rig']
 assert sa.camera.matrix_world==sb.camera.matrix_world and sa.camera.data.ortho_scale==sb.camera.data.ortho_scale and ra.parent.animation_data.action==rb.parent.animation_data.action
 for label,sign in [('CCW circle',1),('CW circle',-1)]:
  rs=[x for x in rows if x['case']==label];assert all(x['signed_weight']*sign>=0 for x in rs);span=rs[-1]['yaw']-rs[0]['yaw'];assert abs(abs(span)-2*math.pi)<1e-5
  sustained=[x for x in rs if 1<=x['case_time']<=3.5];assert all(abs(x['signed_weight'])>.999 for x in sustained)
  report['circles'].append({'gait':gait,'case':label,'yaw_degrees':math.degrees(span),'steady_turn_strides':2.5*24/period,'consistent_local_sign':True,'never_returns_to_straight_during_steady_curve':True})
 for variant in ['A','B']:
  s=bpy.data.scenes['R3_'+gait+'_'+variant];bpy.context.window.scene=s;r=bpy.data.objects['R3_'+gait+'_'+variant+'_Rig'];pts=mesh_points(bpy.data.objects['R3_'+gait+'_'+variant+'_Mesh']);low=1.;hits=[];err=0.;feet={};rooterr=0.
  for i in range(1821):
   f=1+i/4;k=int(f)-1;u=f-int(f)
   if u and k+1<len(rows) and rows[k]['case']!=rows[k+1]['case']:continue
   s.frame_set(int(f),subframe=u);bpy.context.view_layer.update();low=min(low,floor_min(r,pts))
   for aa,bb in pairs:
    if overlap(aa,bb):hits.append({'f':f,'pair':[aa,bb]})
   rooterr=max(rooterr,max(abs(r.pose.bones['Root'].matrix_basis[x][y]-(x==y)) for x in range(4) for y in range(4)))
   w=rate(rows[k]['case'],rows[k]['case_time']+u/24)/MAX_RATE if variant=='B' else 0
   expected=fullpose(gait,(f-1)/24,w)
   for n in BODY:
    p=r.pose.bones[n];err=max(err,(p.location-expected[n][0]).length,max(abs(p.rotation_euler[j]-expected[n][1][j]) for j in range(3)))
   for n in ['Leg.L','Leg.R']:
    point=Vector(((.1125 if n=='Leg.L' else -.1125),0,0));world=r.matrix_world@r.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted()@point
    feet[(i,n)]={'case':rows[k]['case'],'case_time':rows[k]['case_time']+u/24,'height':float(transformed(r,pts,n)[:,2].min()),'world':world}
  # Explicit half-steps between the quarter-frame baked preview keys.
  for j in range(1820):
   f=1.125+j/4;k=int(f)-1
   if k+1<len(rows) and rows[k]['case']!=rows[k+1]['case']:continue
   s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();low=min(low,floor_min(r,pts))
   for aa,bb in pairs:
    if overlap(aa,bb):hits.append({'f':f,'pair':[aa,bb]})
  allfeet[(gait,variant)]=feet;report['cases'][gait+variant]={'quarter_frame_samples':1821,'additional_between_key_samples':1820,'min_floor_m':low,'inset_hits':hits,'root_error':rooterr,'shared_phase_pose_error':err}
  print(gait,variant,'floor',low,'hits',len(hits),'pose_error',err,flush=True)
 for label in ['All','Left bend','Right bend','S curve','CCW circle','CW circle']:
  aa=allfeet[(gait,'A')];bb=allfeet[(gait,'B')];speeds=[[],[]];delta=[]
  for key,x in aa.items():
   i,n=key;nextkey=(i+1,n)
   if nextkey not in aa or key not in bb or nextkey not in bb:continue
   a2=aa[nextkey];b=bb[key];b2=bb[nextkey]
   if x['case']!=a2['case'] or (label!='All' and x['case']!=label):continue
   if max(x['height'],a2['height'],b['height'],b2['height'])>=.03:continue
   vals=[]
   for j,(v1,v2) in enumerate([(x,a2),(b,b2)]):
    d=v2['world']-v1['world'];v=math.hypot(d.x,d.y)*96;vals.append(v);speeds[j].append(v)
   delta.append(vals[1]-vals[0])
  if delta:report['matched_sliding'][gait+'_'+label]={'matched_intervals':len(delta),'A_median_m_s':float(np.median(speeds[0])),'B_median_m_s':float(np.median(speeds[1])),'A_p95_m_s':float(np.percentile(speeds[0],95)),'B_p95_m_s':float(np.percentile(speeds[1],95)),'B_minus_A_mean_m_s':float(np.mean(delta)),'B_minus_A_abs_p95_m_s':float(np.percentile(np.abs(delta),95))}
 # Entry phase and recovery: evaluate at 240 Hz, no gait clock restart.
 s=bpy.data.scenes['R3_Turn_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_R3_Author_Rig'];pts=mesh_points(bpy.data.objects['R2_R3_Author_Mesh'])
 for sign in [1,-1]:
  for phase in [0,.25,.5,.75]:
   low=1.;hits=[];phaseerr=0.;turnpose=[]
   for i in range(193):
    t=i/240;w=sign*smooth(t/.4)*(1-smooth((t-.4)/.4));ps=fullpose(gait,t,w,phase);apply(r,ps);low=min(low,floor_min(r,pts));phaseerr=max(phaseerr,abs((phase+t*24/period)%1-((t*24+phase*period)%period)/period))
    for a,b in pairs:
     if overlap(a,b):hits.append({'t':t,'pair':[a,b]})
   p0=fullpose(gait,.8,0,phase);p1=fullpose(gait,.8,sign*smooth(2)*(1-smooth(1)),phase)
   returnerr=max(max((p0[n][0]-p1[n][0]).length,max(abs(p0[n][1][j]-p1[n][1][j]) for j in range(3))) for n in BODY)
   report['phase_entries'].append({'gait':gait,'sign':sign,'entry_phase':phase,'phase_error':phaseerr,'min_floor_m':low,'return_all_channels_error':returnerr,'inset_hits':hits})
report['sliding_method']='Same lower-face-center intervals for A/B, both leg bottoms below 3 cm. 96 Hz horizontal world speed; proxy, not proof of planted contact. Hard cuts excluded. Preview speeds 1.4/2.1 m/s, unchanged from R2; no gameplay calibration.'
(OUT/'preview_validation.json').write_text(json.dumps(report,indent=2))
for v in report['cases'].values():assert v['min_floor_m']>-.001 and not v['inset_hits'] and v['root_error']<1e-6 and v['shared_phase_pose_error']<2e-5
for v in report['phase_entries']:assert v['min_floor_m']>-.001 and not v['inset_hits'] and v['phase_error']<1e-10 and v['return_all_channels_error']<1e-6
print('R3_PREVIEW_VALIDATED',flush=True)
