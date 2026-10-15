"""Independently authored original timing. No source-pack keys or Molang inputs."""
import math
PERIOD=8.0
HEAD=[(0,0),(.78,0),(1.08,24.5),(1.21,23),(1.95,23),(2.49,0),(3.64,0),(3.97,-21.5),(4.13,-20),(4.67,-20),(5.23,0),(8,0)]
TORSO=[(0,0),(.91,0),(1.43,3.6),(2.08,3.6),(2.79,0),(3.80,0),(4.39,-3.1),(4.82,-3.1),(5.52,0),(8,0)]
DROP=[(0,0),(.58,0),(.82,.018),(1.06,.064),(1.95,.064),(2.57,0),(3.48,0),(3.92,.058),(4.67,.058),(5.31,0),(8,0)]
WEIGHT=[(0,0),(.90,0),(1.57,.005),(2.26,.005),(2.98,0),(3.94,0),(4.49,-.004),(5.08,-.004),(5.87,0),(8,0)]
def ramp(u):
 u=max(0.,min(1.,u));return u*u*u*(10+u*(-15+6*u))
def path(keys,t):
 t=t%PERIOD
 for (a,x),(b,y) in zip(keys,keys[1:]):
  if a<=t<=b:return x+(y-x)*ramp((t-a)/(b-a))
 return keys[-1][1]
def motion(t):
 t=t%PERIOD;b=t%4.
 breathe=ramp(b/1.38) if b<=1.38 else 1-ramp((b-1.38)/(3.86-1.38))
 h=path(HEAD,t);torso=path(TORSO,t);hold=.85*path(TORSO,t-.075)
 attention=math.sqrt(h*h+torso*torso+hold*hold)
 return {'head':h,'torso':torso,'hold':hold,'drop':.064*(1-math.exp(-(attention/3.8)**2)),'weight':path(WEIGHT,t),'breathe':breathe,'pitch':-.45*path(HEAD,t)/24.5,'roll':.12*path(HEAD,t)/24.5,'head_lift':.0055*ramp(attention/4.)}
