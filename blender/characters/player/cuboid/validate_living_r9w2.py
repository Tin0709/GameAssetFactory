from living_r9w2_common import *
from bpy_extras.object_utils import world_to_camera_view
p=json.loads((OUT/'preservation.json').read_text());d=json.loads((OUT/'design.json').read_text())
for n,v in p['actions'].items():assert digest(bpy.data.actions[n])==v,n
geo=geometry()
for n,v in p['geometry'].items():assert geo[n]==v,n
for n,v in p['rigs'].items():assert json.dumps(bone_signature(bpy.data.objects[n]))==json.dumps(v),n
for a in bpy.data.actions:
 if a.name not in p['actions']:
  assert not any(any('"'+n+'"' in c.data_path for n in LOWER) for c in curves(a)),a.name
s=bpy.data.scenes['R9W2_DIAGNOSIS'];bpy.context.window.scene=s;r=bpy.data.objects['R9W2_Probe_Rig'];w=gun(s);m=next(o for o in s.objects if o.type=='MESH' and 'Author_Mesh' in o.name);boxes=boxes_for(r,m,.005)
assert bone_signature(r)==bone_signature(SOURCE);assert not any(pb.constraints for pb in r.pose.bones)
report={'preserved_actions':len(p['actions']),'preserved_geometry':len(p['geometry']),'new_actions_upper_only':True,'source_rig_unchanged':True,'studies':{},'composition':{}}
def materr(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
def sf(f):s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
for mode,info in d['actions'].items():
 N=info['period']
 for label,an in info['variants'].items():
  a=bpy.data.actions[an];sample(r,s,a,1,False,False);metrics={'max_contact':{},'patch_gap_max_m':{'R':0,'L':0},'patch_penetration_max_m':{'R':0,'L':0},'grip_center_fit_error_m':0,'support_center_fit_error_m':0,'shoulder_shift_m':0,'elbow_gap_m':0,'scale_error':0,'loop_matrix_error':0,'arm_seam_velocity_delta_rad_s':0,'screen_elbow_points':[],'worst_frames':{}}
  start={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER};expected_sh={side:r.data.bones['Chest'].matrix_local.inverted()@r.data.bones['UpperArm.'+side].head_local for side in ['R','L']}
  for step in range(2*N+1):
   f=1+step/2;sf(f);gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
   for side in ['R','L']:
    patch=patch_contact(r,gm,side)
    if patch['gap_m']>metrics['patch_gap_max_m'][side]:metrics['patch_gap_max_m'][side]=patch['gap_m'];metrics['worst_frames']['gap_'+side]=f
    metrics['patch_penetration_max_m'][side]=max(metrics['patch_penetration_max_m'][side],-patch['signed_m'])
    if label!='A':
     i=min(int(f-1),N);j=min(i+1,N);target=Vector(info['records'][label][i]['targets'][side]).lerp(Vector(info['records'][label][j]['targets'][side]),f-1-i);hand=r.pose.bones['ForeArm.'+side].matrix@Vector((0,.2625,0));err=(hand-gm@target).length;key='grip_center_fit_error_m' if side=='R' else 'support_center_fit_error_m';metrics[key]=max(metrics[key],err)
    up=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];metrics['elbow_gap_m']=max(metrics['elbow_gap_m'],(up.tail-fo.head).length);metrics['shoulder_shift_m']=max(metrics['shoulder_shift_m'],(r.pose.bones['Chest'].matrix.inverted()@up.head-expected_sh[side]).length)
   for pb in r.pose.bones:metrics['scale_error']=max(metrics['scale_error'],(pb.scale-Vector((1,1,1))).length)
   for n in ['Head','Chest','UpperArm.R','ForeArm.R','ForeArm.L']:
    c=contact(r,w,n,boxes);prev=metrics['max_contact'].setdefault(n,{'triangles':0,'depth_m':0})
    if c['depth_m']>prev['depth_m']:metrics['worst_frames'][n]=f
    for k,v in c.items():prev[k]=max(prev[k],v)
   if step%2==0:
    pt=world_to_camera_view(s,bpy.data.objects['R9W2_Gameplay'],r.pose.bones['ForeArm.L'].head);metrics['screen_elbow_points'].append([pt.x*960,pt.y*640])
  metrics['loop_matrix_error']=max(materr(start[n],r.pose.bones[n].matrix_basis) for n in UPPER)
  # Quaternion component derivatives are periodic on new arm curves; measure finite differences.
  for n in ['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R']:
   samples=[]
   for f in [1,1.05,N+.95,N+1]:sf(f);samples.append(r.pose.bones[n].rotation_quaternion.copy())
   qa,qb,qc,qd=samples
   for q in [qb,qc,qd]:
    if q.dot(qa)<0:q.negate()
   delta=np.linalg.norm((np.array(qb)-np.array(qa))-(np.array(qd)-np.array(qc)))*2*24/.05;metrics['arm_seam_velocity_delta_rad_s']=max(metrics['arm_seam_velocity_delta_rad_s'],float(delta))
  assert metrics['scale_error']<1e-5 and metrics['elbow_gap_m']<1e-5 and metrics['shoulder_shift_m']<1e-5,(mode,label,metrics)
  assert metrics['loop_matrix_error']<1e-5
  if label!='A':assert metrics['max_contact']['Head']['triangles']==0 and metrics['max_contact']['Chest']['triangles']==0,(mode,label,'head/chest')
  report['studies'][mode+'_'+label]=metrics
# A/B/C NLA lower-body basis must agree with unmodified V1 at the same time.
for mode in ['WALK_LOCAL','FIGURE8','MOVE']:
 info=d['review'][mode];cs=bpy.data.scenes[info['scene']];bpy.context.window.scene=cs;maximum=0;upper_error=0
 src=bpy.data.actions['PREVIEW_ONLY_R9W1_Steering_Local' if mode=='WALK_LOCAL' else 'LongGunAimAround_LeftRight_V1' if mode=='FIGURE8' else 'LongGunReady_Move_V1']
 for f in [1,6.5,49,73,144.5,217,288]:
  if f>cs.frame_end:continue
  cs.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();rs=[bpy.data.objects[info['rigs'][lab]] for lab in ['A','B','C']]
  for n in LOWER:
   loc=Vector((0,0,0));q=Quaternion((1,0,0,0))
   for c in curves(src):
    if c.data_path=='pose.bones["'+n+'"].location':loc[c.array_index]=c.evaluate(f)
    if c.data_path=='pose.bones["'+n+'"].rotation_quaternion':q[c.array_index]=c.evaluate(f)
   expected=Matrix.LocRotScale(loc,q.normalized(),Vector((1,1,1)))
   for rr in rs:maximum=max(maximum,materr(rr.pose.bones[n].matrix_basis,expected))
  for n in ['Spine','Chest','Neck','Head','WeaponCarrier']:
   for rr in rs[1:]:upper_error=max(upper_error,materr(rr.pose.bones[n].matrix_basis,rs[0].pose.bones[n].matrix_basis))
 assert maximum<1e-5 and upper_error<1e-5,(mode,maximum,upper_error)
 report['composition'][mode]={'source_lower_body_error':maximum,'unchanged_upper_and_weapon_error':upper_error}
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
