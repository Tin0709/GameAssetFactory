"""Private source Idle reconstruction, isolated from accepted locomotion.

Literal upstream player bone channels/controllers from the SHA-pinned archive.
Engine adapters are explicit: Python MT19937 seeded random integers, one ordered
transition/controller/frame, linear source-duration outgoing fades, positive-only
layer weights, uniform Catmull-Rom duplicated endpoints, accumulated-axis ``this``.
Final Bedrock geometry/face capture pipeline is outside this skeleton study.
"""
import copy
import math
from pathlib import Path
import random
import re
import sys

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists())
BASE=ROOT/'blender/animation/reviews/player_animation_library_v1/actions_stuff_idle_v001/immutable_dependencies'
if str(BASE) not in sys.path:sys.path.insert(0,str(BASE))
from jump_runtime import JumpRuntime, JumpChannels, _Controller
from molang import Molang
from source_channels import BONES, CHANNELS, _neutral
from source_simulation import SourceSimulation
BONES=BONES+('rightitem',)
def _neutral():
 return {b:{c:[1.,1.,1.] if c=='scale' else [0.,0.,0.] for c in CHANNELS} for b in BONES}

DEFAULT_PAYLOAD=Path(__file__).with_name('source_payload.json')
ENGINE_CONVENTIONS=[
 'python_random_MT19937_seeded_integer_inclusive_source_PRNG_unknown',
 'positive_only_unnormalized_controller_and_clip_weights_engine_unmeasured',
 'uniform_catmull_duplicate_endpoints',
 'one_ordered_transition_per_controller_per_step_then_new_state_clock_zero',
 'linear_outgoing_source_duration_fades_outgoing_clocks_continue',
 'recursive_source_animation_order_with_each_controller_stepped_once',
 'this_is_accumulated_same_axis_channel',
 'source_upstream_skeleton_only_face_and_final_geometry_capture_excluded',
]

def idle_query(**changes):
    """Caller-owned ordinary ground engine queries, with explicit neutral look."""
    q={'position':(0,0,0),'movement_direction':(0,0,1),'head_y_rotation':0,
       'body_y_rotation':0,'target_x_rotation':0,'is_on_ground':1,
       'is_alive':1,'is_local_player':1,'ground_speed':0,'vertical_speed':0,
       'is_sprinting':0,'is_jumping':0,'is_emoting':0,'attack_time':0,
       'time_of_day':.5}
    q.update(changes)
    return q

class IdleMolang(Molang):
    def __init__(self,env,owner):super().__init__(env);self.owner=owner
    def _execute(self,node):
        if node[0]=='call' and node[1] in ('math.random','math.random_integer'):
            args=[self._execute(a) for a in node[2]]
            value=(self.owner.rng.randint(int(args[0]),int(args[1])) if node[1]=='math.random_integer'
                   else self.owner.rng.uniform(*args))
            self.owner.random_draws.append({'function':node[1],'args':args,'value':value,'life':self.owner.life})
            return value
        if node[0]=='call' and node[1].startswith('math.ease_'):
            a,b,t=[self._execute(x) for x in node[2]]
            if node[1]=='math.ease_out_cubic':u=1-(1-t)**3
            elif node[1]=='math.ease_in_out_back':
                c=1.70158*1.525
                u=((2*t)**2*((c+1)*2*t-c)/2 if t<.5
                   else ((2*t-2)**2*((c+1)*(2*t-2)+c)+2)/2)
            else:raise ValueError('Unmeasured ease function '+node[1])
            return a+(b-a)*u
        return super()._execute(node)

class IdleChannels(JumpChannels):
    """Literal source sampler with accumulated-axis ``this`` in every key path."""
    def _add_clip(self,output,alias,env,clock,controller_weight=1.):
        clip=self.clips[self.aliases[alias]]
        if clip.get('override_previous_animation'):
            raise ValueError('Unexpected overriding clip in ordinary Idle: '+alias)
        sample_env=dict(env);sample_env['q.anim_time']=clock
        own_weight=float(Molang(sample_env).eval(clip.get('blend_weight',1)))
        weight=max(0.,float(controller_weight))*max(0.,own_weight)
        if weight:
            for bone in BONES:
                for channel in CHANNELS:
                    literal=clip.get('bones',{}).get(bone,{}).get(channel)
                    if literal is None:continue
                    # Evaluating each axis separately also supports this inside
                    # pre/post/keyframe expressions, without resetting other axes.
                    identity=1. if channel=='scale' else 0.
                    for axis in range(3):
                        sample_env['this']=output[bone][channel][axis]
                        vals=self._channel(clip,bone,channel,clock,Molang(sample_env))
                        output[bone][channel][axis]+=weight*(vals[axis]-identity)
        return {'alias':alias,'id':self.aliases[alias],'controller_weight':controller_weight,
                'clip_weight':own_weight,'applied_weight':weight,'clock':clock}

