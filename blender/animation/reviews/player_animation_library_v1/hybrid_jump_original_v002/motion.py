"""Original soft landing revision, reusing only our own unchanged v001 ascent.

No proprietary keyframe data is imported. New landing knots and tangents are
independent original design. Source A&S informs overlap/spacing principles.
"""
import importlib.util,math
from pathlib import Path
_spec=importlib.util.spec_from_file_location('gaf_own_jump_v001',Path(__file__).parent.parent/'hybrid_jump_original_v001/motion.py')
old=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(old)
FPS=60;TAKEOFF=old.TAKEOFF;AIR_LOOP=old.AIR_LOOP;FLIGHT=old.FLIGHT;APEX_TIME=old.APEX_TIME;HEIGHT=old.HEIGHT;START=old.START
LANDING=.72;DURATION=2.4
descriptor=old.descriptor;takeoff=old.takeoff;airborne=old.airborne;elevation=old.elevation;ease=old.ease;mix=old.mix
def curve(t,knots):
 """C1 shape-preserving Hermite; non-extremal knots keep through-velocity."""
 if t<=knots[0][0]:return knots[0][1]
 if t>=knots[-1][0]:return knots[-1][1]
 n=len(knots);sec=[(b[1]-a[1])/(b[0]-a[0])for a,b in zip(knots,knots[1:])];tangent=[0.]*n
 for i in range(1,n-1):
  if sec[i-1]*sec[i]>0:
   h0=knots[i][0]-knots[i-1][0];h1=knots[i+1][0]-knots[i][0];w1=2*h1+h0;w2=h1+2*h0
   tangent[i]=(w1+w2)/(w1/sec[i-1]+w2/sec[i])
 for i,((a,x),(b,y))in enumerate(zip(knots,knots[1:])):
  if a<=t<=b:
   u=(t-a)/(b-a);h=b-a
   return (2*u**3-3*u*u+1)*x+(u**3-2*u*u+u)*h*tangent[i]+(-2*u**3+3*u*u)*y+(u**3-u*u)*h*tangent[i+1]
CHANNELS={
 'hip':[(0,0),(.115,-.062),(.21,-.047),(.35,-.006),(.47,-.014),(.59,-.003),(.72,0)],
 'lean':[(0,6),(.105,14),(.22,10),(.36,-2.5),(.49,2.7),(.62,.6),(.72,0)],
 'yaw':[(0,2),(.16,-1.6),(.38,.8),(.57,-.3),(.72,0)],
 'head':[(0,-1),(.055,-3.2),(.205,8.5),(.32,5),(.455,-2.3),(.61,.65),(.72,0)],
 'al':[(0,-28),(.13,6),(.29,-11),(.46,4),(.72,0)],
 'ar':[(0,-34),(.15,4),(.31,-9),(.48,3),(.72,0)],
 'splay':[(0,9),(.14,11),(.38,5),(.59,3.5),(.72,3)]}
def landing(t):return descriptor(**{k:curve(t,v)for k,v in CHANNELS.items()})
def context(t):
 local=t-START
 if local<0:return descriptor(),False,'hold'
 if local<TAKEOFF:return takeoff(local),False,'takeoff'
 if local<FLIGHT:return mix(airborne(local-TAKEOFF),landing(0),ease((local-TAKEOFF)/(FLIGHT-TAKEOFF))),False,'descent'
 if local<FLIGHT+LANDING:return landing(local-FLIGHT),True,'landing'
 return descriptor(),True,'settled'
def landmarks(phase):
 times=sorted({x for values in CHANNELS.values()for x,_ in values})
 if phase=='landing':return times
 return sorted(set([0,DURATION,START+APEX_TIME,START+FLIGHT]+[START+t for t in old.TAKEOFF_LANDMARKS]+[START+FLIGHT+t for t in times]))
def verify():
 assert max(abs(landing(LANDING)[k]-descriptor()[k])for k in descriptor())<1e-12
 # Through-velocity is a regression guard against the old all-knots-stop rule.
 dt=1e-5
 v=(landing(.21+dt)['hip']-landing(.21-dt)['hip'])/(2*dt)
 assert v>.15,v
 for key,knots in CHANNELS.items():
  for t,_ in knots[1:-1]:
   l=(curve(t,knots)-curve(t-dt,knots))/dt;r=(curve(t+dt,knots)-curve(t,knots))/dt
   assert abs(l-r)<.06,(key,t,l,r)
 assert abs(elevation(START+APEX_TIME)-HEIGHT)<1e-12
 return {'new_phase':'landing/context only','through_velocity_at_210ms_m_s':v,'c1_curve_checks':sum(len(v)-2 for v in CHANNELS.values()),'landing_seconds':LANDING,'same_preview_arc':True}
if __name__=='__main__':print(verify())
