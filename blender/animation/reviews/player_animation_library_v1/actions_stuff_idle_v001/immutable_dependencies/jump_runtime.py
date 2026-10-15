"""Private resource reconstruction: local/alive/normal player, no special settings.

Input queries own all world motion and physics. Source PRS and conditions are
literal. Explicit engine conventions: positive-only unnormalized layer weights;
uniform Catmull-Rom with duplicated endpoints; outgoing state clips continue
through linear source-duration fades; one transition/controller/step, followed by
new-state clock-zero sampling. Engine VM ordering has not been measured. Head
relative_to entity is metadata for the caller's transform adapter.
"""
import copy
import json
import math
from pathlib import Path
import re
import sys
BASE=Path(__file__).with_name('immutable_dependencies')
if str(BASE) not in sys.path:sys.path.insert(0,str(BASE))
from molang import Molang
from source_channels import SourceChannels, BONES, CHANNELS, _neutral
from source_simulation import SourceSimulation
DEFAULT_PAYLOAD=Path(__file__).with_name('jump_source_payload.json')

class JumpChannels(SourceChannels):
    """Reuses immutable PRS mixer; extends only transient source interpolation."""
    @staticmethod
    def catmull(p0,p1,p2,p3,t):
        return .5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)

    def _channel(self,clip,bone,channel,clock,evaluator):
        value=clip.get('bones',{}).get(bone,{}).get(channel,[1.,1.,1.] if channel=='scale' else [0.,0.,0.])
        if not isinstance(value,dict):return self._vector(value,evaluator)
        keys=sorted((float(t),v) for t,v in value.items())
        # Exact keys use authored post; approach from left uses next pre.
        for t,v in keys:
            if abs(clock-t)<1e-11:return self._vector(v,evaluator)
        if clock<keys[0][0]:return self._vector(keys[0][1],evaluator,'pre')
        if clock>keys[-1][0]:return self._vector(keys[-1][1],evaluator)
        for i,((a,av),(b,bv)) in enumerate(zip(keys,keys[1:])):
            if a<clock<b:
                x=self._vector(av,evaluator);y=self._vector(bv,evaluator,'pre');t=(clock-a)/(b-a)
                spline=any(isinstance(v,dict) and v.get('lerp_mode')=='catmullrom' for v in (av,bv))
                if not spline:return [u+(v-u)*t for u,v in zip(x,y)]
                p0=self._vector(keys[max(0,i-1)][1],evaluator)
                p3=self._vector(keys[min(len(keys)-1,i+2)][1],evaluator,'pre')
                return [self.catmull(u,v,w,z,t) for u,v,w,z in zip(p0,x,y,p3)]
        raise AssertionError(clock)

    def sample_clip(self,alias,clock,variables=None,query=None):
        env={k if k.startswith('v.') else 'v.'+k:v for k,v in (variables or {}).items()}
        env.update({k if k.startswith('q.') else 'q.'+k:v for k,v in (query or {}).items()})
        env.setdefault('q.life_time',0.);env.setdefault('q.is_in_ui',0.);env.setdefault('q.body_y_rotation',0.)
        env.setdefault('q.target_x_rotation',0.);env['q.anim_time']=float(clock)
        out=_neutral();clip=self.clips[self.aliases[alias]];e=Molang(env)
        for bone in BONES:
            for channel in CHANNELS:out[bone][channel]=self._channel(clip,bone,channel,float(clock),e)
        return self._check(out)

