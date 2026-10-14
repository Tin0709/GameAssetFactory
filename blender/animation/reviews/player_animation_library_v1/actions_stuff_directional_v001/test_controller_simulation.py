"""Regression breaks: radians, eager branches, lost phase, wrong source ordering/dwell."""
import importlib.util
import json
import math
from pathlib import Path
import sys
import unittest

MODULES = Path(__file__).resolve().parent
sys.path.insert(0, str(MODULES))
try:
    from molang import Molang, MolangError
    from source_simulation import SourceSimulation
except ImportError:
    Molang = SourceSimulation = None
    MolangError = ValueError

AUDIT = Path(__file__).parent

class MolangTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(Molang, 'Molang evaluator is not implemented')
        self.env = {'q.pick': lambda axis: (2, 3, 5)[int(axis)]}
        self.m = Molang(self.env)

    def test_degree_trig_and_wrap(self):
        self.assertAlmostEqual(self.m.eval('Math.sin(90)+Math.cos(180)+Math.atan(1)'), 45)
        self.assertAlmostEqual(self.m.eval('math.min_angle(370)'), 10)
        self.assertAlmostEqual(self.m.eval('math.min_angle(-350)'), 10)
        self.assertAlmostEqual(self.m.eval('q.pick(2)*2+Math.pow(3,2)'), 19)

    def test_lazy_ternary_missing_else_and_program_assignments(self):
        self.m.eval('v.a=4;v.y=0;v.a>0?{v.y=6;v.a=v.a+1;}:v.no_such();')
        self.assertEqual(self.env['v.a'], 5)
        self.assertEqual(self.env['v.y'], 6)
        self.assertEqual(self.m.eval('v.a<0?99'), 0)
        self.assertEqual(self.m.eval('v.a==5?7:8'), 7)
        self.assertEqual(self.m.eval('v.a=0;return v.a?12:3;'), 3)
        self.assertEqual(self.m.eval('0&&v.unsupported()'), 0)
        self.assertEqual(self.m.eval('1||v.unsupported()'), 1)

    def test_fail_closed_and_molang_numeric_zero(self):
        with self.assertRaises(MolangError): self.m.eval('Math.unimplemented(1)')
        with self.assertRaises(MolangError): self.m.eval('v.a @ 3')
        with self.assertRaises(MolangError): self.m.eval('q.absent(0)')
        self.assertEqual(self.m.eval('0/0'), 0)
        self.assertEqual(self.m.eval('v.never_initialized'), 0)

class SimulationTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(SourceSimulation, 'SourceSimulation is not implemented')
        self.path = MODULES/'source_payload.json'
        self.sim = SourceSimulation(self.path, initial_life=1.0)

    def q(self, x, z, dx, dz, life):
        return {'q.position': lambda axis: (x,0,z)[int(axis)],
                'q.movement_direction': lambda axis: (dx,0,dz)[int(axis)],
                'q.head_y_rotation': lambda axis: 0,
                'q.life_time': life, 'q.is_local_player':1, 'q.is_on_ground':1,
                'q.is_alive':1, 'q.vertical_speed':0}

    def test_source_order_phase_and_180_continuity(self):
        # Warm speed/direction but source29 still observes old lateral=0 this frame.
        self.sim.env.update({'v.esnrkj':1,'v.lzwweo':4.3,'v.cknrcn':1,
                             'v.sfdeke':1,'v.mrmeib':0,'v.nqexps':0})
        first=self.sim.step(self.q(0,0,1,0,1),.01)
        self.assertAlmostEqual(first['phase'],.016)
        self.assertAlmostEqual(first['vars']['v.mrmeib'],0)
        self.assertAlmostEqual(first['vars']['v.nqexps'],-1)
        second=self.sim.step(self.q(.043,0,1,0,1.01),.01)
        self.assertAlmostEqual(second['vars']['v.mrmeib'],-.08)
        before=second['phase']
        third=self.sim.step(self.q(.0,0,-1,0,1.02),.01)
        self.assertGreater(third['phase'],before)
        self.assertLess(third['phase']-before,.02)
        self.assertEqual(first['query']['q.life_time'],1)

    def test_state_dwell_hysteresis_and_linear_crossfade(self):
        self.sim.env.update({'v.esnrkj':1,'v.lzwweo':4.3,'v.cknrcn':1,'v.sfdeke':1})
        out=None
        for i in range(20):
            out=self.sim.step(self.q(i*.043,0,0,1,1+i*.01),.01)
        self.assertEqual(out['controllerstate'],'onccai')
        out=self.sim.step(self.q(.86,0,0,1,1.2),.01)
        self.assertEqual(out['controllerstate'],'run')
        self.assertAlmostEqual(out['run_weight'],0)
        for i in range(11):
            out=self.sim.step(self.q(.903+i*.043,0,0,1,1.21+i*.01),.01)
        self.assertAlmostEqual(out['run_weight'],.5)
        self.assertGreater(out['phase'],.4)

    def test_travel_facing_branch_preserves_authored_update_order(self):
        self.sim.env.update({'v.esnrkj':1,'v.lzwweo':4.3,'v.cknrcn':1,
                             'v.sfdeke':1,'v.nqexps':1,'v.txtwqb':11})
        first=self.sim.step(self.q(0,0,-1,0,1),.01)
        self.assertAlmostEqual(first['vars']['v.upxhvv'],.06)
        self.assertAlmostEqual(first['vars']['v.nthjcy'],0)
        self.assertAlmostEqual(first['vars']['v.mrmeib'],0)
        second=self.sim.step(self.q(-.043,0,-1,0,1.01),.01)
        self.assertAlmostEqual(second['vars']['v.nthjcy'],5.4)
        self.assertAlmostEqual(second['vars']['v.upxhvv'],.1164)

    def test_excluded_air_profile_fails_explicitly(self):
        q=self.q(0,0,0,1,1);q['q.is_on_ground']=0
        with self.assertRaises(ValueError): self.sim.step(q,.01)

if __name__=='__main__': unittest.main()
