import bpy,json,sys,math
from pathlib import Path
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE));import motion as m
rig=bpy.data.objects['HybridRun_Authoring_Rig'];s=bpy.context.scene
out=[]
def sample(f):
 s.frame_set(int(f),subframe=f%1)
 return {b.name:b.matrix.copy()for b in rig.pose.bones}
for variant in m.VARIANTS:
 name='Run_Hybrid_'+variant[0]+'_Original_v001';a=bpy.data.actions[name];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0]
 first=sample(1);near=sample(1.01);before=sample(128.99);last=sample(129);dt=.01/(m.FPS/m.FPS_BASE)
 pose=max(abs(first[b][i][j]-last[b][i][j])for b in first for i in range(4)for j in range(4))
 velocity=max(((near[b].translation-first[b].translation)/dt-(last[b].translation-before[b].translation)/dt).length for b in first)
 assert pose<1e-5 and velocity<.1,(name,pose,velocity)
 f1=sample(1);f17=sample(17)
 symmetry=max(abs(f1['Leg.R'][i][j]-f17['Leg.L'][i][j])for i in range(3)for j in range(4)if not(i==0 and j==3))
 assert symmetry<1e-5
 out.append({'action':name,'four_cycle_pose_seam_error':pose,'bone_origin_velocity_seam_difference_m_s':velocity,'opposite_leg_half_phase_matrix_error':symmetry})
(HERE/'seam_validation.json').write_text(json.dumps(out,indent=2));print('SEAMS',out)
