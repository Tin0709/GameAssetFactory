"""Preservation, continuous playback, contact and lower-body transfer evidence."""
import bpy,sys,json,hashlib,math
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector,Euler
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3];OUT=BASE/'living_r9w1_review';sys.path.insert(0,str(BASE))
from turning_r2_common import curves,digest,geometry,bone_signature
p=json.loads((OUT/'preservation.json').read_text());design=json.loads((OUT/'design.json').read_text())

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



a=bpy.data.actions['LongGunAimAround_LeftRight_V1'];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];base=Euler(tuple(math.radians(v) for v in (2,27,-2)),'XYZ').to_matrix().to_4x4()
for bias in [2,3,4]:
 worst=0;frames=[]
 for f in range(1,289,3):
  sample(f);rec=design['actions'][a.name]['records'][f-1];drive=rec['drive'];breath=math.sin(2*math.pi*(f-1)/288*3)
  r.pose.bones['Head'].matrix_basis=base@Euler(tuple(math.radians(v) for v in (.65*breath,bias+2.5*drive,-.5*drive)),'XYZ').to_matrix().to_4x4();bpy.context.view_layer.update()
  wm=weapon.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy();hits=contact('Head',wm)['triangles'];worst=max(worst,hits)
  if hits:frames.append(f)
 print('HEAD_BIAS_TEST',bias,worst,frames,flush=True)
