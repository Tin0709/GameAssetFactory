import unittest
import numpy as np
from scripts.graphics.terrain_irradiance import Scene, integrate, receiver_origins

class TerrainIrradianceTests(unittest.TestCase):
    def test_open_origins_unchanged_and_enclosed_receiver_rejected(self):
        scene=Scene([[0,0,0]],[0,0,0],[[.2,.2,.2]])
        p=np.array([[.5,.5,.5,0,1,0],[0.,.25,.5,-1,0,0]])
        np.testing.assert_array_equal(receiver_origins(scene,p),p[:,:3]+p[:,3:]*.01)
        with self.assertRaisesRegex(ValueError,'no exposed origin'):
            receiver_origins(scene,np.array([[.5,.25,.5,1,0,0]]))

    def test_concave_boundary_matches_exposed_face_interior(self):
        # A side-face endpoint lies exactly on its neighbouring perpendicular
        # wall. Normal-only epsilon enters that wall and falsely blocks all rays.
        scene=Scene([[0,1,0],[1,1,1]],[0,0,0],[[.2,.2,.2],[.2,.2,.2]])
        edge=np.array([[1.,.75,1.,1,0,0]])
        interior=np.array([[1.,.75,.99,1,0,0]])
        a=integrate(scene,edge,256,[0,1,0],[.1,.2,.3])
        b=integrate(scene,interior,256,[0,1,0],[.1,.2,.3])
        self.assertGreater(b['visibility'][0],.4)
        np.testing.assert_allclose(a['sky'],b['sky'],atol=1e-9)
        np.testing.assert_allclose(a['sun'],b['sun'],atol=1e-9)

    def test_open_surface_preserves_sky_integral(self):
        scene=Scene([[0,0,0],[0,1,0]], [0,0,0], [[.2,.2,.2],[.2,.2,.2]])
        r=integrate(scene,np.array([[.5,1.,.5,0,1,0]]),256,[0,1,0],[.1,.2,.3])
        np.testing.assert_allclose(r['sky'][0],[.11,.2333333333,.39],atol=2e-5)
        np.testing.assert_allclose(r['sun'][0],0,atol=1e-8)
        self.assertAlmostEqual(r['visibility'][0],1.,places=6)

    def test_ground_reflection_retains_original_color(self):
        cells=[[x,y,z] for x in range(-25,26) for y in [0,1] for z in range(-25,26)]
        scene=Scene(cells,[0,0,0],np.tile([.1,.6,.1],(len(cells),1)))
        r=integrate(scene,np.array([[.5,2.,.5,0,0,1]]),512,[0,1,0],[.1,.1,.1])
        self.assertGreater(r['sun'][0,1],r['sun'][0,0]*5.9)
        self.assertGreater(r['sun'][0,1],.24)
        self.assertLess(r['sun'][0,1],.31)
        self.assertGreater(r['visibility'][0],.48)
        self.assertLess(r['visibility'][0],.55)

    def test_trace_returns_first_surface_and_sun_occlusion(self):
        scene=Scene([[1,0,0],[3,0,0]],[0,0,0],[[.8,.1,.1],[.1,.8,.1]])
        hit,normal=scene.trace(np.array([[0.,.25,.5],[0.,2.,.5]]),np.array([[1,0,0],[1,0,0]]))
        self.assertEqual(hit.tolist(),[0,-1])
        np.testing.assert_array_equal(normal[0],[-1,0,0])

    def test_invalid_rays_and_material_colors_fail_closed(self):
        with self.assertRaises(ValueError):Scene([[0,0,0]],[0,0,0],[[np.nan,0,0]])
        scene=Scene([[0,0,0]],[0,0,0],[[.2,.3,.4]])
        with self.assertRaises(ValueError):scene.trace([[2,2,2]],[[0,0,0]])

    def test_first_hits_against_independent_box_intersections(self):
        rng=np.random.default_rng(316);cells=np.array([[0,0,0],[1,1,0],[2,0,2],[-1,2,1]])
        scene=Scene(cells,[0,0,0],np.ones((4,3))*.2)
        origins=rng.uniform(-3,4,(128,3));dirs=rng.normal(size=(128,3));dirs/=np.linalg.norm(dirs,axis=1)[:,None]
        expected=[]
        for o,d in zip(origins,dirs):
            lo=cells/np.array([1,2,1]);hi=(cells+1)/np.array([1,2,1])
            a=(lo-o)/d;b=(hi-o)/d;t=np.maximum(np.minimum(a,b).max(1),0);leave=np.maximum(a,b).min(1)
            t=np.where(leave>t,t,np.inf);expected.append(int(t.argmin()) if np.isfinite(t).any() else -1)
        hit,_=scene.trace(origins,dirs);np.testing.assert_array_equal(hit,expected)

if __name__=='__main__':unittest.main()
