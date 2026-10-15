"""Audited ordinary ground player animation logic, with caller-owned engine input.

Executes literal entity pre_animation 27,29,30 in authored order. No keyboard,
physics, feet/contact constraints, pose mixing, or fabricated yaw queries. The
normal player type (tnlxsa=2), local, third-person, alive, grounded, unmounted,
noninteracting profile supports only lhbuwm states onccai and run. Alternate
rvwafl/speed-option states, jumping/recovery phase overrides, skins with alternate
controllers, cape and combat/item interactions are deliberately excluded.

initial_life seeds alive age/measurement timestamps; it does NOT advance phase or
pretend a velocity was observed. To settle a gait, supply real virtual query
samples. The harness may display the root in place while its engine-query trace
moves, but that convention belongs outside this module.
"""
import copy
import json
import math
from pathlib import Path
import re

from molang import Molang


CONTROLLER_ID='controller.animation.oreville_ans.lhbuwm'
_EXCLUDED_FLAGS=('v.rvwafl','v.hirjne','v.hhsumy','v.fxllpr','v.gddzeg',
                 'v.gtgvhp','v.yyjpfg','v.cthrgf','v.is_first_person','v.is_paperdoll')
_QUERY_PROFILE_ZERO=('q.is_in_ui','q.is_paperdoll','q.is_first_person','q.has_cape',
                     'q.is_riding','q.is_sprinting','q.is_sneaking','q.is_swimming',
                     'q.is_crawling','q.is_gliding','q.blocking',
                     'q.main_hand_item_use_duration','q.item_is_charged',
                     'q.vertical_speed','q.yaw_speed')


