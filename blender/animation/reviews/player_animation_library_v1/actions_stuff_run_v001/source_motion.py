"""Private source reconstruction only; exact source channels + declared runtime profile."""
import ast,json,math
from pathlib import Path
HERE=Path(__file__).resolve().parent
ALL=json.loads((HERE/'source/f2da1071.json').read_text())['animations']
RUN=ALL['animation.oreville_ans.fngydr']
BOB=ALL['animation.oreville_ans.tdrcwc']
SPRINT=ALL['animation.oreville_ans.ucaryc']
RATE=1.6;DURATION=6.0;FPS=30
PROFILE={'speed_normalized':1.0,'forward_weight':1.0,'lateral_weight':0.0,
 'grounded':True,'sprinting':True,'sprint_state_time_s':2.0,'life_time_origin_s':0.0,
 'phase_origin':0.0,'phase_rate_cycles_s':RATE,'duration_s':DURATION,
 'body_type':0,'head_look':[0,0],'turn_bank':0,'terrain_offset':0,
 'held_items':'generic main-hand item; unmirrored screen-left hand assumed right',
 'right_holding_flag':1.0,'left_holding_flag':0.0,'undfyr':0,'ground_speed_blocks_s':5.59,
 'nonpositive_directional_weights':'assumed inactive; runtime negative-weight semantics not established',
 'core_loop_s':1/RATE,'full_composite_short_loop':False}
_cache={}
def expression(value,phase,life_time):
 if not isinstance(value,str):return float(value)
 if value not in _cache:
  s=value.replace('q.anim_time','phase').replace('q.life_time','life_time')
  for a,b in [('Math.sin','sind'),('Math.cos','cosd'),('Math.min','min'),('Math.max','max')]:s=s.replace(a,b)
  tree=ast.parse(s,mode='eval')
  for n in ast.walk(tree):
   if not isinstance(n,(ast.Expression,ast.BinOp,ast.UnaryOp,ast.Add,ast.Sub,ast.Mult,ast.Div,ast.USub,ast.UAdd,ast.Constant,ast.Name,ast.Load,ast.Call)):raise ValueError(type(n).__name__)
   if isinstance(n,ast.Name)and n.id not in ['phase','life_time','sind','cosd','min','max']:raise ValueError(n.id)
   if isinstance(n,ast.Call)and(not isinstance(n.func,ast.Name)or n.func.id not in ['sind','cosd','min','max']or n.keywords):raise ValueError('Unsupported source call')
  _cache[value]=compile(tree,'<private-source-math>','eval')
 return eval(_cache[value],{'__builtins__':{}},{'phase':phase,'life_time':life_time,'sind':lambda x:math.sin(math.radians(x)),'cosd':lambda x:math.cos(math.radians(x)),'min':min,'max':max})
def vector(value,phase,life_time):
 if isinstance(value,dict):value=value.get('post',value.get('pre'))
 if not isinstance(value,list):value=[value]*3
 if len(value)==1:value=value*3
 assert len(value)==3
 return [expression(v,phase,life_time)for v in value]
def channel(clip,bone,key,phase,life_time=0.0):
 value=clip['bones'].get(bone,{}).get(key,[1,1,1]if key=='scale'else[0,0,0])
 if not isinstance(value,dict):return vector(value,phase,life_time)
 keys=sorted((float(t),v)for t,v in value.items())
 if phase<=keys[0][0]:return vector(keys[0][1],phase,life_time)
 if phase>=keys[-1][0]:return vector(keys[-1][1],phase,life_time)
 for (a,x),(b,y)in zip(keys,keys[1:]):
  if a<=phase<=b:
   # fngydr has plain vectors/default linear interpolation. Sprint is read
   # only at its held endpoint; never approximate a Catmull-Rom transition.
   if isinstance(x,dict)or isinstance(y,dict):raise ValueError('Nonlinear transient interpolation is outside this steady profile')
   w=(phase-a)/(b-a);xx=vector(x,phase,life_time);yy=vector(y,phase,life_time)
   return [u+(v-u)*w for u,v in zip(xx,yy)]
 raise AssertionError(phase)
def channels(bone,t,include_bob=True,include_sprint=True):
 p=(PROFILE['phase_origin']+RATE*t)%1;life=PROFILE['life_time_origin_s']+t
 out={key:channel(RUN,bone,key,p,life)for key in ['rotation','position','scale']}
 # Bedrock accumulates local channels before constructing the transform.
 for clip,clock,enabled in [(BOB,p,include_bob),(SPRINT,2.0,include_sprint)]:
  if not enabled:continue
  for key in ['rotation','position']:
   add=channel(clip,bone,key,clock,life);out[key]=[x+y for x,y in zip(out[key],add)]
 # Source holding/dpjhxl is evaluated after bob with blend_weight .5 and
 # increment -this*holding_flag. Retain the recorded item's arm attenuation
 # under the explicitly declared standard unmirrored-hand assumption.
 if bone in ['rightarm','leftarm']:
  flag=PROFILE['right_holding_flag'if bone=='rightarm'else'left_holding_flag']
  out['rotation'][0]*=1-.5*flag
 return out
def source_break_times():
 phases={0.,1.,.125,.375,.625,.875}
 for b in RUN['bones'].values():
  for value in b.values():
   if isinstance(value,dict):phases.update(float(x)for x in value)
 return sorted({(cycle+p)/RATE for cycle in range(math.ceil(DURATION*RATE)+1)for p in phases if 0<=(cycle+p)/RATE<=DURATION}|{0.,DURATION})