class IdleRuntime(JumpRuntime):
    """Ordinary default tnlxsa=0, grounded local unarmed source controller graph.

    Constructor is a fresh neutral history. ``relaxed`` declares prior movement
    and attack-free age; neither helper forces a controller state, random outcome,
    clip clock, locomotion phase or authored animation channel.
    """
    def __init__(self,payload_path=DEFAULT_PAYLOAD,initial_life=0.,seed=2,
                 modified_distance_moved=0.,attack_free_age=0.):
        self.channels=IdleChannels(payload_path);self.payload=self.channels.payload
        self.player=self.payload['player'];self.life=float(initial_life)
        self.env={k.lower():0. for k in set(re.findall(r'\bv\.[a-zA-Z_0-9]+',str(self.player)))}
        self.env.update({'v.tnlxsa':0.,'v.wtlyok':1.,'v.qlczor':self.life,
                        'v.abjhra':self.life,'v.jcvgdh':self.life,'v.bueybx':self.life,
                        'v.txtwqb':float(attack_free_age)})
        self.seed=int(seed);self.rng=random.Random(self.seed);self.random_draws=[]
        self.vm=IdleMolang(self.env,self);self.controllers={};self.events=[]
        self.modified_distance_moved=float(modified_distance_moved)
        self.holding_right=1.;self.holding_left=0.;self.env['v.is_holding_right']=1.;self.env['v.is_holding_left']=0.
        self.last=None
        self.history={'initial_life':self.life,'attack_free_age':float(attack_free_age),
                      'modified_distance_moved':self.modified_distance_moved,
                      'position':(0.,0.,0.),'head_yaw':0.,'body_yaw':0.}

    @classmethod
    def relaxed(cls,seed=2,initial_life=12.,payload_path=DEFAULT_PAYLOAD):
        """Just stopped after walking, attack-free >=12s; look aligned to body."""
        return cls(payload_path,initial_life,seed,modified_distance_moved=1.,attack_free_age=12.)

    def _controller(self,alias):
        if alias not in self.controllers:
            self.controllers[alias]=_Controller(alias,self.payload['controllers'][self.channels.aliases[alias]],self)
        return self.controllers[alias]

    def _visit(self,alias,weight,dt,stepped,layers,path=()):
        if weight<=0:return
        identifier=self.channels.aliases[alias]
        if identifier in self.channels.clips:
            # Direct entry point is only used for clip-valued root programs.
            layers.append({'alias':alias,'controller':'entity','state':'animate','clock':self.life,
                           'controller_weight':weight,'state_weight':1.,'ancestry':list(path)})
            return
        if identifier not in self.payload['controllers']:
            raise ValueError('Unresolved active source alias: '+alias)
        c=self._controller(alias)
        if alias not in stepped:c.step(dt);stepped.add(alias)
        alpha=min(1.,c.fade/c.duration) if c.old else 1.
        states=([(c.old['state'],c.old['clocks'],1-alpha)] if c.old else [])+[(c.state,c.clocks,alpha)]
        for state,clocks,state_weight in states:
            if state_weight<=0:continue
            for row in c.data['states'][state].get('animations',[]):
                child=row if isinstance(row,str) else next(iter(row));expr=1. if isinstance(row,str) else row[child]
                self.env['q.state_time']=c.time
                clock=clocks.get(child,self.life)
                if child in clocks:
                    clip=self.clip(child)
                    if clip.get('loop') is True and clip.get('animation_length'):clock%=float(clip['animation_length'])
                    elif clip.get('animation_length'):clock=min(clock,float(clip['animation_length']))
                self.env['q.anim_time']=clock
                child_weight=float(self.vm.eval(expr))*weight*state_weight
                child_id=self.channels.aliases[child]
                if child_id in self.channels.clips:
                    layers.append({'alias':child,'controller':alias,'state':state,'clock':clock,
                                   'controller_weight':child_weight,'state_weight':state_weight,
                                   'ancestry':list(path+(alias,))})
                elif child_weight>0:
                    self._visit(child,child_weight,dt,stepped,layers,path+(alias,))

    def step(self,dt,query):
        dt=float(dt)
        if not math.isfinite(dt) or not 0<dt<=1/6:raise ValueError('dt outside (0,1/6]')
        q=SourceSimulation._queries(query,self.life,dt)
        if not math.isfinite(q['q.life_time']) or q['q.life_time']<self.life:
            raise ValueError('life_time must be finite and nondecreasing')
        # This source study is ordinary standing + ground walking interruption.
        for name in ['is_in_ui','is_paperdoll','is_first_person','has_cape','is_riding','is_sneaking',
                     'is_swimming','is_crawling','is_gliding','blocking','main_hand_item_use_duration','item_is_charged']:
            if q.get('q.'+name):raise ValueError('Excluded special query '+name)
        if not q['q.is_alive'] or not q['q.is_local_player'] or not q['q.is_on_ground'] or q.get('q.is_in_water'):
            raise ValueError('Requires alive local unarmed dry grounded ordinary player')
        q.setdefault('q.modified_distance_moved',self.modified_distance_moved)
        q.setdefault('q.ground_speed',0.);q.setdefault('q.is_in_water',0.);q.setdefault('q.is_jumping',0.)
        q.setdefault('q.is_emoting',0.);q.setdefault('q.body_y_rotation',0.);q.setdefault('q.target_x_rotation',0.)
        q.setdefault('q.time_of_day',.5);q.setdefault('q.get_animation_frame',0.)
        q.setdefault('q.any',lambda x,*values:float(x in values))
        q.setdefault('q.in_range',lambda x,a,b:float(a<=x<=b))
        for name in ['relative_block_has_any_tag','relative_block_has_all_tags','is_item_name_any',
                     'equipped_item_any_tag','entity_biome_has_any_tags']:
            q.setdefault('q.'+name,lambda *args:0.)
        q.setdefault('q.get_equipped_item_name',lambda *args:'')
        q.setdefault('q.armor_texture_slot',lambda *args:-1.)
        for k in list(self.env):
            if k.startswith(('q.','t.')):del self.env[k]
        self.env.update(q);self.life=q['q.life_time'];self.events=[]
        self.env['v.qlczor']+=dt
        self.env['v.attack_time']=float(query.get('attack_time',query.get('v.attack_time',0.)))
        # literal authored pre-animation motion/direction programs; all excluded
        # query/item/surface branches are invariant zero for the stated profile.
        for i in [27,29,30]:self.vm.eval(self.player['scripts']['pre_animation'][i])
        self.env['v.is_holding_right']=1.;self.env['v.is_holding_left']=0.
        layers=[];self._visit('rzkmtm',1.,dt,set(),layers)
        out=_neutral();applied=[]
        for layer in layers:
            result=self.channels._add_clip(out,layer['alias'],self.env,layer['clock'],layer['controller_weight'])
            applied.append(dict(layer,**{k:v for k,v in result.items() if k not in layer}))
        self.channels._check(out)
        self.last={'channels':out,'vars':{k:copy.deepcopy(v) for k,v in self.env.items() if k.startswith('v.')},
          'query':dict(q),'phase':self.env['v.eqhdel'],'phase01':self.env['v.ifcvde'],'life':self.life,
          'controllers':{a:c.snapshot() for a,c in self.controllers.items()},'layers':applied,
          'timeline_events':copy.deepcopy(self.events),'random_draws':copy.deepcopy(self.random_draws),
          'head_relative_to_entity':True,'profile':'ordinary_default_tnlxsa0_mainhand_uncharged_crossbow_no_offhand',
          'history':dict(self.history),'seed':self.seed,'engine_conventions':list(ENGINE_CONVENTIONS)}
        return self.last

