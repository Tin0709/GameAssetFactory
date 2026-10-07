"""Preservation, binding, rigid FK invariants and bounded contact evidence."""
import bpy,sys,json,math,hashlib
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3];OUT=BASE/'arm_r8a1_review';sys.path.insert(0,str(BASE))
from turning_r2_common import digest,geometry,bone_signature,curves
p=json.loads((OUT/'preservation.json').read_text())
for n,h in p['files'].items():assert hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==h,n
for n,h in p['actions'].items():assert digest(bpy.data.actions[n])==h,n
geo=geometry()
for n,h in p['geometry'].items():assert geo[n]==h,n
for n,sig in p['rigs'].items():assert json.dumps(bone_signature(bpy.data.objects[n]))==json.dumps(sig),n
newnames={'LongGunHold_RigV2_Study_V1','LongGunAimBias_RigV2_Study_V1'};assert set(bpy.data.actions.keys())-set(p['actions'])==newnames
s=bpy.data.scenes['R8A1_AUTHORING'];bpy.context.window.scene=s;r=bpy.data.objects['R8A1_RigV2_Author'];mesh=bpy.data.objects['R8A1_RigV2_Mesh'];src=bpy.data.objects['Player_Cuboid_Base'];orig=bpy.data.objects['Player_Cuboid_Rig']
weapon=next(o for o in s.objects if o.type=='MESH' and 'M4A1_Blocky_Base' in o.name)
assert len(r.data.bones)==len(orig.data.bones)+2
signature=bone_signature(r);original=bone_signature(orig)
for n in set(original)-{'Arm.L','Arm.R'}:assert signature[n]==original[n],n
for side in ['L','R']:
 u=r.data.bones['UpperArm.'+side];f=r.data.bones['ForeArm.'+side]
 assert f.parent==u and f.use_connect and (u.tail_local-f.head_local).length<1e-6
 assert abs(u.length+f.length-orig.data.bones['Arm.'+side].length)<1e-6
assert not any(pb.constraints for pb in r.pose.bones)
assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in mesh.data.vertices)
assert not any(p.use_smooth for p in mesh.data.polygons)
def nonarm(m):
 data=[]
 for v in m.data.vertices:
  g=m.vertex_groups[v.groups[0].group].name
  if 'Arm' not in g:data.append((g,tuple(v.co)))
 return sorted(data)
assert nonarm(mesh)==nonarm(src)
def surface(m):
 data=[]
 for poly in m.data.polygons:
  if any('Arm' in m.vertex_groups[m.data.vertices[i].groups[0].group].name for i in poly.vertices):continue
  data.append((poly.material_index,[(tuple(m.data.vertices[m.data.loops[li].vertex_index].co),[tuple(u.data[li].uv) for u in m.data.uv_layers]) for li in poly.loop_indices]))
 return data
assert surface(mesh)==surface(src)
boxes={}
for g in mesh.vertex_groups:
 inv=r.data.bones[g.name].matrix_local.inverted();pts=np.array([tuple(inv@v.co) for v in mesh.data.vertices if v.groups[0].group==g.index])
 boxes[g.name]=(pts.min(0)+.005,pts.max(0)-.005)
weapon.data.calc_loop_triangles();triangles=np.array([tuple(v.co) for v in weapon.data.vertices])[np.array([tuple(t.vertices) for t in weapon.data.loop_triangles])]
def collision(name):
 lo,hi=boxes[name];center=(lo+hi)/2;extent=(hi-lo)/2;t=np.array(r.pose.bones[name].matrix.inverted()@weapon.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world)
 v=triangles@t[:3,:3].T+t[:3,3]-center;e=np.roll(v,-1,axis=1)-v
 axes=np.concatenate([np.broadcast_to(np.eye(3),(len(v),3,3)),np.cross(e[:,0],e[:,1])[:,None,:],np.cross(e[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)],axis=1)
 proj=np.einsum('ntd,nad->nta',v,axes);reach=np.abs(axes)@extent
 hits=int((~((proj.min(1)>reach+1e-8)|(proj.max(1)<-reach-1e-8)).any(1)).sum());depth=float(max(0,np.min(extent-np.abs(v),axis=2).max()))
 return {'weapon_triangle_hits_inset_5mm':hits,'max_vertex_penetration_m':depth}
def sample(name,f):
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 for pb in r.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
report={'preservation_passed':True,'protected_files':len(p['files']),'protected_actions':len(p['actions']),'new_actions':sorted(newnames),'bone_count':len(r.data.bones),'rigid_weighting_passed':True,'non_arm_geometry_uvs_preserved':True,'poses':{},'actions':{},'contact_note':'Weapon triangles vs 5mm inset rigid boxes; vertex depth is a lower bound, not exact volumetric penetration. Fingerless hand contact is intentional. Does not test every possible body pair.'}
for name in sorted(newnames):
 sample(name,1);start={pb.name:pb.matrix_basis.copy() for pb in r.pose.bones};head=r.pose.bones['Head'].matrix.copy();lower=scale=loc=0;headangle=0
 for i in range(193):
  sample(name,1+i/4)
  headangle=max(headangle,math.degrees(head.to_quaternion().rotation_difference(r.pose.bones['Head'].matrix.to_quaternion()).angle))
  for n in ['Root','Hips','Leg.L','Leg.R']:lower=max(lower,max(abs(r.pose.bones[n].matrix_basis[j][k]-(j==k)) for j in range(4) for k in range(4)))
  for pb in r.pose.bones:
   scale=max(scale,(pb.scale-Vector((1,1,1))).length)
   if 'Arm' in pb.name:loc=max(loc,pb.location.length)
 sample(name,49);seam=max(abs(start[pb.name][j][k]-pb.matrix_basis[j][k]) for pb in r.pose.bones for j in range(4) for k in range(4))
 assert lower<1e-6 and scale<1e-5 and loc<1e-5 and seam<1e-6,(lower,scale,loc,seam)
 assert not any(c.data_path.endswith('scale') for c in curves(bpy.data.actions[name]))
 report['actions'][name]={'lower_body_error':lower,'scale_error':scale,'arm_translation_error':loc,'loop_seam_error':seam,'peak_world_head_delta_deg':headangle}
 for f in ([1] if 'Hold' in name else [1,7,15,20,23,31,43,49]):
  sample(name,f);wm=weapon.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
  targets={'R':wm@Vector((0,0,0)),'L':wm@Vector((0,.25,.02))}
  hands={side:(r.pose.bones['ForeArm.'+side].matrix@Vector((0,.2625,0))-target).length for side,target in targets.items()}
  report['poses'][name+'_'+str(f)]={'hand_center_target_errors_m':hands,'contact':{n:collision(n) for n in ['Head','Chest','UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R']},'stock_butt_center':list(wm@Vector((0,-.312,.145)))}
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True)
