"""One rifle contact adaptation of immutable charged crossbow source motion."""
import math
from mathutils import Matrix,Vector
HOLD=['UpperArm.R','ForeArm.R','UpperArm.L','ForeArm.L','WeaponCarrier']
class RifleFit:
 def __init__(self,rig,source,P):
  self.rig=rig;self.B={n:m.copy() for n,m in source.items()};self.P=P
  self.gR=Vector((0,P['right_grip_along_arm_m'],P['right_grip_normal_m']))
  self.gL=Vector((0,P['left_palm_along_arm_m'],0));self.support=Vector(P['left_support_carrier_local'])
  W=Matrix.Rotation(math.radians(P['weapon_yaw_deg']),4,'Z')@Matrix.Diagonal(Vector((-1.,-1.,1.,1.)));W.translation=Vector(P['weapon_grip'])
  self.M={'WeaponCarrier':W};self.stats={}
  for side,point,target in [('R',self.gR,W.translation),('L',self.gL,W@self.support)]:
   U=source['UpperArm.'+side];socket=U.translation-Vector((0,0,P.get('socket_drop_'+side+'_m',0.)));rot=U.to_3x3();desired=(target-socket).normalized();swing=(rot@point).normalized().rotation_difference(desired);Q=swing.to_matrix()@rot
   if P.get('roll_'+side,0):Q=Matrix.Rotation(math.radians(P['roll_'+side]),3,desired)@Q
   fit=Q.to_4x4();fit.translation=target-Q@point;self.M['UpperArm.'+side]=fit;self.M['ForeArm.'+side]=fit@(U.inverted()@source['ForeArm.'+side])
   self.stats[side]={'shoulder_shift_m':(fit.translation-U.translation).length,'orientation_change_deg':math.degrees(U.to_quaternion().rotation_difference(fit.to_quaternion()).angle),'shoulder_position':list(fit.translation),'point_local':list(point)}
 def value(self,source):
  M={n:m.copy() for n,m in source.items()}
  for side in ['R','L']:
   D=source['UpperArm.'+side]@self.B['UpperArm.'+side].inverted()
   for n in ['UpperArm.'+side,'ForeArm.'+side]:M[n]=D@self.M[n]
   if side=='R':M['WeaponCarrier']=D@self.M['WeaponCarrier']
  # A constant look calibration follows the raised rifle; source head roll and clocks remain.
  H=Matrix.Rotation(math.radians(self.P['head_yaw_deg']),4,'Z')@source['Head'];H.translation=source['Head'].translation.copy();M['Head']=H
  # Constant24mm whole-hold seating preserves all source clocks and both contacts.
  D=Matrix.Translation((0,0,-self.P.get('holding_drop_m',0.)))
  for n in HOLD:M[n]=D@M[n]
  return M
