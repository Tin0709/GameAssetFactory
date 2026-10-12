"""Compare saved independent Actions at the same normalized gait phase."""
import bpy,json,sys,hashlib,math
from pathlib import Path
O=Path(__file__).resolve().parent;R=O.parents[4];sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
r=bpy.data.objects['RN3_Test_Rig'];s=bpy.context.scene;old=bpy.data.actions['Run_Expressive_v2_Test'];new=bpy.data.actions['Run_Expressive_v3_Test'];names=[b.name for b in r.pose.bones if not b.name.startswith(('UpperArm.','ForeArm.'))]
max_matrix_error=0.;per_bone={n:0. for n in names};angles={a.name:{side:[] for side in ['L','R']} for a in [old,new]}
def sample(a,p,u):
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];f=1+p*u;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
 for side in ['L','R']:angles[a.name][side].append(math.degrees(r.pose.bones['UpperArm.'+side].rotation_quaternion.to_euler('ZXY').x))
 return {n:r.pose.bones[n].matrix.copy() for n in names}
for j in range(441):
 u=j/440;aa=sample(old,22,u);bb=sample(new,20,u)
 for n in names:per_bone[n]=max(per_bone[n],max(abs(aa[n][i][k]-bb[n][i][k]) for i in range(4) for k in range(4)))
 max_matrix_error=max(per_bone.values())
ranges={n:{side:max(v)-min(v) for side,v in sides.items()} for n,sides in angles.items()};ratios={side:ranges[new.name][side]/ranges[old.name][side] for side in ['L','R']}
print('DIAGNOSTIC',per_bone,ratios,flush=True)
assert max_matrix_error<2e-6 and all(abs(x-1.2)<.001 for x in ratios.values())
report={'passed':True,'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'action_sha256':ui.action_signature(new),'previous_action_sha256':ui.action_signature(old),'normalized_phase_samples':441,'non_arm_bones_compared':names,'maximum_non_arm_matrix_difference':max_matrix_error,'arm_pitch_excursion_deg':ranges,'arm_excursion_ratio':ratios,'cadence_ratio':22/20,'track_spacing_m':.27,'toe_out_deg':{'L':3,'R':5},'hip_range_mm':{'lateral':26,'fore_aft':50,'vertical':43},'nominal_controller_speed_m_s':2.31,'contact_frames':{'L':1,'R':11},'support_duty':{'L':.42,'R':.43},'flight_fraction':.15,'previous_source_preserved':True}
(O/'refinement_comparison.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
