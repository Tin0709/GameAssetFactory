import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3];OUT=BASE/'hold_r7w1_review'
sys.path.insert(0,str(BASE))
from turning_r2_common import curves,digest,geometry,bone_signature
protected=json.loads((OUT/'preservation.json').read_text())
for n,h in protected['actions'].items():assert digest(bpy.data.actions[n])==h,n
geo=geometry()
for n,h in protected['geometry'].items():assert geo[n]==h,n
for n,sig in protected['rigs'].items():assert json.dumps(bone_signature(bpy.data.objects[n]))==json.dumps(sig),n
bad=[n for n,h in protected['files'].items() if hashlib.sha256((ROOT/n).read_bytes()).hexdigest()!=h];assert not bad,bad
s=bpy.data.scenes['R7W1_AUTHORING'];bpy.context.window.scene=s;r=bpy.data.objects['R7W1_Author_Player_Cuboid_Rig'];mesh=bpy.data.objects['R7W1_Author_Player_Cuboid_Base'];weapon=bpy.data.objects['R7W1_Author_M4A1_Blocky_Base']
source=bpy.data.objects['Player_Cuboid_Rig']
assert bone_signature(r)==bone_signature(source)
assert not any(p.constraints for p in r.pose.bones)
def sample(name,f):
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
def gap(point,lo,hi):return sum(max(lo[i]-point[i],0,point[i]-hi[i])**2 for i in range(3))**.5
def measure():
 deps=bpy.context.evaluated_depsgraph_get();w=weapon.evaluated_get(deps).matrix_world
 grip=bpy.data.objects['R7W1_Author_Grip_Point'].evaluated_get(deps).matrix_world.translation
 support=bpy.data.objects['R7W1_Author_Support_Hand_Point'].evaluated_get(deps).matrix_world.translation
 stock=w@Vector((0,-.312,.145))
 brace=r.pose.bones['Chest'].matrix@r.data.bones['Chest'].matrix_local.inverted()@Vector((-.225,-.1125,1.30))
 hands={}
 for bone,point in [('Arm.R',grip),('Arm.L',support)]:
  p=r.pose.bones[bone];local=p.matrix.inverted()@point
  hands[bone]={'target_distance_from_shoulder_m':(point-p.head).length,'target_to_terminal_hand_box_gap_m':gap(local,(-.1125,.525,-.1125),(.1125,.675,.1125)),'target_bone_local_xyz':list(local),'bone_length_m':p.length,'shoulder_location_local':list(p.location)}
 return {'grip_world':list(grip),'support_world':list(support),'stock_butt_center_world':list(stock),'upper_chest_brace_patch_world':list(brace),'stock_to_brace_patch_m':(stock-brace).length,'hands':hands,'head_rotation_quaternion':list(r.pose.bones['Head'].matrix.to_quaternion()),'head_origin':list(r.pose.bones['Head'].matrix.translation)}
report={'protected_files':len(protected['files']),'protected_actions':len(protected['actions']),'preservation_passed':True,'poses':{},'new_actions':{},'note':'Grip/fore-end helper-to-terminal-hand-box gaps are geometric proxies, not an artistic score. Stock patch is an explicit approximate upper-chest landmark.'}
for label,name,f in [('A','LongGunHold_V2',1),('B','LongGunHold_ReferenceStudy_V1',1),('C','LongGunAimBias_Study_V1',20)]:
 sample(name,f);report['poses'][label]=measure()
for name in ['LongGunHold_ReferenceStudy_V1','LongGunAimBias_Study_V1']:
 a=bpy.data.actions[name];sample(name,1);start={p.name:p.matrix_basis.copy() for p in r.pose.bones};head=r.pose.bones['Head'].matrix.copy();rot=[];offset=[];rooterr=0;scaleerr=0
 for i in range(193):
  sample(name,1+i/4)
  rot.append(math.degrees(head.to_quaternion().rotation_difference(r.pose.bones['Head'].matrix.to_quaternion()).angle))
  offset.append((r.pose.bones['Head'].matrix.translation-head.translation).length)
  for n in ['Root','Hips','Leg.L','Leg.R']:rooterr=max(rooterr,max(abs(r.pose.bones[n].matrix_basis[j][k]-(j==k)) for j in range(4) for k in range(4)))
  scaleerr=max(scaleerr,max((p.scale-Vector((1,1,1))).length for p in r.pose.bones))
 sample(name,49);seam=max(abs(start[p.name][j][k]-p.matrix_basis[j][k]) for p in r.pose.bones for j in range(4) for k in range(4))
 scale_keys=sum(c.data_path.endswith('scale') for c in curves(a))
 report['new_actions'][name]={'seam_matrix_error':seam,'lower_basis_error':rooterr,'scale_error':scaleerr,'scale_tracks':scale_keys,'head_world_delta_deg_peak':max(rot),'head_origin_offset_m_peak':max(offset),'keys':[1,49],'playback':[1,48],'fps':24}
 assert seam<1e-6 and rooterr<1e-6 and scaleerr<1e-5 and not scale_keys
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
