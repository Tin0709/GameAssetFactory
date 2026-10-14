"""Literal private source-channel mixer for the directional Blender study.

Declared adapters: nonpositive controller weights are inactive (engine semantics
unverified); no weight normalization; sprint held at2s and weighted by Run state;
standard right-hand holding factor1/left0. Full study includes the actual ordinary
Walk/Run bob, root-yaw and entity-relative head layers. ``directional`` and
``sample(extras=False)`` expose isolated core clips for accepted-profile parity.
No foot locks, phase remaps, closure repairs, smoothing, or synthetic gait curves.
"""
import json
import math
from pathlib import Path
from molang import Molang

BONES = ('root', 'waist', 'body', 'head', 'rightarm', 'leftarm', 'rightleg', 'leftleg')
CHANNELS = ('rotation', 'position', 'scale')
DIRECTION_ALIASES = {
    'walk': ('walk', 'vwyhwm', 'pvgbyg', 'kzuqni'),
    'run': ('move', 'move_right', 'move_left', 'pgnnhd'),
}
DIRECTION_NAMES = ('forward', 'right', 'left', 'backward')


def _get(snapshot, name, default=None):
    return snapshot.get(name, default) if isinstance(snapshot, dict) else getattr(snapshot, name, default)


def _neutral():
    return {bone: {channel: [1., 1., 1.] if channel == 'scale' else [0., 0., 0.]
                   for channel in CHANNELS} for bone in BONES}


