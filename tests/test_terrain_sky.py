"""Original source-voxel geometry tests, independent of rendering or MD2 assets."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import numpy as np

spec=importlib.util.spec_from_file_location('terrain_sky',Path(__file__).parents[1]/'scripts/graphics/terrain_sky.py')
model=importlib.util.module_from_spec(spec);spec.loader.exec_module(model)


class TerrainSky(unittest.TestCase):
    def setUp(self):
        self.scratch=tempfile.TemporaryDirectory()
        self.folder=Path(self.scratch.name)
        metadata={'count':1,'occupied':[[0,0,0],[0,1,0]],'offset':[10,2,-7],
                  'ambient_srgb':[.55,.71,.83],'rows':[],'source_runtime_sha256':'unit-original-box'}
        (self.folder/'metadata.private.json').write_text(json.dumps(metadata))
        np.array([[11.,2.5,-6.5,1.,0.,0.]],np.float32).tofile(self.folder/'vertices.private.bin')
        self.source=model.Source(self.folder)

    def tearDown(self):self.scratch.cleanup()

    def test_solid_half_cells_and_outside_entry(self):
        origins=np.array([[12,2.5,-6.5],[10.5,1,-6.5],[12,2.5,-6.5],[11.01,2.5,-6.5],[10.5,2.5,-6.5]])
        directions=np.array([[-1,0,0],[0,1,0],[0,0,1],[1,0,0],[0,1,0]])
        np.testing.assert_array_equal(self.source.hits(origins,directions),[True,True,False,False,True])

    def test_ray_box_oracle(self):
        rng=np.random.default_rng(81)
        origins=rng.uniform([8,0,-9],[13,5,-4],(300,3))
        directions=rng.normal(size=(300,3))
        a=(np.array([10,2,-7])-origins)/directions
        b=(np.array([11,3,-6])-origins)/directions
        expected=np.maximum(a,b).min(1)>np.maximum(np.minimum(a,b).max(1),0.)
        np.testing.assert_array_equal(self.source.hits(origins,directions),expected)

    def test_open_upper_sky_is_identity(self):
        values=self.source.evaluate(self.source.points,1024)
        np.testing.assert_array_equal(values,[1.])

    def test_degenerate_ray_is_rejected(self):
        with self.assertRaises(ValueError):
            self.source.hits(np.array([[10.5,2.5,-6.5]]),np.zeros((1,3)))

    def test_bake_refuses_existing_output(self):
        output=self.folder/'new-bake'
        result=model.bake(self.source,output,64)
        self.assertEqual(result['full_vertices'],1)
        original=(output/'visibility.private.bin').read_bytes()
        with self.assertRaises(FileExistsError):model.bake(self.source,output,64)
        self.assertEqual(original,(output/'visibility.private.bin').read_bytes())


if __name__=='__main__':unittest.main()
