"""One rifle Aim/Hold, authored around verified charged-crossbow handling.
Straight rigid arm solves preserve both original contact points. Source gesture,
reload and firing timelines are deliberately outside this single aiming Action.
"""
import math,json
from mathutils import Matrix,Vector,Quaternion
HOLD=['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']
def ease(x):
 x=min(1.,max(0.,x));return x*x*x*(10+x*(-15+6*x))
def env(t,lead=0.):return ease((t-(.6-lead))/.6)*(1-ease((t-(4.8+lead*.5))/.6))
def blend(a,b,w):
 p=a.translation.lerp(b.translation,w);q=a.to_quaternion().slerp(b.to_quaternion(),w);M=q.to_matrix().to_4x4();M.translation=p;return M
class Motion:
 def __init__(self,rig,base):
  self.r=rig;self.B={n:x.copy() for n,x in base.items()};self.rest={b.name:b.matrix_local.copy() for b in rig.data.bones};self.palmL=Vector((0,rig.data.bones['ForeArm.L'].length*.78,0));self.fore={s:base['UpperArm.'+s].inverted()@base['ForeArm.'+s] for s in ['L','R']};self.gripR=base['UpperArm.R'].inverted()@base['WeaponCarrier'].translation;self.anchorL=base['WeaponCarrier'].inverted()@(base['ForeArm.L']@self.palmL);self.palmL_arm=self.fore['L']@self.palmL
 def solve(self,preferred,target,socket,local_point,roll=0.):
  rod=preferred.to_3x3()@local_point;direction=(target-socket).normalized();q=rod.normalized().rotation_difference(direction);Q=q.to_matrix()@preferred.to_3x3()
  if roll:Q=Matrix.Rotation(math.radians(roll),3,direction)@Q
  M=Q.to_4x4();M.translation=target-Q@local_point;return M
 def static(self,P):
  M={n:x.copy() for n,x in self.B.items()};C=M['Chest'].copy();C=Matrix.Translation(C.translation)@Matrix.Rotation(math.radians(-(P['body_blade_deg']-12)),4,'Z')@Matrix.Translation(-C.translation)@C;M['Chest']=C
  C=Matrix.Translation(C.translation)@Matrix.Rotation(math.radians(P.get('chest_pitch_deg',0.)),4,'X')@Matrix.Translation(-C.translation)@C;M['Chest']=C
  headRot=Matrix.Rotation(math.radians(P.get('head_yaw_deg',0.)),4,'Z')@Matrix.Rotation(math.radians(P.get('head_roll_deg',0.)),4,'Y')@Matrix.Rotation(math.radians(P['head_nod_deg']),4,'X')
  for n in ['Neck','Head']:
   H=headRot@self.B[n];H.translation=C@(self.B['Chest'].inverted()@self.B[n].translation);M[n]=H
  W=Matrix.Rotation(math.radians(P['weapon_yaw_deg']),4,'Z')@Matrix.Rotation(math.radians(-P['weapon_pitch_deg']),4,'X')@Matrix.Diagonal(Vector((-1.,-1.,1.,1.)))@Matrix.Rotation(math.radians(P['weapon_roll_deg']),4,'Y');W.translation=Vector(P['grip']);M['WeaponCarrier']=W
  sockets={s:C@self.B['Chest'].inverted()@self.B['UpperArm.'+s].translation-Vector((0,0,P.get('shoulder_drop_m',0.)+(P.get('right_drop_m',0.) if s=='R' else 0.))) for s in ['L','R']}
  for side,point,target in [('R',self.gripR+Vector((0,P.get('grip_forward_m',0.),0)),W.translation),('L',self.palmL_arm+Vector((0,P.get('left_palm_forward_m',0.),0)),W@(self.anchorL+Vector((P.get('support_outward_m',0.),P.get('support_back_m',0.),P.get('support_up_m',0.)))))]:
   U=self.solve(self.B['UpperArm.'+side],target,sockets[side],point,P.get('left_axial_deg',0.) if side=='L' else P.get('right_axial_deg',0.));M['UpperArm.'+side]=U;M['ForeArm.'+side]=U@self.fore[side]
  return M
 def value(self,t,P):
  B=self.B;Aim=self.static(P);w=env(t);wc=env(t,.04);wh=env(t,.08);M={n:x.copy() for n,x in B.items()}
  # Original restrained, phase-coordinated life using verified .9/1.8/3.6s rhythms.
  breath=math.sin(math.tau*t/.9);slow=math.sin(math.tau*t/3.6);roll=math.sin(math.tau*t/1.8)
  D=Matrix.Translation((.0012*slow,0,.0015*(1-math.cos(math.tau*t/.9))))
  for n in ['Hips','Spine','Chest','Neck','Head']:M[n]=D@blend(B[n],Aim[n],wh if n in ['Head','Neck'] else wc)
  C=M['Chest'];pivot=C.translation.copy();attention=math.sin(math.tau*(t-1.2)/3.6)
  Q=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(P.get('idle_chest_yaw_deg',.18)*w*math.sin(math.tau*(t-1.30)/3.6)),4,'Z')@Matrix.Rotation(math.radians(.25*(1-.75*w)*breath),4,'X')@Matrix.Rotation(math.radians(.18*(1-.75*w)*roll),4,'Y')@Matrix.Translation(-pivot)
  for n in ['Chest','Neck','Head']:M[n]=Q@M[n]
  # Keep the head attached at the same torso-top anchor, with head leading aim.
  for n in ['Neck','Head']:M[n].translation=M['Chest']@(B['Chest'].inverted()@B[n].translation)
  for n in ['Neck','Head']:
   p=M[n].translation.copy();M[n]=Matrix.Rotation(math.radians(P.get('idle_head_yaw_deg',.65)*w*attention),4,'Z')@M[n];M[n].translation=p
  W=blend(B['WeaponCarrier'],Aim['WeaponCarrier'],w)
  W.translation=B['WeaponCarrier'].translation.lerp(Aim['WeaponCarrier'].translation,w**P.get('raise_position_exponent',1.5))
  W=D@W
  clearance=math.sin(math.pi*w)**2
  W.translation+=Vector((0,-P.get('raise_forward_clearance_m',.12)*clearance,-P.get('raise_lower_clearance_m',.035)*clearance))
  # Keep both fully straight reaches in front of their shoulder seats while
  # raising; this avoids the square arm blocks being pulled back into the head.
  anchors={'R':self.gripR+Vector((0,P.get('grip_forward_m',0.)*w,0)), 'L':self.palmL_arm+Vector((0,P.get('left_palm_forward_m',0.)*w,0))}
  left_target=W@(self.anchorL+Vector((P.get('support_outward_m',0.)*w-.015*clearance-P.get('transition_support_outward_m',0.)*math.sin(math.pi*w),P.get('support_back_m',0.)*ease(max(0.,(w-.2)/.8)),P.get('support_up_m',0.)*ease(min(1.,w*2))+.0007*math.sin(math.tau*t/.9))))
  extra=0.
  for side,target in [('R',W.translation),('L',left_target)]:
   socket=(D@blend(B['UpperArm.'+side],Aim['UpperArm.'+side],w)).translation-Vector((0,0,P.get('transition_shoulder_drop_m',0.)*clearance))
   v=target-socket;radial=anchors[side].length_squared-v.x*v.x-v.z*v.z
   if radial>0:extra=max(extra,v.y+math.sqrt(radial))
  W.translation.y-=max(0.,extra)
  # Tiny delayed holding response, strongest at Ready and attenuated for precision.
  small=(1-.65*w);pivot=W.translation.copy();W=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(P.get('idle_weapon_yaw_deg',.35)*w*math.sin(math.tau*(t-1.26)/3.6)),4,'Z')@Matrix.Rotation(math.radians(.16*small*math.sin(math.tau*(t-.06)/.9)-.16*small*math.sin(-math.tau*.06/.9)),4,'X')@Matrix.Translation(-pivot)@W
  M['WeaponCarrier']=W
  for side,point,target in [('R',self.gripR+Vector((0,P.get('grip_forward_m',0.)*w,0)),W.translation),('L',self.palmL_arm+Vector((0,P.get('left_palm_forward_m',0.)*w,0)),W@(self.anchorL+Vector((P.get('support_outward_m',0.)*w-.015*clearance-P.get('transition_support_outward_m',0.)*math.sin(math.pi*w),P.get('support_back_m',0.)*ease(max(0.,(w-.2)/.8)),P.get('support_up_m',0.)*ease(min(1.,w*2))+.0007*math.sin(math.tau*t/.9)))) )]:
   pref=blend(B['UpperArm.'+side],Aim['UpperArm.'+side],w);pref=D@pref
   socket=pref.translation-Vector((0,0,P.get('transition_shoulder_drop_m',0.)*clearance))
   roll=P.get('transition_'+('right' if side=='R' else 'left')+'_roll_deg',0.)*math.sin(math.pi*w)*w
   U=self.solve(pref,target,socket,point,roll)
   M['UpperArm.'+side]=U;M['ForeArm.'+side]=U@self.fore[side]
  return M