class SourceChannels:
    def __init__(self, payload_path):
        self.payload = json.loads(Path(payload_path).read_text())
        self.clips = self.payload['clips']
        self.aliases = self.payload['player']['animations']
        self.controller = self.payload['controllers'][self.aliases['veywgp']]
        self.last_metadata = {}
        for aliases in DIRECTION_ALIASES.values():
            for alias in aliases:
                clip = self.clips[self.aliases[alias]]
                if clip.get('override_previous_animation'):
                    raise ValueError('Directional source unexpectedly overrides preceding animation')
                if clip.get('anim_time_update') != 'v.eqhdel' or clip.get('animation_length') != 1:
                    raise ValueError('Directional source clock/range mismatch')

    def _environment(self, snapshot, clock=None):
        env = {}
        for prefix, field in [('v', 'vars'), ('q', 'query')]:
            for key, value in (_get(snapshot, field, {}) or {}).items():
                full = key if key.startswith(prefix + '.') else prefix + '.' + key
                env[full] = value
        env['q.anim_time'] = float(_get(snapshot, 'phase', 0) if clock is None else clock)
        env['q.life_time'] = float(_get(snapshot, 'life', 0))
        env.setdefault('q.state_time', float(_get(snapshot, 'state_time', 0)))
        env.setdefault('q.is_in_ui', 0)
        env.setdefault('q.body_y_rotation', 0)
        env.setdefault('q.target_x_rotation', 0)
        return env

    def _vector(self, value, evaluator, side='post'):
        if isinstance(value, dict):
            value = value.get(side, value.get('post', value.get('pre')))
        if not isinstance(value, list):
            value = [value] * 3
        if len(value) == 1:
            value = value * 3
        if len(value) != 3:
            raise ValueError('Expected literal three-component source channel')
        return [float(evaluator.eval(component)) if isinstance(component, str) else float(component)
                for component in value]

    def _channel(self, clip, bone, channel, clock, evaluator):
        value = clip.get('bones', {}).get(bone, {}).get(channel,
                [1., 1., 1.] if channel == 'scale' else [0., 0., 0.])
        if not isinstance(value, dict):
            return self._vector(value, evaluator)
        keys = sorted((float(time), vector) for time, vector in value.items())
        if clock <= keys[0][0]:
            return self._vector(keys[0][1], evaluator, 'pre')
        if clock >= keys[-1][0]:
            return self._vector(keys[-1][1], evaluator)
        for (a, av), (b, bv) in zip(keys, keys[1:]):
            if a <= clock < b:
                if (isinstance(av, dict) and av.get('lerp_mode') == 'catmullrom' or
                        isinstance(bv, dict) and bv.get('lerp_mode') == 'catmullrom'):
                    raise ValueError('Transient Catmull-Rom is outside the held-sprint study profile')
                x = self._vector(av, evaluator)
                y = self._vector(bv, evaluator, 'pre')
                w = (clock-a)/(b-a)
                return [u + (v-u)*w for u, v in zip(x, y)]
        raise AssertionError(clock)

    def _add_clip(self, output, alias, env, clock, controller_weight=1.):
        clip = self.clips[self.aliases[alias]]
        env = dict(env)
        env['q.anim_time'] = clock
        evaluator = Molang(env)
        own_weight = float(evaluator.eval(clip.get('blend_weight', 1)))
        weight = max(0., float(controller_weight)) * max(0., own_weight)
        if clip.get('override_previous_animation'):
            raise ValueError('Profile cannot silently apply an overriding source layer')
        if weight:
            for bone in BONES:
                for channel in CHANNELS:
                    # ``this`` in holding is the already accumulated same-axis
                    # channel, not time or the source key's raw component.
                    literal = clip.get('bones', {}).get(bone, {}).get(channel)
                    if isinstance(literal, list) and any(isinstance(v, str) and 'this' in v for v in literal):
                        values = []
                        for axis, component in enumerate(literal):
                            env['this'] = output[bone][channel][axis]
                            values.append(float(Molang(env).eval(component)) if isinstance(component, str) else float(component))
                    else:
                        values = self._channel(clip, bone, channel, clock, evaluator)
                    identity = 1. if channel == 'scale' else 0.
                    for axis, value in enumerate(values):
                        output[bone][channel][axis] += weight*(value-identity)
        return {'alias': alias, 'id': self.aliases[alias], 'controller_weight': controller_weight,
                'clip_weight': own_weight, 'applied_weight': weight, 'clock': clock}

    def _directional(self, snapshot, mode, clock=None):
        if mode not in DIRECTION_ALIASES:
            raise ValueError('Mode must be walk or run')
        clock = float(_get(snapshot, 'phase', 0) if clock is None else clock)
        env = self._environment(snapshot, clock)
        state = self.controller['states']['onccai' if mode == 'walk' else 'run']
        expressions = {alias: expr for row in state['animations'] if isinstance(row, dict)
                       for alias, expr in row.items()}
        out = _neutral()
        layers = []
        raw = {}
        applied = {}
        evaluator = Molang(env)
        for name, alias in zip(DIRECTION_NAMES, DIRECTION_ALIASES[mode]):
            raw[name] = float(evaluator.eval(expressions[alias]))
            layer = self._add_clip(out, alias, env, clock, raw[name])
            applied[name] = layer['applied_weight']
            layers.append(layer)
        return out, {'mode': mode, 'raw_weights': raw, 'applied_weights': applied, 'layers': layers,
                     'negative_weight_adapter': 'max(0,raw); no normalization; engine semantics unverified',
                     'head_relative_to_entity': False, 'phase': clock}

    @staticmethod
    def _check(output):
        for bone, channels in output.items():
            for channel, values in channels.items():
                if any(not math.isfinite(v) for v in values):
                    raise ValueError('Nonfinite source channel: ' + bone + '.' + channel)
                # Numerical explosion guard, not an artistic deformation clamp.
                if channel == 'scale' and any(abs(v) > 100 for v in values):
                    raise ValueError('Unbounded source scale: ' + bone)
        return output

    def directional(self, snapshot, mode):
        # Audit API accepts literal phase1 so an authored endpoint remains
        # inspectable. Runtime sample below always uses animation-local modulo.
        out, self.last_metadata = self._directional(snapshot, mode.lower())
        return self._check(out)

    def sample(self, snapshot, extras=True):
        run = float(_get(snapshot, 'run_weight', 0))
        if not math.isfinite(run) or not 0 <= run <= 1:
            raise ValueError('Controller run_weight must be in [0,1]')
        unbounded = float(_get(snapshot, 'phase', 0))
        p = unbounded % 1.
        walk, wm = self._directional(snapshot, 'walk', p)
        running, rm = self._directional(snapshot, 'run', p)
        out = {bone: {channel: [(1-run)*a+run*b for a, b in zip(walk[bone][channel], running[bone][channel])]
                      for channel in CHANNELS} for bone in BONES}
        metadata = {'phase': p, 'unbounded_phase': unbounded, 'run_weight': run,
                    'core': {'walk': wm, 'run': rm}, 'layers': [],
                    'head_relative_to_entity': bool(extras),
                    'negative_weight_adapter': wm['negative_weight_adapter'], 'extras': bool(extras)}
        if extras:
            env = self._environment(snapshot, p)
            layers = metadata['layers']
            layers.append(self._add_clip(out, 'xfltzh', env, p))
            layers.append(self._add_clip(out, 'hxfxxu', env, p, run*float(env.get('v.esnrkj', 0))))
            layers.append(self._add_clip(out, 'xahrzd', env, 2., run))
            layers.append(self._add_clip(out, 'bob', env, p))
            # Literal kcexxa/njvelc ordinary default and ssulqn both apply bob
            # then holding; steady standard-item profile agrees with accepted Run.
            env['v.vbcdda'] = 1.
            env['v.wfyvyl'] = 0.
            layers.append(self._add_clip(out, 'holding', env, p))
            layers.append(self._add_clip(out, 'look_at_target', env, p))
            metadata['sprint_clock_s'] = 2.
            metadata['holding_profile'] = {'right': 1., 'left': 0., 'blend_weight': .5,
                                           'adapter': 'steady standard item; transient holding flags omitted'}
            metadata['bob_source_chain'] = 'rzkmtm.default > okjrob.eryuvy > kcexxa.default/ssulqn: bob weight1 then holding'
            metadata['sprint_adapter'] = 'settled ucaryc endpoint at2s weighted by Run state; sprint onset omitted'
        self.last_metadata = metadata
        return self._check(out)
