"""Original SOLDIER face parameters; deterministic, Blender-independent and bounded.
No source-derived blink timing: the pack's referenced Persona controller is external.
Positive gazeX means character-left. Head channels are preview-only coordination.
"""
from functools import lru_cache
import math,random
NEUTRAL=dict(open_l=1.,open_r=1.,brow_l=0.,brow_r=0.,tilt_l=0.,tilt_r=0.,gaze_x=0.,gaze_y=0.,pupil_scale=1.,blink=0.,blink_auto=0.,head_yaw=0.,head_pitch=0.)
LIMITS={k:(-1.,1.) for k in NEUTRAL}
LIMITS.update(open_l=(.05,1.3),open_r=(.05,1.3),pupil_scale=(.65,1.05),blink=(0.,1.),blink_auto=(0.,1.),head_yaw=(-3.,3.),head_pitch=(-3.,3.))
PRESETS={
 'Neutral_Idle':dict(duration=8.,loop=True,target={}),
 'Blink_Soft':dict(duration=2.,loop=True,target={}),
 'Look_Left':dict(duration=2.6,loop=True,target=dict(gaze_x=.92,head_yaw=2.8)),
 'Look_Right':dict(duration=2.6,loop=True,target=dict(gaze_x=-.92,head_yaw=-2.8)),
 'Look_Down_Short':dict(duration=1.8,loop=True,target=dict(gaze_y=-.82,head_pitch=2.5)),
 'Alert':dict(duration=2.4,loop=False,target=dict(open_l=1.23,open_r=1.23,brow_l=.42,brow_r=.40,pupil_scale=.91)),
 'Focused_Aim':dict(duration=3.,loop=True,target=dict(open_l=.73,open_r=.88,brow_l=-.22,brow_r=-.12,tilt_l=.38,tilt_r=.32)),
 'Fire_Recoil_Face':dict(duration=1.8,loop=False,target=dict(open_l=.48,open_r=.65,brow_l=-.30,brow_r=-.22,tilt_l=.43,tilt_r=.38)),
 'Enemy_Nearby':dict(duration=3.4,loop=True,target=dict(open_l=1.10,open_r=1.12,brow_l=.18,brow_r=.25,tilt_l=.12,tilt_r=.12)),
 'Move_Effort_Light':dict(duration=3.,loop=True,target=dict(open_l=.95,open_r=.95,tilt_l=.08,tilt_r=.08)),
 'Run_Effort':dict(duration=3.,loop=True,target=dict(open_l=.79,open_r=.80,brow_l=-.12,brow_r=-.12,tilt_l=.30,tilt_r=.30)),
 'Jump_Focus':dict(duration=2.,loop=False,target=dict(open_l=.80,open_r=.84,brow_l=-.10,brow_r=-.10,tilt_l=.30,tilt_r=.30)),
 'Land_Impact':dict(duration=1.8,loop=False,target=dict(open_l=.32,open_r=.39,brow_l=-.22,brow_r=-.22,tilt_l=.38,tilt_r=.38)),
 'Hurt_Light':dict(duration=2.2,loop=False,target=dict(open_l=.35,open_r=.57,brow_l=.05,brow_r=.10,tilt_l=-.42,tilt_r=-.36)),
 'Hurt_Heavy':dict(duration=2.6,loop=False,target=dict(open_l=.12,open_r=.20,brow_l=.20,brow_r=.26,tilt_l=-.80,tilt_r=-.72)),
 'Low_HP_Tense':dict(duration=4.,loop=True,target=dict(open_l=.66,open_r=.73,brow_l=.02,brow_r=.08,tilt_l=-.55,tilt_r=-.45)),
 'Victory_Small':dict(duration=3.,loop=False,target=dict(open_l=.74,open_r=.81,brow_l=.23,brow_r=.30,tilt_l=-.08,tilt_r=-.06)),
 'Death_Stunned':dict(duration=3.,loop=False,target=dict(open_l=1.28,open_r=1.28,brow_l=.55,brow_r=.55,pupil_scale=.69)),
}
SITUATIONS={'Idle':8.,'Walk':4.,'Run':4.,'Rifle Ready Idle':7.2,'Aim':4.8,'Fire':3.6,'Jump':2.4,'Landing':2.2,'Hurt':3.6,'Low Health':4.}
BASE={'Idle':'Neutral_Idle','Walk':'Move_Effort_Light','Run':'Run_Effort','Rifle Ready Idle':'Enemy_Nearby','Aim':'Focused_Aim','Fire':'Focused_Aim','Jump':'Neutral_Idle','Landing':'Neutral_Idle','Hurt':'Enemy_Nearby','Low Health':'Low_HP_Tense'}
EVENTS={'Fire_Recoil_Face':(.1666666667,.025,.0167,20),'Jump_Focus':(.38,.055,.10,30),'Land_Impact':(.33,.035,.045,40),'Hurt_Light':(.46,.045,.09,60),'Hurt_Heavy':(.70,.065,.14,80),'Death_Stunned':(1.15,.09,.60,100)}