def serializable_snapshot(snapshot):
    """Keep sampled query values, not Python callables, in persisted evidence."""
    row={k:copy.deepcopy(v) for k,v in snapshot.items() if k!='query'}
    q={}
    for k,v in snapshot['query'].items():
        if not callable(v):q[k]=copy.deepcopy(v)
        elif k in ('q.position','q.movement_direction'):q[k]=[v(i) for i in range(3)]
        elif k=='q.head_y_rotation':q[k]=v(0)
    row['query']=q
    row['query_callable_conventions']={
       'q.any':'membership','q.in_range':'inclusive',
       'item_name_tag_and_biome_queries':'false: ordinary unarmed neutral biome',
       'q.get_equipped_item_name':'empty string','q.armor_texture_slot':-1,
       'q.is_riding_any_entity_of_type':'false','q.is_pack_setting_selected':'false: specials disabled'}
    return row

def sample_primary(duration=9.,hz=240):
    """One finite naturally selected normal-player Idle; source lifetime persists.

    Includes time0 and endpoint. As in the frozen study, time0 is the first
    fixed-dt source evaluation, so source life starts at12+1/hz seconds. This is
    a finite performance, not a seamless9-second loop.
    """
    hz=int(hz);duration=float(duration)
    if hz<=0 or duration<=0 or not math.isfinite(duration):raise ValueError('Positive duration/hz required')
    r=IdleRuntime.relaxed(seed=2,initial_life=12.)
    rows=[]
    for i in range(round(duration*hz)+1):
        s=serializable_snapshot(r.step(1/hz,idle_query()))
        s['time_s']=i/hz;s['source_evaluation_offset_s']=1/hz
        rows.append(s)
    return rows
