"""Behavior checks for the private ordinary-player Idle reconstruction."""
import math
from pathlib import Path
import unittest
from idle_runtime import IdleRuntime, idle_query

DT=1/120

def advance(runtime, seconds, **changes):
    frames=[]
    for _ in range(round(seconds/DT)):
        frames.append(runtime.step(DT,idle_query(**changes)))
    return frames

class IdleTests(unittest.TestCase):
    def test_ever_moved_gate_blocks_spawn_idle(self):
        r=IdleRuntime(initial_life=0,seed=2,modified_distance_moved=0)
        frames=advance(r,16)
        self.assertTrue(all(s['controllers']['bjmscc']['state']=='uwpoku' for s in frames))
        self.assertEqual(r.random_draws,[])

    def test_recent_attack_blocks_until_ten_then_three_quiet_seconds(self):
        r=IdleRuntime(initial_life=0,seed=2,modified_distance_moved=1)
        first=None
        for i in range(1800):
            s=r.step(DT,idle_query())
            if s['controllers']['bjmscc']['state']=='tculwn':
                first=(i+1)*DT;break
        self.assertIsNotNone(first)
        self.assertGreater(first,13)
        self.assertLess(first,13.1)

    def test_seeded_relaxed_natural_gesture_and_fade(self):
        r=IdleRuntime.relaxed(seed=2)
        frames=advance(r,9)
        active=[(i*DT,s) for i,s in enumerate(frames) if s['controllers']['bjmscc']['state']=='tculwn']
        self.assertGreater(active[0][0],3)
        self.assertLess(active[0][0],3.1)
        self.assertEqual(r.random_draws[0]['value'],1)
        self.assertGreater(active[-1][0]-active[0][0],4.19)
        fade=[s for s in frames if s['controllers']['bjmscc']['state']=='bhsawv' and any(l['alias']=='tculwn' and 0<l['state_weight']<1 for l in s['layers'])]
        self.assertTrue(fade)
        self.assertEqual(frames[-1]['controllers']['bjmscc']['state'],'wkbbnc')
        self.assertEqual(frames[-1]['vars']['v.xrtrow'],0)
        self.assertEqual(frames[-1]['vars']['v.tnlxsa'],0)
        self.assertEqual(frames[-1]['vars']['v.vbcdda'],0)
        aliases=[l['alias'] for l in active[120][1]['layers']]
        self.assertLess(aliases.index('bob'),aliases.index('look_at_target'))
        self.assertLess(aliases.index('look_at_target'),aliases.index('tculwn'))
        self.assertNotEqual(active[120][1]['channels']['body']['rotation'][1],0)

    def test_head_interrupt_uses_literal_controller_and_fades(self):
        r=IdleRuntime.relaxed(seed=2);advance(r,4)
        s=r.step(DT,idle_query(head_y_rotation=25))
        self.assertEqual(s['controllers']['bjmscc']['state'],'bhsawv')
        self.assertEqual(s['vars']['v.xrtrow'],0)
        self.assertTrue(any(l['alias']=='tculwn' and l['controller_weight']>0 for l in s['layers']))
        s=advance(r,.25,head_y_rotation=25)[-1]
        self.assertFalse(any(l['alias']=='tculwn' for l in s['layers']))

    def test_motion_interrupts_idle_and_walk_body_returns(self):
        r=IdleRuntime.relaxed(seed=2);advance(r,4)
        s=r.step(DT,idle_query(position=(0,0,.035),ground_speed=4.3))
        self.assertEqual(s['controllers']['bjmscc']['state'],'bhsawv')
        for i in range(60):
            s=r.step(DT,idle_query(position=(0,0,.035+(i+1)*4.3*DT),ground_speed=4.3))
        self.assertTrue(any(l['alias']=='move' and l['applied_weight']>0 for l in s['layers']))

    def test_ambient_loop_follows_lifetime_and_has_literal_amplitude(self):
        r=IdleRuntime(initial_life=0,seed=2,modified_distance_moved=0)
        s=r.step(DT,idle_query(life_time=144/49))
        self.assertAlmostEqual(s['channels']['waist']['position'][0],0,places=8)
        self.assertAlmostEqual(s['channels']['waist']['rotation'][2],-1,places=8)
        self.assertAlmostEqual(s['channels']['leftarm']['rotation'][2],-1.15,places=8)
        self.assertEqual(s['channels']['body']['scale'],[1,1,1])

    def test_attack_during_gesture_resets_recent_gate(self):
        r=IdleRuntime.relaxed(seed=2);advance(r,4)
        s=r.step(DT,idle_query(attack_time=.1))
        self.assertEqual(s['vars']['v.txtwqb'],0)
        self.assertEqual(s['controllers']['bjmscc']['state'],'bhsawv')
        self.assertEqual(s['vars']['v.nwocdu'],1)

    def test_primary_trace_is_serializable_and_nine_seconds(self):
        import json
        from idle_runtime import sample_primary
        rows=sample_primary(duration=9,hz=120)
        self.assertEqual(len(rows),1081)
        self.assertEqual(rows[0]['time_s'],0)
        self.assertEqual(rows[-1]['time_s'],9)
        self.assertAlmostEqual(rows[0]['life'],12+1/120)
        self.assertEqual(rows[0]['query']['q.position'],[0,0,0])
        json.dumps(rows,allow_nan=False)

    def test_literal_tculwn_body_keys_and_cancel_layer(self):
        from idle_runtime import IdleChannels, DEFAULT_PAYLOAD
        from source_channels import _neutral
        c=IdleChannels(DEFAULT_PAYLOAD)
        self.assertEqual(c.sample_clip('tculwn',.2917)['body']['rotation'],[0,-6,0])
        self.assertEqual(c.sample_clip('tculwn',1.25)['body']['rotation'],[0,8,0])
        self.assertEqual(c.sample_clip('tculwn',1.0833)['leftleg']['rotation'],[0,0,-5])
        out=_neutral();out['head']['rotation']=[25,10,-3]
        out['rightarm']['rotation']=[20,15,-2]
        c._add_clip(out,'vrkauw',{},.25,1)
        self.assertEqual(out['head']['rotation'],[0,10,-3])
        self.assertEqual(out['rightarm']['rotation'],[0,0,0])

    def test_invalid_specials_fail_closed(self):
        r=IdleRuntime.relaxed()
        with self.assertRaises(ValueError):r.step(DT,idle_query(is_sneaking=1))
        with self.assertRaises(ValueError):r.step(DT,idle_query(is_on_ground=0))

if __name__=='__main__':unittest.main()