class SourceSimulation:
    def __init__(self,source_json_path,initial_life=0.0,profile_flags=None):
        payload=json.loads(Path(source_json_path).read_text())
        player=payload['player']
        if 'minecraft:client_entity' in player:
            player=player['minecraft:client_entity']['description']
        elif 'description' in player:
            player=player['description']
        self.player=player
        self.programs=[player['scripts']['pre_animation'][i] for i in (27,29,30)]
        self.controller=payload['controllers'][CONTROLLER_ID]
        self.env={name.lower():0.0 for name in set(re.findall(r'\bv\.[a-zA-Z_0-9]+',json.dumps(player)))}
        self.env.update({'v.tnlxsa':2.0,'v.wtlyok':1.0,'v.qlczor':float(initial_life),
                         'v.abjhra':float(initial_life),'v.jcvgdh':float(initial_life),
                         'v.bueybx':float(initial_life)})
        if profile_flags: self.env.update(profile_flags)
        self.molang=Molang(self.env)
        self.life=float(initial_life)
        self.state='onccai'
        self.state_time=0.0
        self.run_weight=0.0
        self._blend_elapsed=0.0
        self._blend_duration=0.0
        self._blend_from=0.0
        self._blend_to=0.0
        self._first_step=True

    @staticmethod
    def _queries(query,life,dt):
        normalized={key if key.startswith('q.') else 'q.'+key:value for key,value in query.items()}
        for key in _QUERY_PROFILE_ZERO: normalized.setdefault(key,0.0)
        normalized.setdefault('q.is_alive',1.0)
        normalized.setdefault('q.is_on_ground',1.0)
        normalized.setdefault('q.is_local_player',1.0)
        # The grounded/unmounted profile has no matching ridden entity/options.
        normalized.setdefault('q.is_riding_any_entity_of_type',lambda *args:0.0)
        normalized.setdefault('q.is_pack_setting_selected',lambda *args:0.0)
        for key in ('q.position','q.movement_direction'):
            if key not in normalized: raise ValueError('Harness must supply '+key)
            value=normalized[key]
            if not callable(value):
                if len(value)!=3: raise ValueError(key+' requires xyz length 3')
                normalized[key]=lambda axis,vector=tuple(value):vector[int(axis)]
        if 'q.head_y_rotation' not in normalized:
            raise ValueError('Harness must supply q.head_y_rotation')
        head=normalized['q.head_y_rotation']
        if not callable(head): normalized['q.head_y_rotation']=lambda axis=0,value=float(head):value
        normalized['q.life_time']=float(normalized.get('q.life_time',life+dt))
        normalized['q.delta_time']=float(dt)
        return normalized

    def _validate_profile(self,query):
        if not query['q.is_alive'] or not query['q.is_on_ground']:
            raise ValueError('SourceSimulation supports alive ordinary ground only')
        if not query['q.is_local_player']:
            raise ValueError('Remote entity motion is outside the audited local harness')
        for key in ('q.is_in_ui','q.is_paperdoll','q.is_first_person','q.has_cape',
                    'q.is_riding','q.is_sneaking','q.is_swimming','q.is_crawling',
                    'q.is_gliding','q.blocking','q.main_hand_item_use_duration',
                    'q.item_is_charged'):
            if query[key]: raise ValueError('Excluded source profile query '+key)
        if query['q.vertical_speed']:
            raise ValueError('Vertical movement is outside the ordinary ground profile')
        for key in _EXCLUDED_FLAGS:
            if self.env.get(key,0): raise ValueError('Excluded source profile flag '+key)
        if self.env.get('v.tnlxsa')!=2:
            raise ValueError('Only normal player tnlxsa=2 profile is supported')

    def step(self,query,dt):
        dt=float(dt)
        if not math.isfinite(dt) or dt<=0 or dt>1/6:
            raise ValueError('dt must be finite in (0,1/6] for audited Euler smoothing')
        q=self._queries(query,self.life,dt)
        if q['q.life_time']<self.life or not math.isfinite(q['q.life_time']):
            raise ValueError('Query life_time must be finite and nondecreasing')
        self._validate_profile(q)
        # pre_animation22 maintains this alive timer before the sampled trio.
        self.env['v.qlczor']+=dt
        for key in list(self.env):
            if key.startswith(('q.','t.')): del self.env[key]
        self.env.update(q)
        self.life=q['q.life_time']
        for program in self.programs: self.molang.eval(program)
        self._validate_profile(q)
        # Advance a previous crossfade, then process one ordered transition.
        if self._blend_duration:
            self._blend_elapsed=min(self._blend_duration,self._blend_elapsed+dt)
            alpha=self._blend_elapsed/self._blend_duration
            self.run_weight=self._blend_from+(self._blend_to-self._blend_from)*alpha
        self.state_time=round(self.state_time+dt,14)
        self.env['q.state_time']=self.state_time
        state_record=self.controller['states'][self.state]
        for transition in state_record.get('transitions',[]):
            destination,expression=next(iter(transition.items()))
            if self.molang.eval(expression):
                if destination not in ('onccai','run'):
                    raise ValueError('Ground profile attempted excluded source state '+destination)
                duration=float(state_record.get('blend_transition',0.0))
                self._blend_from=self.run_weight
                self._blend_to=float(destination=='run')
                self._blend_duration=duration
                self._blend_elapsed=0.0
                if not duration: self.run_weight=self._blend_to
                self.state=destination
                self.state_time=0.0
                self.env['q.state_time']=0.0
                break
        current=self.controller['states'][self.state]
        weights={}
        for animation in current.get('animations',[]):
            if isinstance(animation,dict):
                alias,expression=next(iter(animation.items()))
                weights[alias]=self.molang.eval(expression)
            else: weights[animation]=1.0
        variables={k:copy.deepcopy(v) for k,v in self.env.items() if k.startswith('v.')}
        return {'vars':variables,'phase':variables['v.eqhdel'],
                'phase01':variables.get('v.ifcvde',variables['v.eqhdel']%1),
                'life':self.life,'run_weight':self.run_weight,
                'controllerstate':self.state,'state':self.state,
                'state_time':self.state_time,'cadence':1.6*math.sqrt(max(0,variables['v.njrdop'])),
                'raw_weights':weights,'query':dict(q),
                'profile':'ordinary_ground_local_third_person_tnlxsa2'}
