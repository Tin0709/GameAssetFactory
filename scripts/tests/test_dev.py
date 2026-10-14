"""Portable launcher contracts; run with standard-library unittest."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'dev.py'
spec = importlib.util.spec_from_file_location('gaf_dev', SCRIPT)
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)


class PortableLauncherTests(unittest.TestCase):
    def test_explicit_executable_with_spaces_is_one_argument(self):
        with tempfile.TemporaryDirectory(prefix='GAF tool space ') as temp:
            tool = Path(temp) / 'Godot binary'; tool.touch()
            self.assertEqual(dev.find_tool('godot', str(tool)), tool.resolve())

    def test_invalid_explicit_override_does_not_silently_fall_back(self):
        with self.assertRaises(FileNotFoundError):
            dev.find_tool('godot', '/does-not-exist/Godot')

    def test_macos_app_bundle_discovery(self):
        expected = Path('/Applications/Blender.app/Contents/MacOS/Blender')
        with patch.object(dev.platform, 'system', return_value='Darwin'), patch.object(dev.shutil, 'which', return_value=None), patch.object(dev.Path, 'is_file', lambda p: p == expected), patch.object(dev.Path, 'home', return_value=Path('/Users/test')), patch.dict(dev.os.environ, {}, clear=True):
            self.assertEqual(dev.find_tool('blender'), expected)

    def test_macos_command_does_not_force_windows_gpu_driver(self):
        with patch.object(dev.platform, 'system', return_value='Darwin'):
            cmd = dev.godot_command(Path('/Applications/Godot.app/Contents/MacOS/Godot'), 'snappy', False, False)
        self.assertNotIn('d3d12', cmd)
        self.assertIn('--rendering-method', cmd)
        self.assertEqual(cmd[-1], 'res://scenes/dev/SnappyLocomotionFastJumpTest.tscn')

    def test_windows_preserves_existing_driver_policy(self):
        with patch.object(dev.platform, 'system', return_value='Windows'):
            cmd = dev.godot_command(Path('C:/Tools/Godot.exe'), 'grassland', False, False)
        self.assertIn('d3d12', cmd)
        self.assertIn(str(dev.ROOT / 'game_mobile_3d'), cmd)

    def test_showcase_explicitly_loads_repository_ui(self):
        cmd = dev.blender_command(Path('/bin/blender'), 'animation')
        self.assertIn('--disable-autoexec', cmd)
        self.assertIn(str(dev.ROOT / 'scripts/load_showcase_ui.py'), cmd)
        self.assertTrue(any(s.endswith('Animation_Showcase.blend') for s in cmd))

    def test_scene_path_rejects_external_or_traversal_paths(self):
        for scene in ['C:/outside/scene.tscn', '../scene.tscn', 'res://../scene.tscn']:
            with self.assertRaises(ValueError):
                dev.godot_command(Path('/bin/godot'), scene, False, False)


if __name__ == '__main__':
    unittest.main()
