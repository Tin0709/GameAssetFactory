"""Original authored jumping: no MD2 or A&S keyframe data loaded.

Angles are independent design values in degrees. Height is metres.
The separate presentation arc is a declared original review adapter.
"""
import math
FPS=60
TAKEOFF=.4
AIR_LOOP=.8
LANDING=.3
FLIGHT=.52
APEX_TIME=.25
HEIGHT=1.2
START=.4
DURATION=2.
def ease(x):
 x=max(0.,min(1.,x));return x*x*x*(x*(x*6-15)+10)
def curve(t,knots):
 if t<=knots[0][0]:return knots[0][1]
 for(a,x),(b,y)in zip(knots,knots[1:]):
  if t<=b:return x+(y-x)*ease((t-a)/(b-a))
 return knots[-1][1]
def descriptor(hip=0.,lean=0.,yaw=0.,head=0.,al=0.,ar=0.,ll=0.,lr=0.,splay=3.):return dict(hip=hip,lean=lean,yaw=yaw,head=head,al=al,ar=ar,ll=ll,lr=lr,splay=splay)
def takeoff(t):
 return descriptor(
  hip=curve(t,[(0,0),(.035,-.018),(.12,.006),(.24,0),(.4,0)]),
  lean=curve(t,[(0,0),(.035,12),(.12,-10),(.23,-14),(.4,-8)]),
  yaw=curve(t,[(0,0),(.12,-3),(.23,4),(.4,2)]),
  head=curve(t,[(0,0),(.05,-2),(.21,-4),(.4,-1)]),
  al=curve(t,[(0,0),(.035,23),(.12,-94),(.22,-134),(.4,-109)]),
  ar=curve(t,[(0,0),(.035,18),(.10,-88),(.24,-143),(.4,-116)]),
  ll=curve(t,[(0,0),(.045,-13),(.16,-61),(.27,-56),(.4,-42)]),
  lr=curve(t,[(0,0),(.06,8),(.19,24),(.4,14)]),
  splay=curve(t,[(0,3),(.14,12),(.4,9)]))
def airborne(t):
 base=takeoff(TAKEOFF);wave=2*math.pi*(t%AIR_LOOP)/AIR_LOOP
 # Start/end match takeoff exactly, with no independent capsule elevation.
 base['lean']+=1.2*(1-math.cos(wave));base['yaw']+=.7*math.sin(wave)
 base['head']+=.7*math.sin(wave);base['al']+=2.1*(1-math.cos(wave));base['ar']-=1.6*(1-math.cos(wave))
 base['ll']+=2.4*(1-math.cos(wave));base['lr']-=1.2*(1-math.cos(wave))
 return base
def landing(t):
 return descriptor(
  hip=curve(t,[(0,0),(.055,-.045),(.13,-.004),(.195,-.012),(.3,0)]),
  lean=curve(t,[(0,12),(.06,23),(.14,4),(.21,7),(.3,0)]),
  yaw=curve(t,[(0,2),(.075,-3),(.16,1),(.3,0)]),
  head=curve(t,[(0,3),(.075,4.5),(.15,-1.5),(.3,0)]),
  al=curve(t,[(0,-28),(.065,15),(.14,-14),(.21,4),(.3,0)]),
  ar=curve(t,[(0,-34),(.075,9),(.15,-11),(.23,3),(.3,0)]),
  splay=curve(t,[(0,9),(.08,12),(.18,6),(.3,3)]))
def mix(a,b,w):return {k:a[k]+(b[k]-a[k])*w for k in a}
def context(t):
 local=t-START
 if local<0:return descriptor(),False,'hold'
 if local<TAKEOFF:return takeoff(local),False,'takeoff'
 if local<FLIGHT:
  return mix(airborne(local-TAKEOFF),landing(0),ease((local-TAKEOFF)/(FLIGHT-TAKEOFF))),False,'descent'
 if local<FLIGHT+LANDING:return landing(local-FLIGHT),True,'landing'
 return descriptor(),True,'settled'
def elevation(t):
 local=t-START
 if local<=0 or local>=FLIGHT:return 0.
 if local<=APEX_TIME:
  u=local/APEX_TIME;return HEIGHT*(2*u-u*u)
 u=(local-APEX_TIME)/(FLIGHT-APEX_TIME);return HEIGHT*(1-u*u)
def verify():
 assert takeoff(TAKEOFF)==airborne(0)
 assert max(abs(airborne(0)[k]-airborne(AIR_LOOP)[k])for k in airborne(0))<1e-12
 assert max(abs(landing(LANDING)[k]-descriptor()[k])for k in descriptor())<1e-12
 assert elevation(START)==0 and elevation(START+FLIGHT)==0
 assert abs(elevation(START+APEX_TIME)-HEIGHT)<1e-12
 assert min(elevation(i/1000)for i in range(2001))>=0
 return {'phase_endpoint_checks':3,'arc_samples':2001,'takeoff_seconds':TAKEOFF,'landing_seconds':LANDING,'preview_flight_seconds':FLIGHT,'preview_arc_native_verified':False}
if __name__=='__main__':print(verify())
