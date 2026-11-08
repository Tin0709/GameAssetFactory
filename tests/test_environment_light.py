import unittest
import numpy as np
from scripts.graphics.environment_light import ggx_brdf, sun_visibility
from scripts.graphics.terrain_irradiance import Scene

class EnvironmentLightTests(unittest.TestCase):
    def test_mirror_fresnel_split(self):
        nv=np.array([.2,.5,1.]);a,b=ggx_brdf(nv,0.,2048)
        np.testing.assert_allclose(a+b,1.,atol=1e-5)
        np.testing.assert_allclose(b,(1-nv)**5,atol=1e-5)
    def test_unit_rough_single_scatter_energy(self):
        a,b=ggx_brdf(np.array([1.]),1.,8192)
        self.assertAlmostEqual(float((a+b)[0]),1-np.log(2),delta=.001)
    def test_sun_grid_has_no_light_through_solid(self):
        scene=Scene([[0,2,0]],[0,0,0],[[.2,.2,.2]])
        got=sun_visibility(scene,np.array([[.25,.25,.25],[.25,1.25,.25],[2.,.25,2.]]),[0,1,0])
        np.testing.assert_array_equal(got,[0,0,1])
if __name__=='__main__':unittest.main()