class _Controller:
    def __init__(self,alias,data,owner):
        self.alias=alias;self.data=data;self.owner=owner
        self.state=data.get('initial_state','default');self.time=0.;self.clocks={};self.fired={}
        self.old=None;self.fade=0.;self.duration=0.;self.initialized=False
    @property
    def record(self):return self.data['states'][self.state]
    def _scripts(self,key,record):
        for script in record.get(key,[]):self.owner.vm.eval(script)
    def _initialize_clips(self):
        self.clocks={};self.fired={}
        for item in self.record.get('animations',[]):
            a=item if isinstance(item,str) else next(iter(item))
            if a in self.owner.channels.aliases and self.owner.channels.aliases[a] in self.owner.channels.clips:
                self.clocks[a]=0.;self.fired[a]=set()
    def _timeline(self,alias,clock,fired):
        clip=self.owner.clip(alias)
        for timestamp,script in clip.get('timeline',{}).items():
            if float(timestamp)<=clock+1e-10 and timestamp not in fired:
                self.owner.vm.eval(script);fired.add(timestamp)
                self.owner.events.append({'controller':self.alias,'alias':alias,'timestamp':float(timestamp),'clock':clock,'script':script})
    def _advance(self,clocks,fired,dt):
        for alias,clock in list(clocks.items()):
            clip=self.owner.clip(alias)
            self.owner.env['q.anim_time']=clock
            if clip.get('anim_time_update'):
                clocks[alias]=float(self.owner.vm.eval(clip['anim_time_update']))
            else:clocks[alias]=clock+dt
            self._timeline(alias,clocks[alias],fired[alias])
    def step(self,dt):
        if not self.initialized:
            self._scripts('on_entry',self.record);self._initialize_clips();self.initialized=True
            for a,c in self.clocks.items():self._timeline(a,c,self.fired[a])
        self.time=round(self.time+dt,14)
        self._advance(self.clocks,self.fired,dt)
        if self.old:
            self.fade+=dt;self._advance(self.old['clocks'],self.old['fired'],dt)
            if self.fade>=self.duration:self.old=None
        env=self.owner.env;env['q.state_time']=self.time
        durations=[float(self.owner.clip(a).get('animation_length',float('inf'))) for a in self.clocks]
        finishes=[self.clocks[a]>=length for a,length in zip(self.clocks,durations)
                  if self.owner.clip(a).get('loop') not in (True,'hold_on_last_frame')]
        env['q.any_animation_finished']=float(any(finishes));env['q.all_animations_finished']=float(bool(finishes) and all(finishes))
        for transition in self.record.get('transitions',[]):
            destination,expression=next(iter(transition.items()))
            if not self.owner.vm.eval(expression):continue
            oldrec=self.record;self._scripts('on_exit',oldrec)
            duration=oldrec.get('blend_transition',0.)
            if isinstance(duration,dict):raise ValueError('Special blend curve outside ordinary profile')
            self.duration=float(duration);self.fade=0.
            self.old={'state':self.state,'clocks':dict(self.clocks),'fired':copy.deepcopy(self.fired)} if self.duration else None
            self.state=destination;self.time=0.;env['q.state_time']=0.
            self._scripts('on_entry',self.record);self._initialize_clips()
            for a,c in self.clocks.items():self._timeline(a,c,self.fired[a])
            break
        return self.layers()
    def _layers_for(self,state,clocks,weight):
        env=self.owner.env;layers=[]
        for item in self.data['states'][state].get('animations',[]):
            a=item if isinstance(item,str) else next(iter(item));expression=1. if isinstance(item,str) else item[a]
            if a not in clocks:continue
            clock=clocks[a];clip=self.owner.clip(a)
            if clip.get('loop') is True and clip.get('animation_length'):clock%=float(clip['animation_length'])
            elif clip.get('animation_length'):clock=min(clock,float(clip['animation_length']))
            env['q.anim_time']=clock
            cw=float(self.owner.vm.eval(expression))*weight
            layers.append({'alias':a,'controller':self.alias,'state':state,'clock':clock,'controller_weight':cw,'state_weight':weight})
        return layers
    def layers(self):
        alpha=min(1.,self.fade/self.duration) if self.old else 1.
        out=self._layers_for(self.old['state'],self.old['clocks'],1-alpha) if self.old else []
        return out+self._layers_for(self.state,self.clocks,alpha)
    def snapshot(self):return {'state':self.state,'state_time':self.time,'clocks':dict(self.clocks),'outgoing':None if not self.old else self.old['state'],'fade_elapsed':self.fade,'fade_duration':self.duration}

