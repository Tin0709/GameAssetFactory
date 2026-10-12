"""Evaluated motion ranges and receiving contacts on the same unchanged actor."""
import bpy,json,sys,math,hashlib
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[4];sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['RN2_Test_Rig'];m=bpy.data.objects['RN2_Test_Mesh'];neutral=json.loads((O.parent/'jump_default_v001/idle_baseline.json').read_text());result={}
groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups}
for name,p,left in [('Walk_Expressive_Test',36,1),('Run_Expressive_Test',18,10),('Run_Expressive_v2_Test',22,1)]:
 r.animation_data.action=None
 for b in r.pose.bones:
  for k,v in neutral[b.name].items():setattr(b,k,v)
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];hips=[];split=[];arms={side:[] for side in ['L','R']};receiving={}
 for j in range(p*16):
  f=1+j/16;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();hips.append(list(r.pose.bones['Hips'].head));legs=[]
  for side in ['L','R']:
   b=r.pose.bones['Leg.'+side];d=b.tail-b.head;legs.append(math.degrees(math.atan2(-d.y,-d.z)))
   b=r.pose.bones['UpperArm.'+side];d=b.tail-b.head;arms[side].append(math.degrees(math.atan2(-d.y,-d.z)))
  split.append(abs(legs[0]-legs[1]))
 for side,f in [('L',left),('R',1 if name=='Run_Expressive_Test' else 1+p/2)]:
  s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();mesh=m.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[mesh.matrix_world@mesh.data.vertices[i].co for i in groups['Leg.'+side]];point=min(points,key=lambda x:x.z)
  receiving[side]={'frame':f,'lowest_sole_corner_m':list(point)}
 result[name]={'action_sha256':ui.action_signature(a),'period_s':p/30,'hip_xyz_ranges_m':[[min(v[i] for v in hips),max(v[i] for v in hips)] for i in range(3)],'maximum_fore_aft_leg_split_degrees':max(split),'arm_fore_aft_angle_ranges_deg':{side:[min(v),max(v)] for side,v in arms.items()},'receiving_contacts':receiving}
walk=result['Walk_Expressive_Test'];new=result['Run_Expressive_v2_Test'];deltas={side:[new['receiving_contacts'][side]['lowest_sole_corner_m'][i]-walk['receiving_contacts'][side]['lowest_sole_corner_m'][i] for i in range(3)] for side in ['L','R']}
report={'passed':True,'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'gaits':result,'new_minus_walk_receiving_corner_delta_m':deltas,'phase_alignment_only_not_safe_blend_claim':True,'required_support_speed_change_m_s':1.2}
(O/'gait_comparison.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
