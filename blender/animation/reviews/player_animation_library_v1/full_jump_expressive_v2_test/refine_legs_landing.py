"""User-steered wider airborne legs and stronger soft landing; old study preserved."""
import bpy,json,sys,math,runpy,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Euler
O=Path(__file__).resolve().parent;R=O.parents[4];T=R/'.validation/full_jump_expressive_v2_test';sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
LB=runpy.run_path(str(O.parent/'lowerbody_recovery_test/build_test.py'));leg_matrix=LB['leg_matrix'];NAME='Full_Jump_Expressive_v2_Test'
def smooth(t):t=max(0,min(1,t));return t*t*t*(10+t*(-15+6*t))
def envelope(f,start,peak,hold,end):
 if f<=start or f>=end:return 0.
 if f<peak:return smooth((f-start)/(peak-start))
 if f<=hold:return 1.
 return 1-smooth((f-hold)/(end-hold))
def build():
 guard=json.loads((T/'steering_guard.json').read_text());assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==guard['source_sha256']
 r=bpy.data.objects['FJ2_Test_Rig'];s=bpy.context.scene;a=bpy.data.actions[NAME];prior={x.name:ui.action_signature(x) for x in bpy.data.actions if x!=a};samples=[];previous={}
 for j in range(92*16+1):
  for b in r.pose.bones:b.scale=(1,1,1)
  f=1+j/16;r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();oldlegs={side:r.pose.bones['Leg.'+side].matrix.copy() for side in ['L','R']};oldhead=r.pose.bones['Head'].matrix.to_3x3().copy();r.animation_data.action=None
  air=envelope(f,20,30.5,34.5,44);impact=envelope(f,46,50.5,52,65);torso=envelope(f,46,51.5,53,65);arms=envelope(f,48,54,55,65)
  hip=r.pose.bones['Hips'];hip.location+=hip.bone.matrix_local.to_3x3().inverted()@Vector((0,0,-.028*impact));hip.rotation_euler.x+=math.radians(1.5*torso)
  for name,amount in [('Spine',1.7),('Chest',1.2)]:
   b=r.pose.bones[name];b.rotation_quaternion=(b.rotation_quaternion@Euler((math.radians(amount*torso),0,0),'XYZ').to_quaternion()).normalized()
  bpy.context.view_layer.update()
  for side in ['L','R']:
   b=r.pose.bones['Leg.'+side];old=oldlegs[side]
   if air>0:
    rot=Matrix.Rotation(math.radians((-8 if side=='L' else 8)*air),3,'Y');mat=(rot@old.to_3x3()).to_4x4();mat.translation=old.translation;b.matrix=mat
   elif impact>0 and f>=(46 if side=='L' else 47):
    socket=hip.matrix@(hip.bone.matrix_local.inverted()@b.bone.head_local);socket.x+=.007*(1 if side=='L' else -1)
    base=Vector((.128,-.105,0)) if side=='L' else Vector((-.128,.070,0));target=leg_matrix(b,socket,base,0);q=old.to_quaternion().slerp(target.to_quaternion(),impact);rot=q.to_matrix()@b.bone.matrix_local.to_3x3().inverted();D=.1125
    corner=Vector((-D if rot[2][0]>0 else D,-D if rot[2][1]>0 else D,-.675));anchor=base+Vector((corner.x,corner.y,.0004));mat=q.to_matrix().to_4x4();mat.translation=anchor-rot@corner;b.matrix=mat
   else:b.matrix=old
  for side,amount in [('L',8),('R',10)]:
   b=r.pose.bones['UpperArm.'+side];e=b.rotation_quaternion.to_euler('ZXY');e.x-=math.radians(amount*arms);e.z+=math.radians((3 if side=='L' else -3)*arms);b.rotation_quaternion=e.to_quaternion()
  bpy.context.view_layer.update();head=r.pose.bones['Head'];mat=oldhead.to_4x4();mat.translation=head.head;head.matrix=mat;bpy.context.view_layer.update()
  pose={}
  for b in r.pose.bones:
   prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'
   if prop=='rotation_quaternion':
    q=b.rotation_quaternion.copy();q.normalize()
    if b.name in previous and q.dot(previous[b.name])<0:q.negate()
    previous[b.name]=q.copy();value=list(q)
   else:value=list(b.rotation_euler)
   pose[b.name]={'location':list(b.location),prop:value}
  samples.append((f,pose))
 windows={'Leg.L':[(20,44),(46,65)],'Leg.R':[(20,44),(46,65)],'Hips':[(46,65)],'Spine':[(46,65)],'Chest':[(46,65)],'Head':[(46,65)],'UpperArm.L':[(48,65)],'UpperArm.R':[(48,65)]}
 for c in ui.curves(a):
  name=next((n for n in windows if c.data_path.startswith(f'pose.bones["{n}"]')),None)
  if not name:continue
  prop=c.data_path.rsplit('.',1)[1]
  for lo,hi in windows[name]:
   for k in list(c.keyframe_points):
    if lo<k.co.x<hi:c.keyframe_points.remove(k,fast=True)
   for f,pose in samples:
    if lo<f<hi:k=c.keyframe_points.insert(f,pose[name][prop][c.array_index],options={'FAST'});k.interpolation='LINEAR'
  c.update()
 for b in r.pose.bones:b.scale=(1,1,1)
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s.frame_set(1)
 assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in prior.items())
 p=O/'manifest.json';data=json.loads(p.read_text());data.update({'scope':'User-steered higher arms, wider airborne legs and harder soft landing. Original Full Jump preserved; same93frame timing, contact frames and controlled rebound.','airborne_leg_opening_added_deg_each':8,'airborne_leg_opening_window':[20,44],'additional_impact_compression_m':.028,'impact_window':[46,65],'additional_torso_pitch_deg':{'pelvis':1.5,'spine':1.7,'chest':1.2},'additional_arm_impact_pitch_deg':{'L':-8,'R':-10},'arm_only_checkpoint_preserved':'.validation/full_jump_expressive_v2_test/before_wider_legs_heavier_landing','landing_note':'Fixed receiving contactsF46/F47; faster deeper loading, no added rebound, exact original settled motion fromF65 onward.'});p.write_text(json.dumps(data,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(O/'full_jump_expressive_v2_review.blend'));print('WIDER AIRBORNE LEGS / HARDER SOFT LANDING / ORIGINALS PRESERVED')
if __name__=='__main__':build()
