import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'turning_study_r3_review';protected=json.loads((OUT/'preservation_before.json').read_text());check_preserved(protected)
s=bpy.data.scenes['R3_Turn_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_R3_Author_Rig'];pts=mesh_points(bpy.data.objects['R2_R3_Author_Mesh'])
src=(BASE/'validate_turning_r2.py').read_text();exec(src[src.index('def box('):src.index('report=')])
report={'preserved_actions':len(protected['actions']),'preserved_geometry_weights_rest_hierarchy_files':True,'loops':{},'blends':{}}
for gait,period in PERIOD.items():
 base=bpy.data.actions[gait+'_ReferenceStudy_V2'];left=bpy.data.actions[gait+'_TurnLeft_Reference_V2'];right=bpy.data.actions[gait+'_TurnRight_Reference_V2']
 for a in [left,right]:
  slopes=[]
  for c in curves(a):
   k,j=c.keyframe_points[0],c.keyframe_points[-1];slopes.append(abs((k.handle_right.y-k.co.y)/(k.handle_right.x-k.co.x)-(j.co.y-j.handle_left.y)/(j.co.x-j.handle_left.x)))
  loop={'seconds':period/24,'endpoint_error':max(abs(c.evaluate(1)-c.evaluate(period+1)) for c in curves(a)),'seam_slope_error':max(slopes),'scale_tracks':sum(c.data_path.endswith('scale') for c in curves(a)),'weapon_tracks':sum('WeaponCarrier' in c.data_path for c in curves(a))}
  report['loops'][a.name]=loop
  assert loop['endpoint_error']<1e-6 and loop['seam_slope_error']<1e-4 and not loop['scale_tracks'] and not loop['weapon_tracks']
 for label,a,b in [('StraightLeft',base,left),('StraightRight',base,right),('LeftRight',left,right)]:
  for w in [.25,.5,.75,1.]:
   lows=[];heads=[];hips=[];hits=[];rooterr=0.;rigiderr=0.;legerr=0.;armerr=0.;armloc=0.;headangles=[]
   for i in range(period*16+1):
    f=1+i/16;pa=sample(r,s,a,f);pb=sample(r,s,b,f);ps=mix(pa,pb,w);baseline=sample(r,s,base,f);apply(r,ps)
    lows.append(floor_min(r,pts));heads.append(r.pose.bones['Head'].matrix.translation.z);hips.append(r.pose.bones['Hips'].matrix.translation.z)
    headangles.append(math.degrees((r.pose.bones['Head'].matrix.to_quaternion()@r.data.bones['Head'].matrix_local.to_quaternion().inverted()).angle))
    for aa,bb in pairs:
     if overlap(aa,bb):hits.append({'frame':f,'pair':[aa,bb]})
    rooterr=max(rooterr,max(abs(r.pose.bones['Root'].matrix_basis[x][y]-(x==y)) for x in range(4) for y in range(4)))
    for n in pts:
     q=transformed(r,pts,n);rigiderr=max(rigiderr,float(np.max(np.abs(np.linalg.norm(q[:,None]-q[None,:],axis=2)-np.linalg.norm(pts[n][:,None]-pts[n][None,:],axis=2)))))
    for n in ['Leg.L','Leg.R']:legerr=max(legerr,(ps[n][0]-baseline[n][0]).length,max(abs(ps[n][1][j]-baseline[n][1][j]) for j in range(3)))
    for n in ['Arm.L','Arm.R']:
     armerr=max(armerr,abs(ps[n][1].x-baseline[n][1].x),abs(ps[n][1].y-baseline[n][1].y));armloc=max(armloc,(ps[n][0]-baseline[n][0]).length)
   entry={'samples':len(lows),'floor_min_max_m':[min(lows),max(lows)],'head_bob_m':max(heads)-min(heads),'hips_bob_m':max(hips)-min(hips),'head_orientation_deg_range':[min(headangles),max(headangles)],'root_error':rooterr,'rigid_corner_distance_error_m':rigiderr,'V2_leg_channels_error':legerr,'V2_arm_pitch_twist_error':armerr,'additional_arm_root_translation_m':armloc,'inset_hits':hits}
   report['blends'][gait+'_'+label+'_'+str(w)]=entry
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
for n,v in report['blends'].items():
 print(n,'floor',min(v['floor_min_max_m']),'hits',len(v['inset_hits']),v['inset_hits'][:3],flush=True)
 # Free Bezier interpolation adds about 10 micrometres above the authored 4 mm.
 assert v['floor_min_max_m'][0]>-.001 and v['root_error']<1e-6 and v['rigid_corner_distance_error_m']<1e-6 and v['V2_leg_channels_error']<1e-5 and v['V2_arm_pitch_twist_error']<1e-4 and v['additional_arm_root_translation_m']<.00402 and not v['inset_hits']
print('R3_VALIDATED',flush=True)
