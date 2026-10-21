import unittest,math
import expression_model as m

class Expressions(unittest.TestCase):
 def test_required_names(self):
  self.assertEqual(len(m.PRESETS),18)
  for n in ['Neutral_Idle','Blink_Soft','Focused_Aim','Hurt_Heavy','Victory_Small','Death_Stunned']:self.assertIn(n,m.PRESETS)
 def test_all_presets_return_and_bound(self):
  for name,p in m.PRESETS.items():
   for i in range(181):
    c=m.evaluate_preset(name,p['duration']*i/180,auto_blink=False)
    for k,(lo,hi) in m.LIMITS.items():self.assertTrue(math.isfinite(c[k]) and lo-1e-8<=c[k]<=hi+1e-8,(name,k,c[k]))
   end=m.evaluate_preset(name,p['duration'],auto_blink=False)
   for k in m.NEUTRAL:self.assertAlmostEqual(end[k],m.NEUTRAL[k],places=7,msg=(name,k))
 def test_gaze_character_sides_and_down(self):
  self.assertGreater(m.evaluate_preset('Look_Left',.65,False)['gaze_x'],.65)
  self.assertLess(m.evaluate_preset('Look_Right',.65,False)['gaze_x'],-.65)
  self.assertLess(m.evaluate_preset('Look_Down_Short',.5,False)['gaze_y'],-.5)
 def test_blink_deterministic_irregular(self):
  a=m.blink_schedule(25);self.assertEqual(a,m.blink_schedule(25));self.assertGreater(len(set(round(a[i+1]-a[i],2) for i in range(len(a)-1))),2)
  self.assertGreater(m.evaluate_preset('Neutral_Idle',a[0]+.075)['blink_auto'],.9)
  self.assertEqual(m.evaluate_situation('Aim',.6)['gaze_x'],0)
 def test_priority_context_recovery_no_stacking(self):
  events=[{'type':'Hurt_Heavy','time':1.},{'type':'Fire_Recoil_Face','time':1.02}]
  h=m.evaluate_situation('Aim',1.10,events=events,auto_blink=False)
  expected=m.evaluate_situation('Aim',1.10,events=events[:1],auto_blink=False)
  self.assertEqual(h,expected)
  for t in [2.,4.]:self.assertEqual(m.evaluate_situation('Aim',t,events=events,auto_blink=False),m.evaluate_situation('Aim',t,auto_blink=False))
  repeated=[{'type':'Fire_Recoil_Face','time':1.}]*100
  self.assertEqual(m.evaluate_situation('Aim',1.04,events=repeated,auto_blink=False),m.evaluate_situation('Aim',1.04,events=repeated[:1],auto_blink=False))
 def test_zero_intensity_and_low_hp(self):
  c=m.evaluate_preset('Hurt_Heavy',.4,False,intensity=0)
  self.assertEqual(c,m.NEUTRAL)
  c=m.evaluate_situation('Aim',1.,low_hp=1,auto_blink=False)
  self.assertLess(c['open_l'],1.)
 def test_seam_continuity(self):
  for name,p in m.PRESETS.items():
   a=m.evaluate_preset(name,0,False);b=m.evaluate_preset(name,p['duration'],False)
   self.assertEqual(a,b,name)
 def test_situation_and_6hz_recovery(self):
  for state in m.SITUATIONS:
   for i in range(150):
    c=m.evaluate_situation(state,i/30)
    for k,(lo,hi) in m.LIMITS.items():self.assertTrue(lo-1e-6<=c[k]<=hi+1e-6,(state,k,c[k]))
  events=[{'type':'Fire_Recoil_Face','time':i/6} for i in range(120)]
  self.assertEqual(m.evaluate_situation('Aim',21.,events=events,auto_blink=False),m.evaluate_situation('Aim',21.,auto_blink=False))
 def test_priority_onset_and_recovery_are_continuous(self):
  for lower,start in [('Fire_Recoil_Face',1.),('Hurt_Light',1.)]:
   events=[{'type':lower,'time':start},{'type':'Hurt_Heavy','time':1.04}]
   for boundary in [1.04,1.74]:
    a=m.evaluate_situation('Aim',boundary-1e-6,events=events)
    b=m.evaluate_situation('Aim',boundary+1e-6,events=events)
    self.assertLess(max(abs(a[k]-b[k]) for k in a),.0001)
  events=[{'type':'Hurt_Light','time':1.325}]
  a=m.evaluate_situation('Idle',1.325-1e-6,events=events)
  b=m.evaluate_situation('Idle',1.325+1e-6,events=events)
  self.assertLess(max(abs(a[k]-b[k]) for k in a),.0001)
 def test_steady_situation_loop_seams(self):
  for state,duration in m.SITUATIONS.items():
   if state in ['Jump','Landing','Hurt']:continue
   a=m.evaluate_situation(state,0.)
   b=m.evaluate_situation(state,duration)
   self.assertLess(max(abs(a[k]-b[k]) for k in a),.00001,state)
if __name__=='__main__':unittest.main()
