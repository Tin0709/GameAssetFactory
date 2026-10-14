"""Native rig adaptation; source channels unchanged, parent/rest solving explicit."""
import math
from mathutils import Matrix,Vector
from source_motion import channels
class Retarget:
 def __init__(self,rig):
  self.base={p.name:p.matrix.copy()for p in rig.pose.bones}
  self.unit=self.base['Hips'].translation.z/12
  self.C=Matrix(((-1,0,0),(0,0,1),(0,1,0)));self.Ci=self.C.inverted()
 def transform(self,bone,t,pivot):
  values=channels(bone,t);x,y,z=[math.radians(v)for v in values['rotation']]
  # Three.js ZYX = explicit Rz Ry Rx = Blender XYZ, not Blender ZYX.
  bb=Matrix.Rotation(z,3,'Z')@Matrix.Rotation(-y,3,'Y')@Matrix.Rotation(-x,3,'X')
  rotation=(self.C@bb@self.Ci).to_4x4()
  x,y,z=values['position'];pos=Vector((x,z,y))*self.unit
  x,y,z=values['scale'];scale=Matrix.Diagonal((x,z,y,1))
  return Matrix.Translation(pos)@Matrix.Translation(pivot)@rotation@scale@Matrix.Translation(-pivot)
 def desired(self,t):
  base=self.base;d={n:m.copy()for n,m in base.items()}
  waist=self.transform('waist',t,base['Hips'].translation)
  body=waist@self.transform('body',t,base['Head'].translation)
  for n in ['Hips','Spine']:d[n]=waist@base[n]
  for n in ['Chest','Neck','WeaponCarrier']:d[n]=body@base[n]
  head=self.transform('head',t,base['Head'].translation)@base['Head']
  # Source look_at_target uses entity-relative head orientation. Preserve the
  # parent-translated pivot but cancel parent rotation on our native rig.
  head.translation=(body@base['Head']).translation
  d['Head']=head
  for side,source in [('L','leftarm'),('R','rightarm')]:
   n='UpperArm.'+side;pivot=base[n].translation-Vector((0,0,2*self.unit))
   arm=body@self.transform(source,t,pivot)
   d[n]=arm@base[n];d['ForeArm.'+side]=arm@base['ForeArm.'+side]
   n='Leg.'+side;d[n]=self.transform('leftleg'if side=='L'else'rightleg',t,base[n].translation)@base[n]
  return d
