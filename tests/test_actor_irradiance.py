import unittest
import numpy as np
from scripts.graphics.actor_irradiance import integrate_volume_points, AXES
from scripts.graphics.terrain_irradiance import Scene

class ActorIrradianceTests(unittest.TestCase):
    def test_open_sky_has_calibrated_direction_and_no_false_bounce(self):
        scene=Scene([[40,0,40]],[0,0,0],[[0,0,0]])
        mean=np.array([.1,.2,.3])
        result=integrate_volume_points(scene,np.array([[0.25,3.25,0.25]]),256,[0,1,0],mean)
        expected=mean*(1+(2/3)*AXES[:,1,None]*[.15,.25,.45]+(2/3)*.18*(AXES[:,0,None]*.616-AXES[:,2,None]*.788))
        np.testing.assert_allclose(result['sky'][0],expected,atol=.001)
        np.testing.assert_array_equal(result['sun'],0)

    def test_zero_light_stays_zero_and_floor_bounce_is_colored(self):
        cells=[[x,0,z]for x in range(-4,5)for z in range(-4,5)]
        scene=Scene(cells,[0,0,0],[[.1,.3,.05]]*len(cells))
        result=integrate_volume_points(scene,np.array([[.25,1.25,.25]]),128,[0,1,0],[0,0,0])
        np.testing.assert_array_equal(result['sky'],0)
        self.assertGreater(result['sun'][0,3,1],result['sun'][0,3,0]*2)
        self.assertTrue(np.all(result['sun']>=0))

    def test_invalid_receivers_fail_instead_of_baking_inside_solids(self):
        scene=Scene([[0,0,0]],[0,0,0],[[.2,.2,.2]])
        with self.assertRaises(ValueError):
            integrate_volume_points(scene,np.array([[.25,.25,.25]]),64,[0,1,0],[1,1,1])

if __name__=='__main__':unittest.main()
