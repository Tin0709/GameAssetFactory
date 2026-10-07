"""R9-W2 helpers; reuse the established cloning/camera/contact machinery."""
import bpy,sys,math,json,hashlib,ast
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3];OUT=BASE/'living_r9w2_review';OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(BASE))
from turning_r2_common import assign,curves,digest,geometry,bone_signature,camera,periodic
UPPER=['Spine','Chest','Neck','Head','UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']
LOWER=['Root','Hips','Leg.L','Leg.R']
SOURCE=bpy.data.objects['R9W1_Author_Rig'];original=bpy.data.scenes['R9W1_AUTHORING'];source_rig=SOURCE
source_objects=[o for o in original.objects if o.type not in {'CAMERA','LIGHT'}]
# Use the existing copy/remap and scene helpers without rerunning W1 authoring.
tree=ast.parse((BASE/'create_living_r9w1.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['clone','scene']],type_ignores=[]),'<W1 helpers>','exec'))
def clone2(label,s):
 r,mp=clone('W2_'+label,s)
 for o in mp.values():o.name=o.name.replace('R9W1_W2_','R9W2_')
 r.name='R9W2_'+label+'_Rig'
 return r,mp
def gun(s):return next(o for o in s.objects if o.type=='MESH' and 'M4A1_Blocky_Base' in o.name)
def sample(r,s,a,f,local=False,stationary=False):
 assign(r,None)
 for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
 assign(r,a);s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 if local:r.pose.bones['Root'].matrix_basis=Matrix.Identity(4)
 if stationary:
  for n in LOWER:r.pose.bones[n].matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
def apply_pose(r,pose):
 assign(r,None)
 for n,m in pose.items():r.pose.bones[n].matrix_basis=m.copy()
 bpy.context.view_layer.update()
def arm(r,side,target,pole,twist=None):
 up=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];sh=up.head.copy();a=up.length;b=fo.length-.075
 delta=target-sh;d=delta.length;axis=delta.normalized()
 if not abs(a-b)+.001<d<a+b-.001:raise ValueError((side,'reach',d,a+b))
 along=(a*a-b*b+d*d)/(2*d);height=math.sqrt(a*a-along*along);v=pole-sh;v=(v-axis*v.dot(axis)).normalized();el=sh+axis*along+v*height
 for p,head,tail in [(up,sh,el),(fo,el,el+(target-el).normalized()*fo.length)]:
  y=(tail-head).normalized();x=twist.copy() if twist is not None else Vector((1,0,0));x=(x-y*x.dot(y)).normalized();z=x.cross(y).normalized();m=Matrix((x,y,z)).transposed().to_4x4();m.translation=head;p.matrix=m;bpy.context.view_layer.update()
 return el
def save():
 import time
 pending=OUT/('checkpoint_'+str(time.time_ns())+'.blend')
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(pending),check_existing=False,copy=True)
 (OUT/'checkpoint.json').write_text(json.dumps({'path':str(pending)}))
def boxes_for(r,m,inset=0):
 boxes={}
 for g in m.vertex_groups:
  pts=np.array([tuple(r.data.bones[g.name].matrix_local.inverted()@v.co) for v in m.data.vertices if v.groups[0].group==g.index]);boxes[g.name]=(pts.min(0)+inset,pts.max(0)-inset)
 return boxes
def contact(r,w,n,boxes,region=None):
 w.data.calc_loop_triangles();tri=np.array([tuple(v.co) for v in w.data.vertices])[np.array([tuple(t.vertices) for t in w.data.loop_triangles])]
 if region is not None:tri=tri[region(tri.mean(1))]
 wm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world;lo,hi=boxes[n];center=(lo+hi)/2;extent=(hi-lo)/2;t=np.array(r.pose.bones[n].matrix.inverted()@wm);v=tri@t[:3,:3].T+t[:3,3]-center;e=np.roll(v,-1,axis=1)-v
 axes=np.concatenate([np.broadcast_to(np.eye(3),(len(v),3,3)),np.cross(e[:,0],e[:,1])[:,None,:],np.cross(e[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)],axis=1);proj=np.einsum('ntd,nad->nta',v,axes);reach=np.abs(axes)@extent
 return {'triangles':int((~((proj.min(1)>reach+1e-8)|(proj.max(1)<-reach-1e-8)).any(1)).sum()),'depth_m':float(max(0,np.min(extent-np.abs(v),axis=2).max()))}
PATCHES={'L':np.array([(x,y,.122) for x in np.linspace(-.049,.049,11) for y in np.linspace(.284,.479,25)]),'R':np.array([(-.033,y,z) for y in np.linspace(-.02,.01,9) for z in np.linspace(-.05,.085,22)])}
def patch_contact(r,gm,side):
 mat=np.array(r.pose.bones['ForeArm.'+side].matrix.inverted()@gm);ps=PATCHES[side]@mat[:3,:3].T+mat[:3,3];lo=np.array([-.1125,.1875,-.1125]);hi=np.array([.1125,.3375,.1125]);signed=np.maximum(lo-ps,ps-hi).max(1);i=int(signed.argmin());delta=np.maximum(np.maximum(lo-ps,ps-hi),0)
 return {'signed_m':float(signed[i]),'gap_m':float(np.linalg.norm(delta,axis=1).min()),'surface_point':list(map(float,PATCHES[side][i]))}
def corrected(r,gm,poles,gesture=0):
 """Surface-patch fitting; targets are internal control points, NOT contacts."""
 targets={};poles={k:v.copy() for k,v in poles.items()};poles['R']+=Vector((0,.20,0))
 for side in ['R','L']:
  target=Vector((-.14,-.015,.012)) if side=='R' else Vector((-.11,.36,.015))
  pole=poles[side]
  if side=='L' and gesture:
   sh=r.pose.bones['UpperArm.L'].head;axis=(gm@target-sh).normalized();pole=sh+Quaternion(axis,math.radians(gesture))@(pole-sh)
  for _ in range(22):
   arm(r,side,gm@target,pole,gm.to_3x3()@Vector((1,0,0)))
   metric=patch_contact(r,gm,side);error=metric['signed_m']-.0008
   if abs(error)<.00005:break
   if side=='L':target.z+=max(-.015,min(.015,error*1.2))
   else:target.x+=max(-.015,min(.015,error*1.1))
  targets[side]=list(target)
 return targets
