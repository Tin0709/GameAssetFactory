"""Bounded native-block shoulder seating over the unchanged Pending Run v002.

The complete holding assembly shifts toward the chest and slightly upward.
The support arm rolls as one rigid block chain about its palm/shoulder axis;
its palm path and the inherited living support motion stay unchanged relative
 to the rifle. This is an authored rig accommodation, not literal source data.
"""
import math
from mathutils import Matrix,Vector
SETTINGS={'toward_torso_m':.030,'up_m':.010,'left_whole_arm_roll_deg':20.}
HOLD=['UpperArm.R','ForeArm.R','WeaponCarrier','UpperArm.L','ForeArm.L']
def apply(source,palm):
 M={n:m.copy() for n,m in source.items()}
 C=M['Chest'].to_3x3();T=Matrix.Translation(C@Vector((0,SETTINGS['up_m'],-SETTINGS['toward_torso_m'])))
 for n in HOLD:M[n]=T@M[n]
 P=M['ForeArm.L']@palm;axis=(M['UpperArm.L'].translation-P).normalized()
 D=Matrix.Translation(P)@Matrix.Rotation(math.radians(SETTINGS['left_whole_arm_roll_deg']),4,axis)@Matrix.Translation(-P)
 for n in ['UpperArm.L','ForeArm.L']:M[n]=D@M[n]
 return M
