"""Tall review must open current data without replacing an older unsaved viewer."""
import importlib.util,unittest
from pathlib import Path
from unittest.mock import patch
S=Path(__file__).resolve().parents[1]/'dev.py';spec=importlib.util.spec_from_file_location('dev_md2_tall',S);dev=importlib.util.module_from_spec(spec);spec.loader.exec_module(dev)
class TallViewer(unittest.TestCase):
 def test_command_requests_tall_review_bootstrap(self):
  command=dev.blender_command(Path('/bin/blender'),'asset-style-v2')
  self.assertTrue(any('MD2_TALL_GRASS_V001' in x for x in command))
 def test_short_only_open_window_is_not_reused_for_new_tall_data(self):
  source=dev.ROOT/dev.VIEWERS['asset-style-v2'];prefix=f'/bin/blender --factory-startup --disable-autoexec {source} --python {dev.ROOT}/scripts/load_showcase_ui.py'
  listing=f'101 {prefix} --python-expr MD2_SHORT_GRASS_V001\n202 {prefix} --python-expr MD2_SHORT_GRASS_V001_MD2_TALL_GRASS_V001_MD2_GRASS_LIBRARY_V001 MD2_GRASS_WIND_V001\n'
  with patch.object(dev.subprocess,'check_output',return_value=listing):
   self.assertEqual(dev.existing_viewer_pid('/bin/blender',source,require_ui=True),202)
if __name__=='__main__':unittest.main()
