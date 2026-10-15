"""Original scan choreography and periodic support profiles informed by crossbow layering.
No proprietary temporal keyframes, controller expressions or source clips are baked.
Source comparisons and constrained pose differences are recorded in REFERENCE.md.
"""
import math
PERIOD=8.0
HEAD=[(0,0),(.52,0),(.83,-23),(.96,-21.5),(1.72,-21.5),(2.17,0),(3.12,0),(3.43,20),(3.56,18.5),(4.38,18.5),(4.87,0),(8,0)]
TORSO=[(0,0),(.65,0),(1.13,-3.6),(1.84,-3.6),(2.42,0),(3.25,0),(3.75,3.1),(4.49,3.1),(5.13,0),(8,0)]
WEIGHT=[(0,0),(.7,0),(1.28,-.006),(1.95,-.006),(2.62,0),(3.35,0),(3.94,.005),(4.69,.005),(5.4,0),(8,0)]
def ramp(u):
 u=max(0.,min(1.,u));return u*u*u*(10+u*(-15+6*u))
def path(keys,t):
 t=t%PERIOD
 for (a,x),(b,y) in zip(keys,keys[1:]):
  if a<=t<=b:return x+(y-x)*ramp((t-a)/(b-a))
 return keys[-1][1]
def motion(t):
 t=t%PERIOD
 # Original four-to-one weight/rebound rhythm, not literal source100/400deg/s.
 phase=2*math.pi*t/4.;pulse=2*math.pi*t
 h=path(HEAD,t);torso=11.+path(TORSO,t)
 hold=11.+.85*path(TORSO,t-.075)
 # Braced crossbow-style shoulders suppress free arm swing; one rigid holding frame.
 attention=math.sqrt(h*h+(torso-11.)**2+(hold-11.)**2)
 return {'head':h,'torso':torso,'hold':hold,'drop':.064*(1-math.exp(-(attention/3.8)**2)),
 'weight':path(WEIGHT,t)+.0035*math.sin(phase),
 'breathe':.5-.5*math.cos(pulse),
 'pitch':-.65*h/23.,'roll':.22*math.sin(phase),
 'head_lift':.0055*ramp(attention/4.),'body_pitch':.45*math.sin(pulse),
 'body_roll':.28*math.sin(phase),'hold_pitch':.34*math.sin(pulse-.18)}
