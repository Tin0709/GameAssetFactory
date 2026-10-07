"""Geometric contact evidence; report overlaps without treating zero overlap as art."""
import bpy,json,sys
import numpy as np
from pathlib import Path
from mathutils import Matrix
BASE=Path(__file__).resolve().parent;OUT=BASE/'hold_r7w1_review'
s=bpy.data.scenes['R7W1_AUTHORING'];bpy.context.window.scene=s
r=bpy.data.objects['R7W1_Author_Player_Cuboid_Rig'];mesh=bpy.data.objects['R7W1_Author_Player_Cuboid_Base'];weapon=bpy.data.objects['R7W1_Author_M4A1_Blocky_Base']
weapon.data.calc_loop_triangles();triangles=np.array([tuple(v.co) for v in weapon.data.vertices])[np.array([tuple(t.vertices) for t in weapon.data.loop_triangles])]
boxes={}
for name in ['Head','Chest','Arm.L','Arm.R']:
 g=mesh.vertex_groups[name].index;inv=r.data.bones[name].matrix_local.inverted()
 points=np.array([tuple(inv@v.co) for v in mesh.data.vertices if any(x.group==g and x.weight>.999 for x in v.groups)])
 boxes[name]=(points.min(0)+.005,points.max(0)-.005)
def collision(name):
 lo,hi=boxes[name];center=(lo+hi)/2;extent=(hi-lo)/2
 t=np.array(r.pose.bones[name].matrix.inverted()@weapon.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world)
 v=triangles@t[:3,:3].T+t[:3,3]-center;e=np.roll(v,-1,axis=1)-v
 axes=np.concatenate([np.broadcast_to(np.eye(3),(len(v),3,3)),np.cross(e[:,0],e[:,1])[:,None,:],np.cross(e[:,:,None,:],np.eye(3)[None,None,:,:]).reshape(-1,9,3)],axis=1)
 proj=np.einsum('ntd,nad->nta',v,axes);reach=np.abs(axes)@extent
 hits=int((~((proj.min(1)>reach+1e-8)|(proj.max(1)<-reach-1e-8)).any(1)).sum())
 interior=np.min(extent-np.abs(v),axis=2);depth=float(max(0,interior.max()))
 return {'weapon_triangle_intersections_inset_5mm':hits,'max_weapon_vertex_depth_in_inset_box_m':depth}
report={'note':'Triangle counts depend on weapon topology; depth is a vertex-based lower bound on penetration. Inset boxes omit 5mm skin. Arm/weapon contact can be intentional. Head/eye visibility also requires camera review.','poses':{}}
for label,name,fs in [('A','LongGunHold_V2',[1]),('B','LongGunHold_ReferenceStudy_V1',[1]),('C','LongGunAimBias_Study_V1',[1,7,15,20,23,31,43,49])]:
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 for f in fs:
  for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
  s.frame_set(f);bpy.context.view_layer.update()
  report['poses'][label+'_'+str(f)]={name:collision(name) for name in boxes}
(OUT/'contact_evidence.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
