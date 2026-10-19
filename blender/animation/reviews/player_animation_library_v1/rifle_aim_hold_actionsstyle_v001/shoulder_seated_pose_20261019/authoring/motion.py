"""Focused rifle aim: user-requested body/head fit; immutable source supplies all idle clocks."""
from mathutils import Matrix,Vector,Quaternion
HOLD=['UpperArm.R','ForeArm.R','UpperArm.L','ForeArm.L','WeaponCarrier']
CORE=['Root','Hips','Leg.L','Leg.R']
class RifleFit:
 def __init__(self,rig,source,P):
  import json
  from pathlib import Path
  self.B={n:m.copy() for n,m in source.items()};self.P=P
  self.M={n:Matrix(v) for n,v in json.loads((Path(__file__).parent/'static_pose.json').read_text()).items()}
  self.D=self.M['Chest']@self.B['Chest'].inverted();self.H=self.M['Head'].to_3x3()@self.B['Head'].to_3x3().inverted()
  self.gR=Vector((0,.539200127,.016389614));self.gL=Vector((0,P['left_palm_m'],0));self.support=Vector(P['support']);self.stats=P
 def value(self,source):
  M={n:m.copy() for n,m in source.items()}
  for n in ['Spine','Chest','Neck']:M[n]=self.D@source[n]
  deltaq=self.B['Head'].to_quaternion().inverted()@source['Head'].to_quaternion();deltaq=Quaternion().slerp(deltaq,self.P.get('head_idle_delta_weight',1.));head_follow=(M['Chest']@self.M['Chest'].inverted()).to_quaternion();M['Head']=(head_follow@self.M['Head'].to_quaternion()@deltaq).normalized().to_matrix().to_4x4();M['Head'].translation=M['Neck'].translation+M['Chest'].to_3x3().col[1]*self.P.get('head_seat_lift_m',0.)
  # Both rigid arms and rifle share the source hold delta: preserve contact through breath/weight pulses.
  delta=self.D@source['UpperArm.R']@self.B['UpperArm.R'].inverted()@self.D.inverted()
  for n in HOLD:M[n]=delta@self.M[n]
  return M
