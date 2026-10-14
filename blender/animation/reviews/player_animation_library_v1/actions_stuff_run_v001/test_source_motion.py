import unittest,math
from source_motion import *
class SourceChannels(unittest.TestCase):
 def test_original_rotation_and_linear_interpolation(self):
  self.assertEqual(channel(RUN,'rightleg','rotation',.4167)[0],71.05)
  self.assertAlmostEqual(channel(RUN,'rightleg','rotation',.125)[0],15.25)
 def test_original_translation_and_scale(self):
  self.assertEqual(channel(RUN,'rightleg','position',.625),[0,4,-3.25])
  self.assertEqual(channel(RUN,'rightleg','scale',.2083),[1,1.07,1])
  self.assertEqual(channel(RUN,'leftleg','scale',.7083),[1,1.07,1])
 def test_asymmetric_waist(self):
  self.assertAlmostEqual(channel(RUN,'waist','position',0)[1],-3.1)
  self.assertAlmostEqual(channel(RUN,'waist','position',.25)[1],.8)
 def test_source_additive_sprint_and_bob(self):
  self.assertEqual(channels('waist',0)['rotation'],[5.,0.,-6.])
  self.assertAlmostEqual(channels('leftarm',0)['rotation'][1],8.)
  self.assertAlmostEqual(channels('leftarm',0)['rotation'][2],-11.15)
 def test_source_holding_this_modifier(self):
  self.assertAlmostEqual(channels('rightarm',0)['rotation'][0],channel(RUN,'rightarm','rotation',0)[0]*.5)
 def test_independent_bob_clock(self):
  self.assertNotEqual(channels('head',0),channels('head',.625))
  self.assertAlmostEqual(channels('waist',.625,False)['position'][1],-3.1)
 def test_exact_key_times(self):
  self.assertIn(.2083/RATE,source_break_times())
  self.assertIn(1/RATE,source_break_times())
 def test_reject_unimplemented_source_syntax(self):
  with self.assertRaises(ValueError):expression('q.unknown+1',0,0)
if __name__=='__main__':unittest.main()
