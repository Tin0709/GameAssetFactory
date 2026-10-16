"""No source timing/PRS modifications. Full active graph at240Hz; seed is a declared PRNG adapter."""
import copy,math
from crossbow_runtime import IdleRuntime,idle_query,serializable_snapshot,IdleChannels,_neutral
DURATION=10.8;HZ=240;SEED=139
def query(charged=0):
 return idle_query(item_is_charged=charged,is_item_name_any=lambda slot,*items:float(slot=='slot.weapon.mainhand' and 'minecraft:crossbow' in items),equipped_item_any_tag=lambda slot,*tags:float(slot=='slot.weapon.mainhand' and 'oreville:is_crossbow' in tags),get_equipped_item_name=lambda slot:'crossbow' if slot==0 else '',is_item_equipped=lambda slot:float(slot!='off_hand'))
class Sampler:
 def __init__(self,payload):
  self.runtime=IdleRuntime(payload,initial_life=13.4,seed=SEED,modified_distance_moved=1.,attack_free_age=12.)
  for i in range(HZ):self.runtime.step(1/HZ,query())
  self.rows=[]
  for i in range(round(DURATION*HZ)+1):
   row=self.runtime.step(1/HZ,query()) if i else self.runtime.last
   s=serializable_snapshot(row);s['time_s']=i/HZ;self.rows.append(s)
  assert all(r['controllers']['kcexxa']['state']=='ltqtzr' for r in self.rows)
  assert any(r['controllers']['bjmscc']['state']=='tculwn' for r in self.rows)
 def value(self,t):
  row=self.rows[min(int(math.floor(t*HZ+1e-8)),len(self.rows)-1)];ahead=t-row['time_s']
  if abs(ahead)<1e-9:return row['channels']
  env=dict(row['vars']);env.update({'q.life_time':row['life']+ahead,'q.is_in_ui':0.,'q.body_y_rotation':0.,'q.target_x_rotation':0.,'q.delta_time':ahead})
  out=_neutral()
  for l in row['layers']:
   c=self.runtime.channels.clips[self.runtime.channels.aliases[l['alias']]];clock=l['clock']+ahead
   if c.get('loop') is True and c.get('animation_length'):clock%=float(c['animation_length'])
   elif c.get('animation_length'):clock=min(clock,float(c['animation_length']))
   self.runtime.channels._add_clip(out,l['alias'],env,clock,l['controller_weight'])
  return out
 def times(self):
  entry=next(r['time_s'] for r in self.rows if r['controllers']['bjmscc']['state']=='tculwn');clip=self.runtime.channels.clips[self.runtime.channels.aliases['tculwn']]
  points={entry,entry+float(clip['animation_length']),entry+float(clip['animation_length'])+.2}
  for b in clip['bones'].values():
   for k in ['rotation','position','scale']:
    if isinstance(b.get(k),dict):points.update(entry+float(t) for t in b[k])
  return sorted({i/HZ for i in range(round(DURATION*HZ)+1)}|{t for t in points if 0<=t<=DURATION})
