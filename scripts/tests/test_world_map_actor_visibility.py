"""Independent geometric and cosine-kernel fixtures for the original bake."""
import importlib.util
from pathlib import Path
import unittest
try:
    import numpy as np
except ImportError:
    np=None

@unittest.skipIf(np is None,"Optional original-visibility authoring requires numpy")
class VisibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path=Path(__file__).resolve().parents[1]/'bake_world_map_actor_visibility.py'
        spec=importlib.util.spec_from_file_location('original_crown_visibility',path)
        cls.module=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.module)

    def test_exact_voxel_ray_intersections(self):
        points=np.array([[0.,0.,-2.],[2.,2.,2.],[0.,0.,0.],[2.,0.,0.],[0.,2.,0.]])
        directions=self.module.directions(127)
        with np.errstate(divide='ignore'):
            t0=(-1-points[:,None,:])/directions;t1=(1-points[:,None,:])/directions
        expected=np.minimum(t0,t1).max(axis=2)<=np.maximum(t0,t1).min(axis=2)
        expected &= np.maximum(t0,t1).min(axis=2)>=0
        actual=self.module.trace(points,directions,np.ones((2,2,2),bool),np.array([-1,-1,-1]),1.)
        np.testing.assert_array_equal(actual,expected)

    def test_fully_blocked_upper_sky_has_known_cosine_integral(self):
        rays=self.module.directions(2048)
        c=self.module.coefficients(np.ones((1,len(rays)),bool),rays)[0]
        # Exact hemi-space Lambert fractions: up1, horizontal.5, down0.
        for n,want in [(np.array([0,1,0]),1.),(np.array([1,0,0]),.5),(np.array([0,-1,0]),0.)]:
            got=c[0]+c[1:4]@n+c[4:7]@(n*n)+2*(c[7]*n[0]*n[1]+c[8]*n[0]*n[2]+c[9]*n[1]*n[2])
            self.assertAlmostEqual(got,want,delta=.001)

    def test_empty_occluder_retains_open_sky(self):
        rays=self.module.directions(192)
        c=self.module.coefficients(np.zeros((3,len(rays)),bool),rays)
        np.testing.assert_array_equal(c,np.zeros((3,10),np.float32))

if __name__=='__main__':unittest.main()
