"""Literal source crossbow + steady forward locomotion graph. No video fitting.
Settled constant-input continuation is checked against advancing full controller VM.
"""
import sys,math,json
from pathlib import Path
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists())
A=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v003/authoring'
sys.path.insert(0,str(A))
from crossbow_runtime import IdleRuntime,_neutral
from source_sampler import query
from extract_source import extract
HZ=240
PROFILE={'Walk':{'speed':4.3*(1.25/1.6)**2,'rate':1.25,'duration':7.2,'clip':'walk','state':'onccai'},'Run':{'speed':5.59,'rate':1.6,'duration':90.,'clip':'move','state':'run'}}
def engine_query(kind,elapsed):
 p=PROFILE[kind];q=query();q.update(position=(0,0,p['speed']*elapsed),ground_speed=p['speed'],modified_move_speed=p['speed']/4.3,is_sprinting=int(kind=='Run'),modified_distance_moved=1+p['speed']*elapsed);return q
class Sampler:
 def __init__(self,payload,kind):
  self.kind=kind;self.profile=PROFILE[kind];self.rt=IdleRuntime(payload,initial_life=0,seed=139,modified_distance_moved=1,attack_free_age=12)
  for i in range(round(14.4*HZ)):self.row=self.rt.step(1/HZ,engine_query(kind,(i+1)/HZ))
  self.frozen_env=dict(self.rt.env)
  assert self.row['controllers']['veywgp']['state']==self.profile['state']
  assert self.row['controllers']['kcexxa']['state']=='ltqtzr'
  assert not any(x['alias']=='tculwn' and x['applied_weight']>0 for x in self.row['layers'])
  assert abs(self.row['vars']['v.esnrkj']-min(1,self.profile['speed']/4.3))<1e-8
  assert abs(self.row['vars']['v.cknrcn']-1)<1e-8
 def value(self,t):
  env=dict(self.frozen_env);env['q.life_time']=self.row['life']+t;env['v.eqhdel']=self.row['phase']+t*self.profile['rate'];env['v.ifcvde']=env['v.eqhdel']%1
  out=_neutral()
  for l in self.row['layers']:
   clip=self.rt.channels.clips[self.rt.channels.aliases[l['alias']]];clock=l['clock']+t
   if clip.get('loop') is True and clip.get('animation_length'):clock%=float(clip['animation_length'])
   elif clip.get('animation_length'):clock=min(clock,float(clip['animation_length']))
   self.rt.channels._add_clip(out,l['alias'],env,clock,l['controller_weight'])
  return out
 def times(self):
  D=self.profile['duration'];points={i/HZ for i in range(round(D*HZ)+1)};clip=self.rt.channels.clips[self.rt.channels.aliases[self.profile['clip']]]
  phases={0.,1.}
  for b in clip['bones'].values():
   for ch in ['rotation','position','scale']:
    if isinstance(b.get(ch),dict):phases.update(float(k) for k in b[ch])
  origin=self.row['phase'];rate=self.profile['rate']
  for k in range(math.floor(origin)-1,math.ceil(origin+D*rate)+1):
   for p in phases:
    t=(k+p-origin)/rate
    if 0<=t<=D:points.add(t)
  return sorted(points)
 def evidence(self):
  # Independent advancing graph, original controller clocks/pre_animation.
  rt=self.rt;errors=[]
  for i in range(1,round(3.6*HZ)+1):
   row=rt.step(1/HZ,engine_query(self.kind,14.4+i/HZ))
   if i%13==0:
    sample=self.value(i/HZ);errors.append(max(abs(sample[b][c][j]-row['channels'][b][c][j]) for b in sample for c in sample[b] for j in range(3)))
  # value uses the frozen origin and its frozen vars, restore env before caller use.
  return max(errors)
