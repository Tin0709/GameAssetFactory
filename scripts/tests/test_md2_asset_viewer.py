"""The existing asset command must open the current review, not reuse a stale window."""
import importlib.util,unittest
from pathlib import Path
from unittest.mock import patch
S=Path(__file__).resolve().parents[1]/'dev.py';spec=importlib.util.spec_from_file_location('dev_md2',S);dev=importlib.util.module_from_spec(spec);spec.loader.exec_module(dev)
class CurrentAssetViewer(unittest.TestCase):
 def test_asset_command_loads_local_review_controls(self):
  command=dev.blender_command(Path('/bin/blender'),'asset-style-v2')
  self.assertIn(str(dev.ROOT/'scripts/load_showcase_ui.py'),command)
  self.assertTrue(any('MD2_SHORT_GRASS_V001' in arg for arg in command))
 def test_legacy_open_asset_window_is_preserved_but_not_reused(self):
  source=dev.ROOT/dev.VIEWERS['asset-style-v2']
  listing=f'101 /bin/blender --factory-startup --disable-autoexec {source}\n202 /bin/blender --factory-startup --disable-autoexec {source} --python {dev.ROOT}/scripts/load_showcase_ui.py --python-expr print(\"MD2_SHORT_GRASS_V001 MD2_TALL_GRASS_V001 MD2_GRASS_LIBRARY_V001 MD2_GRASS_WIND_V001 MD2_GRASS_INTERACTION_V001\")\n'
  with patch.object(dev.subprocess,'check_output',return_value=listing):
   self.assertEqual(dev.existing_viewer_pid('/bin/blender',source,require_ui=True),202)
if __name__=='__main__':unittest.main()
