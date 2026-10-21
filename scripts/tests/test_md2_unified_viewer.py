import unittest,importlib.util
from pathlib import Path
S=Path(__file__).resolve().parents[1];spec=importlib.util.spec_from_file_location('dev_grass_unified',S/'dev.py');dev=importlib.util.module_from_spec(spec);spec.loader.exec_module(dev)
class UnifiedViewer(unittest.TestCase):
 def test_asset_launcher_requests_single_library_ui(self):
  c=dev.blender_command(Path('/bin/blender'),'asset-style-v2');self.assertTrue(any('MD2_GRASS_LIBRARY_V001' in x for x in c))
 def test_loader_uses_unified_panel(self):
  text=(S/'load_showcase_ui.py').read_text();self.assertIn("'grass_library_ui', 'MD2_PT_grass_library'",text)
 def test_current_command_requests_interaction(self):
  self.assertTrue(any('MD2_GRASS_INTERACTION_V001' in x for x in dev.blender_command(Path('/bin/blender'),'asset-style-v2')))
if __name__=='__main__':unittest.main()