def clamp(x,a,b):return min(b,max(a,x))
def smooth(t):t=clamp(t,0.,1.);return t*t*(3.-2.*t)
def pulse(t,duration,attack=.12,hold=.25):
 if t<=0 or t>=duration:return 0.
 if t<attack:return smooth(t/attack)
 if t<attack+hold:return 1.
 return 1.-smooth((t-attack-hold)/max(.001,duration-attack-hold))
def blend(a,b,w):return {k:a[k]+(b.get(k,NEUTRAL[k])-a[k])*w for k in NEUTRAL}
def target(name):return {**NEUTRAL,**PRESETS[name]['target']}
@lru_cache(maxsize=32)
def blink_schedule(duration=60.,focus=False):
 rng=random.Random(1701);times=[];t=2.7 if focus else 1.25
 while t<duration:
  times.append(t);t+=rng.uniform(5.6,8.2) if focus else rng.uniform(2.65,4.8)
 return tuple(times)
def blink_at(t,focus=False):
 return max([pulse(t-start,.18,.075,.02) for start in blink_schedule(max(60.,math.ceil(t/60)*60.),focus)]+[0.])
def finish(c,intensity=1.):
 c=blend(NEUTRAL,c,clamp(intensity,0.,1.))
 return {k:clamp(c[k],*LIMITS[k]) for k in NEUTRAL}
def evaluate_preset(name,t,auto_blink=True,intensity=1.):
 p=PRESETS[name];duration=p['duration'];t=clamp(t,0.,duration)
 if name=='Neutral_Idle':
  c=NEUTRAL.copy();c['open_l']=c['open_r']=1.-.008*math.sin(math.pi*t/duration)**2
  if 2.4<t<4.5:c['gaze_x']=.12*pulse(t-2.4,2.1,.24,.7)
 elif name=='Blink_Soft':
  c=NEUTRAL.copy();c['blink']=pulse(t-.5,.18,.075,.02)
 elif name in EVENTS:
  total,attack,hold,_=EVENTS[name];c=blend(NEUTRAL,target(name),pulse(t-.25,total,attack,hold))
 else:
  w=pulse(t-.12,max(.1,duration-.24),.16,max(.1,duration-.9))
  c=blend(NEUTRAL,target(name),w)
  if name=='Enemy_Nearby':c['gaze_x']=.30*math.sin(t*2.4)*w
 if auto_blink and name not in EVENTS and 0<t<duration:c['blink_auto']=blink_at(t,name=='Focused_Aim')
 return finish(c,intensity)
def evaluate_situation(state,t,events=None,low_hp=0.,auto_blink=True,intensity=1.):
 name=BASE[state];c=blend(NEUTRAL,target(name),smooth(t/.16))
 if state=='Rifle Ready Idle':
  c['open_l']=c['open_r']=1.02;c['gaze_x']=.15*pulse(t-2.1,2.0,.3,.5)
 elif state=='Idle':
  c['gaze_x']=.13*pulse(t-2.2,2.,.25,.8)-.09*pulse(t-5.2,1.7,.25,.6)
  c['open_l']=c['open_r']=1.-.008*(.5-.5*math.cos(t*math.pi/2))
 elif state in ['Walk','Run']:
  c['open_l']+=.012*math.sin(t*2*math.pi*(1.25 if state=='Walk' else 1.6));c['open_r']=c['open_l']
 c=blend(c,target('Low_HP_Tense'),clamp(low_hp,0.,1.)*.48)
 # Gameplay event requests compose by priority, never sum or restart a spring.
 planned=list(events or [])
 if events is None:
  if state=='Fire':planned=[{'type':'Fire_Recoil_Face','time':.35+i/6} for i in range(24)]
  elif state=='Jump':planned=[{'type':'Jump_Focus','time':.30},{'type':'Land_Impact','time':1.35}]
  elif state=='Landing':planned=[{'type':'Land_Impact','time':.5}]
  elif state=='Hurt':planned=[{'type':'Hurt_Light','time':.4},{'type':'Hurt_Heavy','time':1.6}]
 active=[]
 for e in planned:
  total,attack,hold,priority=EVENTS[e['type']];weight=pulse(t-e['time'],total,attack,hold)
  if weight>0:active.append((priority,weight,e['type']))
 if active:
  priority=max(e[0] for e in active);winner=max((e for e in active if e[0]==priority),key=lambda e:e[1])
  c=blend(c,target(winner[2]),winner[1])
 if auto_blink and not active:c['blink_auto']=blink_at(t,state in ['Aim','Fire'])
 return finish(c,intensity)
