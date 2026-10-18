"""Use the actual Walking shoulder sockets, rather than another whole-hold offset.

Only native rifle/rig calibration changes; incoming Run clocks/core remain.
The relative shoulder float is reduced to the measured Walking envelope.
"""
import math
from mathutils import Matrix,Vector
SETTINGS={
 'walking_reference':'Rifle_Ready_Walk_ActionsStyle_v0012',
 'walking_action_sha256':'e5592898f9ddb8c4b1f010107c288b19cf6c64131bfef88631f6e7a127c71bb6',
 'walk_shoulder_mean':{'L':[.349059085647724,.21064260395514772,.045092051113174915], 'R':[-.29959549495034077,.14516990279077657,.14210690117460476]},
 'run_shoulder_mean':{'L':[.34044072834833133,.18890325458838617,.10097010934839556], 'R':[-.3254988167191452,.14415166918391806,.13302716325883665]},
 'relative_shoulder_bob_fraction':.15,
 'carry_pitch_deg':-5.,'carry_yaw_deg':5.,'right_axial_calibration_deg':10.,
 'left_extra_axial_roll_deg':0.,
}
HOLD=['UpperArm.R','ForeArm.R','WeaponCarrier','UpperArm.L','ForeArm.L']
def target(side,chest,source):
 old=chest.inverted()@source['UpperArm.'+side].translation
 v=Vector(SETTINGS['walk_shoulder_mean'][side])+(old-Vector(SETTINGS['run_shoulder_mean'][side]))*SETTINGS['relative_shoulder_bob_fraction']
 return chest@v

def apply(source,palm):
 M={n:m.copy() for n,m in source.items()};C=source['Chest'];rel=C.inverted()@source['UpperArm.R']
 R=C.to_3x3()@Matrix.Rotation(math.radians(SETTINGS['carry_yaw_deg']),3,'Y')@Matrix.Rotation(math.radians(SETTINGS['carry_pitch_deg']),3,'X')@rel.to_3x3()@Matrix.Rotation(math.radians(SETTINGS['right_axial_calibration_deg']),3,'Y')
 arm=R.to_4x4();arm.translation=target('R',C,source);D=arm@source['UpperArm.R'].inverted()
 for n in HOLD:M[n]=D@M[n]
 P=M['ForeArm.L']@palm;q=(M['UpperArm.L'].translation-P).rotation_difference(target('L',C,source)-P);D=Matrix.Translation(P)@q.to_matrix().to_4x4()@Matrix.Translation(-P)
 for n in ['UpperArm.L','ForeArm.L']:M[n]=D@M[n]
 return M
