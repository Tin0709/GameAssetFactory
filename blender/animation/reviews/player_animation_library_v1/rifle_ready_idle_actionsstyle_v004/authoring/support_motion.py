"""Small original support refinement. Existing source timing is unchanged."""
import math
ARM_DROP_M=.018
# Existing source waist pulse400deg/s and shoulder/head rhythm200deg/s.
# These original micro offsets follow those clocks with30/20/50degree overlap.
def sample(t):
 life=14.4+t
 return {'pressure_release_m':.0008*(1-math.cos(math.radians(life*400-30))),
         'along_rifle_m':.0015*math.sin(math.radians(life*200-20)),
         'shoulder_angle_degrees':.20*math.sin(math.radians(life*400-50))}
