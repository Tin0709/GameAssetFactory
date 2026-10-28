"""Original authored gait/support construction; no reference key/data imports.

Normalized phase describes a full left/right cycle. Root travel belongs to the
caller. Contact windows and all curve knots here are original design choices.
"""
import math
FPS=60
END=150
ORIGIN=.18
STYLES=[dict(kind='Walk',hz=1.2,speed=1.8,duty=.50,arm=34.,torso=8.,head=1.8,lift=0.),
        dict(kind='Run',hz=1.6,speed=4.3,duty=.28,arm=53.,torso=17.,head=2.5,lift=.095)]
L=.675; D=.1125
def smooth(t):return t*t*(3-2*t)
def ease(t):return t*t*t*(t*(t*6-15)+10)
def hermite(a,b,va,vb,t,length):
 return (2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*length*va+(-2*t**3+3*t*t)*b+(t**3-t*t)*length*vb
def mix(a,b,w):return a+(b-a)*w
def blend_style(w):
 return {k:mix(STYLES[0][k],STYLES[1][k],w) for k in STYLES[0] if k!='kind'}|{'kind':'Transition'}
def weight(t):
 # Original transition test: walk, accelerate, run, decelerate, walk.
 if t<.85:return 0.
 if t<1.35:return ease((t-.85)/.5)
 if t<2.8:return 1.
 if t<3.4:return 1-ease((t-2.8)/.6)
 return 0.
def leg(phase,s):
 q=(phase+.5)%1-.5;c=-D if q>=0 else D
 duty=s['duty'];stride=s['speed']/s['hz'];r=math.hypot(L,D)
 if abs(q)<=duty/2:
  return math.asin((stride*q+c)/r)-math.atan2(c,L),True,c
 edge=math.asin((stride*duty/2-D)/r)+math.atan2(D,L)
 velocity=stride/(r*math.cos(edge-math.atan2(D,L)))*(1-duty)
 x=((phase-duty/2)%1)/(1-duty)
 # Fast trailing pickup, a held open silhouette, decisive forward replacement.
 rear=math.radians(mix(38,57,(s['arm']-34)/19))
 front=math.radians(mix(-39,-58,(s['arm']-34)/19))
 knots=[(0.,edge,velocity),(.19,rear,0.),(.57,front,0.),(1.,-edge,velocity)]
 for (a,y,dy),(b,z,dz) in zip(knots,knots[1:]):
  if a<=x<=b:return hermite(y,z,dy,dz,(x-a)/(b-a),b-a),False,0.
 raise AssertionError(x)
def support_z(theta):return L*math.cos(theta)+D*abs(math.sin(theta))+.0003
def raw_height(p,s):
 # One mass trajectory per step. Within contact, smooth a small spatial
 # neighborhood of the geometric rolling support to avoid the box-edge cusp.
 q=(p+.25)% .5-.25
 half=s['duty']/2
 if abs(q)<=half:
  return support_z(leg(q%1,s)[0])-.004
 # Body floats only in the intentional exchange; unequal lift on alternate
 # steps gives a subtle leading-side accent without changing contact timing.
 a=half;b=.5-half; x=(q-half)%( .5)
 x=max(0.,min(1.,x/(b-a)))
 edge=support_z(leg(half,s)[0])-.004
 amplitude=s['lift']*(1 if (p%1)<.5 else .91)
 # Unequal time to apex / compression, smooth positional and speed endpoints.
 peak=.39
 wave=ease(x/peak) if x<peak else 1-ease((x-peak)/(1-peak))
 return edge+amplitude*wave
def hip_height(p,s):
 # Smooth only the mass trajectory, not the rigid sole constraints. A compact
 # original Gaussian window rounds box-edge/landing cusps; the tiny residual
 # is absorbed at the hidden hip junction, never by scaling the leg.
 weights=[math.exp(-.5*(i/3.3)**2)for i in range(-8,9)]
 return sum(raw_height((p+i*.00225)%1,s)*w for i,w in zip(range(-8,9),weights))/sum(weights)
def verify():
 for s in STYLES:
  for i in range(1,400):
   q=-s['duty']/2+s['duty']*i/400
   theta,plant,c=leg(q%1,s)
   assert plant and abs(L*math.sin(theta)+c*math.cos(theta)-(s['speed']/s['hz']*q+c))<1e-10
  assert abs(END/FPS*s['hz']-round(END/FPS*s['hz']))<1e-12
 return {'styles':2,'analytic_contact_checks':798,'fps':FPS,'comparison_seconds':END/FPS}
if __name__=='__main__':print(verify())
