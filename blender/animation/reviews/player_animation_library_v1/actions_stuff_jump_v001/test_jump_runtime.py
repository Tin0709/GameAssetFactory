import unittest
from pathlib import Path
from jump_runtime import JumpRuntime, JumpChannels
P=Path(__file__).parent/'jump_source_payload.json'
def query(ground=True, vertical=0, sprint=False, jump=False, pos=(0,0,0)):
 return {'position':pos,'movement_direction':(0,0,1),'head_y_rotation':0,'is_on_ground':ground,'vertical_speed':vertical,'is_sprinting':sprint,'is_jumping':jump}
class ChannelTests(unittest.TestCase):
 def setUp(self):self.c=JumpChannels(P)
 def test_source_keys(self):
  p=self.c.sample_clip('jump',.125)
  self.assertEqual(p['head']['rotation'],[25.,0.,0.]);self.assertEqual(p['leftleg']['scale'],[1.,1.2,1.])
  self.assertEqual(self.c.sample_clip('wxzmsp',.0833)['root']['position'],[0.,-4.,0.])
  self.assertEqual(self.c.sample_clip('srluww',.125)['waist']['position'],[0.,-2.4,0.])
 def test_catmull(self):
  self.assertAlmostEqual(self.c.catmull(0,1,3,4,.5),2)
  p=self.c.sample_clip('jump',.1875)['leftleg']['rotation'][0]
  self.assertGreater(p,0);self.assertLess(p,8)
 def test_every_authored_key(self):
  from molang import Molang
  for alias in ['jump','wxzmsp','rnmred','fall','ydsari','srluww']:
   clip=self.c.clips[self.c.aliases[alias]]
   for bone,channels in clip['bones'].items():
    if bone not in ['root','waist','body','head','rightarm','leftarm','rightleg','leftleg']:continue
    for channel,keys in channels.items():
     if not isinstance(keys,dict):continue
     for timestamp,record in keys.items():
      expected=self.c._vector(record,Molang({}))
      self.assertEqual(self.c.sample_clip(alias,float(timestamp))[bone][channel],expected,(alias,bone,channel,timestamp))
 def test_hold_and_finite(self):
  self.assertEqual(self.c.sample_clip('fall',20)['root']['position'],[0.,-4.,0.])
class RuntimeTests(unittest.TestCase):
 def setUp(self):self.r=JumpRuntime(P)
 def step(self,**kw):return self.r.step(1/120,query(**kw))
 def test_ordinary_and_landing(self):
  self.step();s=self.step(ground=False,vertical=8,jump=True)
  self.assertEqual(s['controllers']['ngeixo']['state'],'jump')
  self.assertEqual(s['controllers']['pyhwuc']['state'],'zhbjho')
  s=self.step(ground=True);self.assertEqual(s['controllers']['pyhwuc']['state'],'yytrhz')
  self.assertTrue(any(x['alias']=='ydsari' and x['controller_weight']==.8 for x in s['layers']))
 def test_sprint_variants_and_phase_override(self):
  for phase,state,override in [(.2,'ypqtmb',.05),(.8,'seridw',.55)]:
   r=JumpRuntime(P);r.env['v.eqhdel']=phase;r.step(1/120,query())
   s=r.step(1/120,query(ground=False,vertical=8,sprint=True,jump=True))
   self.assertEqual(s['controllers']['ngeixo']['state'],state)
   s=r.step(1/120,query());self.assertEqual(s['vars']['v.gadjrq'],override)
   s=r.step(1/120,query());self.assertEqual(s['phase'],override)
 def test_airborne_threshold_and_fall(self):
  self.step()
  for i in range(7):s=self.step(ground=False,vertical=0)
  self.assertEqual(s['controllers']['veywgp']['state'],'zhbjho')
  s=self.step(ground=False,vertical=-.16);self.assertEqual(s['controllers']['muiqdc']['state'],'nqtrjo')
 def test_sprint_stop_on_landing_even_still_sprinting(self):
  self.step(sprint=True);self.step(ground=False,vertical=8,sprint=True,jump=True)
  s=self.step(ground=True,sprint=True);self.assertEqual(s['controllers']['psowex']['state'],'stop')
  self.assertTrue(any(x['alias']=='sjvffv' for x in s['layers']))
 def test_moving_landing_and_fall_overlap(self):
  for i in range(120):self.r.step(1/120,query(pos=(0,0,(i+1)*4.3/120)))
  self.r.step(1/120,query(ground=False,vertical=8,jump=True,pos=(0,.05,4.3)))
  s=self.r.step(1/120,query(ground=False,vertical=-1,pos=(0,.04,4.3)))
  self.assertTrue(any(x['alias']=='jump' for x in s['layers']))
  self.assertTrue(any(x['alias']=='fall' for x in s['layers']))
  s=self.r.step(1/120,query(pos=(0,0,4.31)))
  self.assertEqual(s['controllers']['pyhwuc']['state'],'cfpejq')
  self.assertTrue(any(x['alias']=='srluww' for x in s['layers']))
 def test_exact_inclusive_sprint_boundaries(self):
  for phase,state in [(.1,'ypqtmb'),(.6,'ypqtmb'),(.099,'seridw'),(.601,'seridw')]:
   r=JumpRuntime(P);r.env['v.eqhdel']=phase
   r.step(1/120,query())
   s=r.step(1/120,query(ground=False,vertical=8,sprint=True,jump=True))
   self.assertEqual(s['controllers']['ngeixo']['state'],state)
 def test_repeated_sprint_alternates(self):
  self.r.env['v.eqhdel']=.2;self.step()
  s=self.step(ground=False,vertical=8,sprint=True,jump=True)
  self.assertEqual(s['controllers']['ngeixo']['state'],'ypqtmb')
  self.step();s=self.step(ground=False,vertical=8,sprint=True,jump=True)
  self.assertEqual(s['controllers']['ngeixo']['state'],'seridw')
 def test_monotonic_life(self):
  q=query();q['life_time']=1.
  with self.assertRaises(ValueError):self.r.step(1/240,q)
  q['life_time']=float('nan')
  with self.assertRaises(ValueError):self.r.step(1/240,q)
 def test_reject_specials(self):
  q=query();q['is_in_water']=True
  with self.assertRaises(ValueError):self.r.step(1/120,q)
if __name__=='__main__':unittest.main()