class JumpRuntime:
    def __init__(self,payload_path=DEFAULT_PAYLOAD,initial_life=2.,holding_right=1.,holding_left=0.):
        self.channels=JumpChannels(payload_path);self.payload=self.channels.payload
        self.player=self.payload['player'];self.life=float(initial_life)
        self.env={k.lower():0. for k in set(re.findall(r'\bv\.[a-zA-Z_0-9]+',json.dumps(self.player)))}
        self.env.update({'v.tnlxsa':2.,'v.wtlyok':1.,'v.qlczor':self.life,'v.abjhra':self.life,'v.jcvgdh':self.life,'v.bueybx':self.life})
        self.vm=Molang(self.env);self.holding_right=float(holding_right);self.holding_left=float(holding_left)
        self.controllers={a:_Controller(a,self.payload['controllers'][self.channels.aliases[a]],self)
                          for a in ['veywgp','psowex','pyhwuc','ngeixo','muiqdc']}
        self.events=[]
    def clip(self,a):return self.channels.clips[self.channels.aliases[a]]
    def step(self,dt,query):
        dt=float(dt)
        if not math.isfinite(dt) or not 0<dt<=1/6:raise ValueError('dt outside (0,1/6]')
        q=SourceSimulation._queries(query,self.life,dt)
        if not math.isfinite(q['q.life_time']) or q['q.life_time']<self.life:raise ValueError('life_time must be finite and nondecreasing')
        self.events=[]
        for name in ['is_in_water','is_jumping','body_y_rotation','target_x_rotation','modified_distance_moved']:
            q.setdefault('q.'+name,0.)
        q.setdefault('q.any',lambda x,*values:float(x in values));q.setdefault('q.in_range',lambda x,a,b:float(a<=x<=b))
        q.setdefault('q.relative_block_has_any_tag',lambda *args:0.)
        q.setdefault('q.is_item_name_any',lambda *args:0.)
        q.setdefault('q.equipped_item_any_tag',lambda *args:0.)
        for name in ['is_in_ui','is_paperdoll','is_first_person','has_cape','is_riding','is_sneaking','is_swimming','is_crawling','is_gliding','blocking','main_hand_item_use_duration','item_is_charged']:
            if q.get('q.'+name):raise ValueError('Excluded special profile '+name)
        if not q['q.is_alive'] or not q['q.is_local_player'] or q['q.is_in_water']:raise ValueError('Requires alive local normal dry player')
        for k in list(self.env):
            if k.startswith(('q.','t.')):del self.env[k]
        self.env.update(q);self.life=q['q.life_time'];self.env['v.qlczor']+=dt
        # Literal authored order. No collision/raycast predictor needed while special branches are disabled.
        for i in [27,29,30]:self.vm.eval(self.player['scripts']['pre_animation'][i])
        # Same ordinary-item flags used by prior immutable SourceChannels profile.
        self.env['v.vbcdda']=self.holding_right;self.env['v.wfyvyl']=self.holding_left
        layers=[{'alias':'xfltzh','controller':'rzkmtm','state':'default','clock':self.life,'controller_weight':1.}]
        for alias in ['veywgp','psowex','pyhwuc','ngeixo','muiqdc']:
            layers.extend(self.controllers[alias].step(dt))
        layers.extend({'alias':a,'controller':'kcexxa' if a!='look_at_target' else 'hsfnbp','state':'default','clock':self.life,'controller_weight':1.} for a in ['bob','holding','look_at_target'])
        out=_neutral();applied=[]
        for layer in layers:
            result=self.channels._add_clip(out,layer['alias'],self.env,layer['clock'],layer['controller_weight'])
            applied.append(dict(layer,**{k:v for k,v in result.items() if k not in layer}))
        self.channels._check(out)
        return {'channels':out,'vars':{k:copy.deepcopy(v) for k,v in self.env.items() if k.startswith('v.')},
                'query':dict(q),'phase':self.env['v.eqhdel'],'phase01':self.env['v.ifcvde'],'life':self.life,
                'controllers':{a:c.snapshot() for a,c in self.controllers.items()},'layers':applied,'timeline_events':copy.deepcopy(self.events),
                'head_relative_to_entity':True,'profile':'local_alive_tnlxsa2_thirdperson_dry_no_specials',
                'engine_conventions':['positive_only_unnormalized_weights','uniform_catmull_duplicate_endpoints','linear_outgoing_fades','one_transition_per_controller_per_step','outgoing_clocks_continue']}
