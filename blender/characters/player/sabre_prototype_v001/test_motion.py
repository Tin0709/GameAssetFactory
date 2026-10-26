"""Behavioral contract for original sparse reconstruction, no game file inputs."""
import math, unittest
import motion

class MotionContract(unittest.TestCase):
    def test_required_playable_set_and_source_clocks(self):
        required={'Idle','Walk','Run','StrafeLeft','StrafeRight','JumpTakeoff','JumpAirborne',
                  'JumpLanding','CombatReady','CombatWalk','CombatRun','CombatStrafeLeft',
                  'CombatStrafeRight','ReadyEnter','ReadyExit','Attack1','Attack2','Attack3',
                  'Recovery1','Recovery2','Recovery3','AirAttack'}
        self.assertEqual(set(motion.CLIPS),required)
        for key,seconds in [('Attack1',13/30),('Attack2',12/30),('Attack3',20/30),
                            ('Recovery1',11/30),('Recovery2',10/30),('Recovery3',20/30),
                            ('Walk',26/30),('Run',13/30),('JumpTakeoff',12/30)]:
            self.assertAlmostEqual(motion.CLIPS[key]['duration'],seconds,places=9)

    def test_combination_and_recovery_endpoints_are_connected(self):
        for a,b in [('Attack1','Attack2'),('Attack2','Attack3'),
                    ('Attack1','Recovery1'),('Attack2','Recovery2'),('Attack3','Recovery3')]:
            self.assertEqual(motion.pose(a,motion.CLIPS[a]['duration']),motion.pose(b,0))
        for a in ['Recovery1','Recovery2','Recovery3','ReadyEnter']:
            self.assertEqual(motion.pose(a,motion.CLIPS[a]['duration']),motion.pose('CombatReady',0))

    def test_loop_endpoint_and_all_finite_pose_outputs(self):
        for name,row in motion.CLIPS.items():
            if row['loop']:
                self.assertEqual(motion.pose(name,0),motion.pose(name,row['duration']))
            for i in range(41):
                p=motion.pose(name,row['duration']*i/40)
                self.assertTrue(all(math.isfinite(v) for v in p))
                self.assertEqual(len(p),motion.POSE_WIDTH)

    def test_grounded_hip_is_not_given_an_invented_bounce(self):
        # An added sine hip bob in motion generation must fail this contract.
        for key in ['Idle','Walk','Run','StrafeLeft','StrafeRight']:
            for i in range(19): self.assertEqual(motion.pose(key,motion.CLIPS[key]['duration']*i/18)[motion.HIP_Z],0)

    def test_vfx_windows_are_not_claimed_native_contacts(self):
        for key in ['Attack1','Attack2','Attack3','AirAttack']:
            row=motion.CLIPS[key]
            a,b=row['vfx_window']
            self.assertLess(0,a);self.assertLess(a,b);self.assertLess(b,row['duration'])
            self.assertIn('authored',row['vfx_evidence'])

if __name__=='__main__': unittest.main()
