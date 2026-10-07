"""Preservation, continuous playback, contact and lower-body transfer evidence."""
import bpy,sys,json,hashlib,math
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector,Euler
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3];OUT=BASE/'living_r9w1_review';sys.path.insert(0,str(BASE))
from turning_r2_common import curves,digest,geometry,bone_signature
p=json.loads((OUT/'preservation.json').read_text());design=json.loads((OUT/'design.json').read_text())
for n,h in p['files'].items():assert hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==h,n
for n,h in p['actions'].items():assert digest(bpy.data.actions[n])==h,n
geo=geometry()
for n,h in p['geometry'].items():assert geo[n]==h,n
for n,h in p['rigs'].items():assert json.dumps(bone_signature(bpy.data.objects[n]))==json.dumps(h),n
r=bpy.data.objects['R9W1_Author_Rig'];mesh=bpy.data.objects['R9W1_Author_Mesh'];s=bpy.data.scenes['R9W1_AUTHORING'];bpy.context.window.scene=s
weapon=next(o for o in s.objects if o.type=='MESH' and 'M4A1_Blocky_Base' in o.name)
assert bone_signature(r)==bone_signature(bpy.data.objects['R8A1_RigV2_Author'])
assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in mesh.data.vertices)
assert not any(pb.constraints for pb in r.pose.bones)
assert digest(bpy.data.actions[design['source_walk']])==design['source_walk_digest']
boxes={}
for g in mesh.vertex_groups:
 inv=r.data.bones[g.name].matrix_local.inverted();pts=np.array([tuple(inv@v.co) for v in mesh.data.vertices if v.groups[0].group==g.index]);boxes[g.name]=(pts.min(0)+.005,pts.max(0)-.005)
weapon.data.calc_loop_triangles();triangles=np.array([tuple(v.co) for v in weapon.data.vertices])[np.array([tuple(t.vertices) for t in weapon.data.loop_triangles])]
def contact(n,wm):
 lo,hi=boxes[n];center=(lo+hi)/2;extent=(hi-lo)/2;t=np.array(r.pose.bones[n].matrix.inverted()@wm);v=triangles@t[:3,:3].T+t[:3,3]-center;e=np.roll(v,-1,axis=1)-v
 axes=np.concatenate([np.broadcast_to(np.eye(3),(len(v),3,3)),np.cross(e[:,0],e[:,1])[:,None,:],np.cross(e[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)],axis=1)
 proj=np.einsum('ntd,nad->nta',v,axes);reach=np.abs(axes)@extent
 return {'triangles':int((~((proj.min(1)>reach+1e-8)|(proj.max(1)<-reach-1e-8)).any(1)).sum()),'vertex_depth_m':float(max(0,np.min(extent-np.abs(v),axis=2).max()))}
wc=curves(bpy.data.actions[design['source_walk']])
def walk(n,f):
 loc=Vector((0,0,0));rot=Euler((0,0,0),'XYZ')
 for c in wc:
  if c.data_path==f'pose.bones["{n}"].location':loc[c.array_index]=c.evaluate(f)
  elif c.data_path==f'pose.bones["{n}"].rotation_euler':rot[c.array_index]=c.evaluate(f)
 return Matrix.LocRotScale(loc,rot.to_quaternion(),Vector((1,1,1)))
def err(a,b):return max(abs(a[j][k]-b[j][k]) for j in range(4) for k in range(4))
def sample(f):
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
report={'preservation_passed':True,'protected_files':len(p['files']),'protected_actions':len(p['actions']),'rig_unchanged':True,'actions':{},'contact_note':'Sampled weapon triangles against 5mm inset rigid boxes; vertex depth is a lower bound, not exact volume. Not all-pairs collision testing.'}
for name,d in design['actions'].items():
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];N=d['period'];sample(1)
 start={pb.name:pb.matrix_basis.copy() for pb in r.pose.bones};maxcontact={n:{'triangles':0,'vertex_depth_m':0} for n in ['Head','Chest','UpperArm.L','UpperArm.R','ForeArm.L','ForeArm.R']}
 grip=support=scale=translation=lower=0;step=0;last=None;motions={n:[] for n in ['Chest','Head','UpperArm.R','ForeArm.R','UpperArm.L','ForeArm.L']};trajectory=[];rows=[]
 for half in range(2*N+1):
  f=1+half/2;sample(f);wm=weapon.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
  handR=r.pose.bones['ForeArm.R'].matrix@Vector((0,.2625,0));handL=r.pose.bones['ForeArm.L'].matrix@Vector((0,.2625,0))
  grip=max(grip,(handR-wm@Vector((0,0,0))).length)
  local=wm.inverted()@handL;lo=max(0,min(N,int(f-1)));hi=min(N,lo+1);frac=f-1-lo
  expected=Vector(d['records'][lo]['support_local']).lerp(Vector(d['records'][hi]['support_local']),frac)
  support=max(support,(local-expected).length)
  for pb in r.pose.bones:
   scale=max(scale,(pb.scale-Vector((1,1,1))).length)
   if 'Arm' in pb.name:translation=max(translation,pb.location.length)
  if half%2==0 and d['mode']!='Ready':
   for n in ['Hips','Leg.L','Leg.R']:lower=max(lower,err(r.pose.bones[n].matrix_basis,walk(n,1+((f-1)%16))))
  current={pb.name:pb.matrix.to_quaternion() for pb in r.pose.bones}
  if last:step=max(step,max(math.degrees(2*math.acos(min(1,abs(q.normalized().dot(last[n].normalized()))))) for n,q in current.items()))
  last=current
  for n in ['Head','Chest']:
   c=contact(n,wm)
   for k,v in c.items():maxcontact[n][k]=max(maxcontact[n][k],v)
  if half%2==0:
   for n in motions:motions[n].append(list(r.pose.bones[n].rotation_quaternion))
   trajectory.append(list(r.pose.bones['Root'].head))
  if half%12==0:
   for n in maxcontact:
    c=contact(n,wm)
    for k,v in c.items():maxcontact[n][k]=max(maxcontact[n][k],v)
   rows.append({'frame':f,'grip_error_m':(handR-wm@Vector((0,0,0))).length,'support_weapon_local':list(local)})
 sample(N+1);seam=max(err(start[pb.name],pb.matrix_basis) for pb in r.pose.bones)
 assert grip<.003 and support<.003,(name,grip,support)
 assert scale<1e-5 and translation<1e-5 and lower<2e-5 and seam<1e-5,(name,scale,translation,lower,seam)
 assert maxcontact['Head']['triangles']==0 and maxcontact['Chest']['triangles']==0,(name,maxcontact)
 # Absolute quaternion signs may differ at a 360-degree crossing; compare orientation matrices.
 ranges={}
 from mathutils import Quaternion
 for n,qs in motions.items():
  q0=Quaternion(qs[0]);ranges[n]=max(math.degrees(2*math.acos(min(1,abs(q0.normalized().dot(Quaternion(q).normalized()))))) for q in qs)
 report['actions'][name]={'period':N,'half_frame_grip_error_m':grip,'half_frame_support_error_weapon_local_m':support,'scale_error':scale,'arm_translation_error':translation,'source_lower_body_keyframe_error':lower,'loop_matrix_error':seam,'max_half_frame_bone_rotation_deg':step,'local_rotation_range_from_start_deg':ranges,'max_sampled_contact':maxcontact,'contact_samples':rows,'root_positions':trajectory}
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps({**{k:v for k,v in report.items() if k!='actions'},'actions':{n:{k:v for k,v in d.items() if k not in ['contact_samples','root_positions']} for n,d in report['actions'].items()}},indent=2),flush=True)
