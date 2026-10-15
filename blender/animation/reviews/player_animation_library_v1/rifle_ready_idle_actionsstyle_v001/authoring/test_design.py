import unittest,math
from motion_design import motion,path,HEAD,TORSO,PERIOD
class Design(unittest.TestCase):
 def test_loop_and_boundary(self):
  for t in [0,.3,1.3,4.3,7.99]:
   for k,v in motion(t).items():self.assertAlmostEqual(v,motion(t+PERIOD)[k],places=9)
  self.assertTrue(all(abs(v)<1e-8 for v in motion(0).values()))
 def test_head_leads(self):
  self.assertGreater(motion(.86)['head'],.5);self.assertEqual(motion(.86)['torso'],0)
  self.assertLess(motion(3.73)['head'],-.5);self.assertEqual(motion(3.73)['torso'],0)
 def test_unequal_observation_holds(self):
  self.assertEqual(motion(1.3)['head'],motion(1.9)['head']);self.assertEqual(motion(4.2)['head'],motion(4.6)['head'])
  self.assertNotEqual(abs(motion(1.5)['head']),abs(motion(4.4)['head']))
 def test_boundary_velocity(self):
  for k in motion(0):
   self.assertLess(abs((motion(.0001)[k]-motion(-.0001)[k])/.0002),.001)
 def test_original_bounded_channels(self):
  for i in range(2401):
   m=motion(i/300);self.assertLessEqual(abs(m['head']),25);self.assertLessEqual(abs(m['torso']),4);self.assertLessEqual(m['drop'],.065);self.assertLessEqual(abs(m['weight']),.006)
if __name__=='__main__':unittest.main()
