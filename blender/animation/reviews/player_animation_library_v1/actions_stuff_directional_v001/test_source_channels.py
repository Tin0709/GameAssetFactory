"""Independent literal-source checks for the private directional study adapter."""
import math
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


class SourceChannelTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue((HERE / 'source_channels.py').exists(), 'source channel adapter must exist')
        from source_channels import SourceChannels
        self.source = SourceChannels(HERE / 'source_payload.json')

    def snap(self, phase=0, forward=1, lateral=0, run=0, speed=1, life=0):
        return {'phase': phase, 'life': life, 'run_weight': run,
                'vars': {'v.cknrcn': forward, 'v.mrmeib': lateral, 'v.esnrkj': speed,
                         'v.nthjcy': 0, 'v.upxhvv': 0, 'v.wyuvst': 0, 'v.bdjsdw': 0},
                'query': {'q.is_in_ui': 0, 'q.body_y_rotation': 0, 'q.target_x_rotation': 0}}

    def test_authored_walk_forward_literal_keys(self):
        c = self.source.directional(self.snap(phase=.2222), 'walk')
        self.assertEqual(c['leftleg']['rotation'], [-39., 0., 0.])
        self.assertEqual(c['leftleg']['position'], [0., -2.1, -.6])
        self.assertAlmostEqual(c['rightarm']['rotation'][0], -math.sin(math.radians(.2222*360))*37.2+1.6)

    def test_authored_backward_and_sideways_are_distinct(self):
        back = self.source.directional(self.snap(phase=.2222, forward=-1), 'walk')
        side = self.source.directional(self.snap(phase=.2222, forward=0, lateral=1), 'walk')
        self.assertEqual(back['leftleg']['rotation'], [43., 0., 0.])
        self.assertEqual(side['leftleg']['rotation'], [-3.75, 0., 29.25])
        self.assertEqual(self.source.last_metadata['raw_weights'], {'forward': -.25, 'right': .75, 'left': -1.25, 'backward': -.25})

    def test_run_scale_and_side_waist_degree_atan(self):
        c = self.source.directional(self.snap(phase=.2188, forward=0, lateral=1), 'run')
        self.assertAlmostEqual(c['rightleg']['scale'][1], 1 + .75*.07)
        c = self.source.directional(self.snap(phase=.125, forward=0, lateral=1), 'run')
        # cos(90 degrees) is numerically near zero: source downward branch near0.
        self.assertAlmostEqual(c['waist']['position'][1], 0, places=12)
        c = self.source.directional(self.snap(phase=.25, forward=0, lateral=1), 'run')
        self.assertAlmostEqual(c['waist']['position'][1], math.degrees(math.atan(2))*.0125*.75)

    def test_loop_seam_is_not_silently_closed(self):
        a = self.source.directional(self.snap(phase=0, forward=0, lateral=1), 'walk')
        b = self.source.directional(self.snap(phase=1, forward=0, lateral=1), 'walk')
        self.assertAlmostEqual(a['leftleg']['position'][0], .078*.75)
        self.assertAlmostEqual(b['leftleg']['position'][0], 0)

    def test_runtime_unbounded_clock_wraps_all_channels_together(self):
        expected = self.source.sample(self.snap(phase=.7083, run=1), extras=False)
        actual = self.source.sample(self.snap(phase=3.7083, run=1), extras=False)
        for bone in expected:
            for channel in expected[bone]:
                for a, b in zip(actual[bone][channel], expected[bone][channel]):
                    self.assertAlmostEqual(a, b, places=11)

    def test_core_run_matches_literal_accepted_profile(self):
        c = self.source.sample(self.snap(phase=.7083, run=1), extras=False)
        self.assertEqual(c['rightleg']['rotation'], [-26.62, 0., 0.])
        self.assertEqual(c['leftleg']['scale'], [1., 1.07, 1.])
        self.assertEqual(c['root']['rotation'], [0., 0., 0.])

    def test_full_walk_has_actual_bob_root_head_and_holding(self):
        s = self.snap(phase=.25)
        s['vars'].update({'v.nthjcy': 50, 'v.upxhvv': .2, 'v.wyuvst': 12})
        s['query'].update({'q.body_y_rotation': 20, 'q.target_x_rotation': 7})
        c = self.source.sample(s)
        self.assertEqual(c['root']['rotation'], [0., 30., 0.])
        self.assertAlmostEqual(c['waist']['rotation'][1], -4.5)
        self.assertAlmostEqual(c['rightarm']['rotation'][0], (-37.2+1.6)*.5)
        self.assertAlmostEqual(c['leftarm']['rotation'][0], 37.2+1.6)
        self.assertAlmostEqual(c['head']['rotation'][0], 1.)
        self.assertAlmostEqual(c['head']['rotation'][1], math.sin(math.radians(130))*3 + math.sqrt(.5) + 42)
        self.assertTrue(self.source.last_metadata['head_relative_to_entity'])
        self.assertIn('bob', [x['alias'] for x in self.source.last_metadata['layers']])

    def test_run_bank_is_source_only_and_sprint_is_settled(self):
        s = self.snap(run=1)
        s['vars']['v.bdjsdw'] = 48
        c = self.source.sample(s)
        self.assertAlmostEqual(c['root']['rotation'][2], -1.44)
        self.assertEqual(c['waist']['rotation'][0], 5)
        self.assertEqual(self.source.last_metadata['sprint_clock_s'], 2)
        self.assertFalse(any(c.get('override_previous_animation', False) for c in self.source.clips.values()))


if __name__ == '__main__':
    unittest.main()
