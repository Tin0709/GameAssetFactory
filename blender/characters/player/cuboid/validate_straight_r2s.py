import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'straight_study_r2s_review'
p=json.loads((OUT/'preservation_before.json').read_text());check_preserved(p)
s=bpy.data.scenes['R2S_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_StraightV2_Author_Rig'];pts=mesh_points(bpy.data.objects['R2_StraightV2_Author_Mesh'])
src=(BASE/'validate_turning_r2.py').read_text();exec(src[src.index('def box('):src.index('report=')])
report={'preserved_actions':len(p['actions']),'preserved_geometry_weights_rest_hierarchy_files':True,'gaits':{}}
for gait,period in PERIOD.items():
 for ver in ['V1','V2']:
  a=bpy.data.actions[gait+'_ReferenceStudy_'+ver];floor=[];heads=[];hips=[];angles=[];hits=[];root=0.;rigidity=0.;channels=[]
  for i in range(period*16+1):
   f=1+i/16;ps=sample(r,s,a,f);floor.append(floor_min(r,pts));heads.append(r.pose.bones['Head'].matrix.translation.z);hips.append(r.pose.bones['Hips'].matrix.translation.z)
   angles.append(math.degrees((r.pose.bones['Head'].matrix.to_quaternion()@r.data.bones['Head'].matrix_local.to_quaternion().inverted()).angle))
   root=max(root,max(abs(r.pose.bones['Root'].matrix_basis[x][y]-(x==y)) for x in range(4) for y in range(4)))
   channels.append([list(ps[n][0])+list(ps[n][1]) for n in BODY])
   for n in pts:
    q=transformed(r,pts,n);rigidity=max(rigidity,float(np.max(np.abs(np.linalg.norm(q[:,None]-q[None,:],axis=2)-np.linalg.norm(pts[n][:,None]-pts[n][None,:],axis=2)))))
   for aa,bb in pairs:
    if overlap(aa,bb):hits.append({'frame':f,'pair':[aa,bb]})
  slopes=[]
  for c in curves(a):
   k,j=c.keyframe_points[0],c.keyframe_points[-1];slopes.append(abs((k.handle_right.y-k.co.y)/(k.handle_right.x-k.co.x)-(j.co.y-j.handle_left.y)/(j.co.x-j.handle_left.x)))
  report['gaits'][gait+ver]={'samples':len(floor),'seconds':period/24,'floor_min_max_m':[min(floor),max(floor)],'head_bob_m':max(heads)-min(heads),'hips_bob_m':max(hips)-min(hips),'head_angle_deg':[min(angles),max(angles)],'root_error':root,'rigid_corner_distance_error_m':rigidity,'endpoint_error':max(abs(c.evaluate(1)-c.evaluate(period+1)) for c in curves(a)),'seam_slope_error':max(slopes),'scale_tracks':sum(c.data_path.endswith('scale') for c in curves(a)),'weapon_tracks':sum('WeaponCarrier' in c.data_path for c in curves(a)),'inset_hits':hits,'channel_ranges':{n:np.ptp(np.array(channels)[:,j,:],axis=0).tolist() for j,n in enumerate(BODY)}}
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
for n,v in report['gaits'].items():
 print(n,json.dumps({k:x for k,x in v.items() if k not in ['channel_ranges','inset_hits']}),'hits',len(v['inset_hits']),v['inset_hits'][:4],flush=True)
 assert v['floor_min_max_m'][0]>-.001 and v['root_error']<1e-6 and v['endpoint_error']<1e-6 and v['seam_slope_error']<1e-4 and not v['inset_hits'] and not v['scale_tracks'] and not v['weapon_tracks']
print('R2S_VALIDATED',flush=True)
