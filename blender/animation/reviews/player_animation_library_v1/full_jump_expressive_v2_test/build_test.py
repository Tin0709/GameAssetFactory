"""Arm-only independent full-jump refinement; all original curves preserved."""
import bpy,json,sys,math,hashlib
from pathlib import Path
from mathutils import Euler
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/full_jump_expressive_v2_test';sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
NAME='Full_Jump_Expressive_v2_Test';OLD='Full_Jump_Expressive_Test';START=18;END=45
def smooth(t):return t*t*t*(10+t*(-15+6*t))
def weight(f,side):
 peak=30.5 if side=='R' else 31.5;settle=33.5 if side=='R' else 34.5
 if f<=START or f>=END:return 0.
 if f<peak:return smooth((f-START)/(peak-START))
 if f<=settle:return 1.
 return 1-smooth((f-settle)/(END-settle))
def build():
 destination=O/'full_jump_expressive_v2_review.blend';assert not destination.exists() and NAME not in bpy.data.actions
 baseline=json.loads((T/'baseline.json').read_text());assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==baseline['basis_source_sha256']
 s=bpy.context.scene;r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];original={a.name:ui.action_signature(a) for a in bpy.data.actions};assert len(original)==14
 ui.activate(s,7);old=bpy.data.actions[OLD];a=old.copy();a.name=NAME;a.use_fake_user=True
 # Preserve every key/value/handle except the two shoulder rotations. Sample
 # the old pose and slerp to a raised rigid-arm orientation with eased envelopes.
 sampled={side:[] for side in ['L','R']};previous={}
 for j in range((END-START)*16+1):
  f=START+j/16;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
  for side,z in [('L',30),('R',-32)]:
   q=r.pose.bones['UpperArm.'+side].rotation_quaternion.copy();target=Euler((math.radians(160),0,math.radians(z)),'ZXY').to_quaternion();v=q.slerp(target,weight(f,side));v.normalize()
   if side in previous and v.dot(previous[side])<0:v.negate()
   previous[side]=v.copy();sampled[side].append((f,v))
 for c in ui.curves(a):
  side=next((side for side in ['L','R'] if c.data_path==f'pose.bones["UpperArm.{side}"].rotation_quaternion'),None)
  if not side:continue
  for k in list(c.keyframe_points):
   if START<k.co.x<END:c.keyframe_points.remove(k,fast=True)
  for f,q in sampled[side][1:-1]:
   k=c.keyframe_points.insert(f,q[c.array_index],options={'FAST'});k.interpolation='LINEAR'
  c.update()
 r.name='FJ2_Test_Rig';r.data.name='FJ2_Test_RestRig';m.name='FJ2_Test_Mesh';r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 if ui.SCENE_TAG in s:del s[ui.SCENE_TAG]
 s.name='FULL_JUMP_V2_ARM_REFINEMENT';s.frame_start=1;s.frame_end=93;s.render.fps=30;s.render.fps_base=1;s.gaf_loop=False;s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];s.frame_set(1)
 s['purpose']='Pending arm-only full-jump comparison. Same in-place motion/timing/heavy landing. Preview elevation is temporary render data only.'
 assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in original.items())
 data={'action':NAME,'status':'pending','frames':[1,93],'fps':30,'in_place':True,'seamless_loop':False,'original_actions':original,'arm_only_window':[START,END],'arm_target_pitch_deg':160,'arm_target_spread_deg':{'L':30,'R':32},'peak_plateau_frames':{'L':[31.5,34.5],'R':[30.5,33.5]},'rig_changes':[],'last_support_frame':19,'contact_frames':{'L':46,'R':47},'impact_frame':51,'rebound_frame':67,'preview_height_m':.72,'motion_ownership':'Same existing in-place root/object pose.0.72m presentation elevation only; no trajectory added to rig Action.','scope':'Arm-height comparison only. Existing full jump, previous previews, timing, non-arm channels and landing remain unchanged.'}
 (O/'manifest.json').write_text(json.dumps(data,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(destination));print('BUILT INDEPENDENT ARM-ONLY FULL JUMP V2')
if __name__=='__main__':build()
