"""Portable launcher contracts; run with standard-library unittest."""
import importlib.util
from pathlib import Path
import tempfile
import socket
import unittest
from unittest.mock import patch, Mock

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

    def test_combat_alias_and_sword_start_use_existing_scene(self):
        cmd=dev.godot_command(Path('/bin/godot'),'combat',False,False,weapon='sword')
        self.assertIn('res://scenes/dev/ActionsStuffWalkRunTest.tscn',cmd)
        self.assertEqual(cmd[-2:],['--','--sword'])

    def test_explicit_windows_vulkan_override_retains_mobile_renderer(self):
        with patch.object(dev.platform,'system',return_value='Windows'):
            cmd=dev.godot_command(Path('C:/Tools/Godot.exe'),'combat',False,False,driver='vulkan')
        self.assertIn('vulkan',cmd);self.assertNotIn('d3d12',cmd)
        self.assertIn('mobile',cmd)

    def test_weapon_start_option_cannot_be_silently_ignored_by_editor(self):
        with self.assertRaises(ValueError):dev.godot_command(Path('/bin/godot'),'combat',True,False,weapon='sword')

    def test_combat_cli_preserves_spaced_executable_and_scene_arguments(self):
        with patch.object(dev,'find_tool',return_value=Path('/Tool Folder/Godot')),patch.object(dev.subprocess,'call',return_value=0) as launch:
            self.assertEqual(dev.main(['godot','--scene','combat','--weapon','sword']),0)
        self.assertEqual(launch.call_args.args[0][0],str(Path('/Tool Folder/Godot')))
        self.assertEqual(launch.call_args.args[0][-2:],['--','--sword'])

    def test_showcase_explicitly_loads_repository_ui(self):
        cmd = dev.blender_command(Path('/bin/blender'), 'animation')
        self.assertIn('--disable-autoexec', cmd)
        self.assertIn(str(dev.ROOT / 'scripts/load_showcase_ui.py'), cmd)
        self.assertTrue(any(s.endswith('Animation_Showcase.blend') for s in cmd))

    def test_all_viewers_use_existing_files(self):
        expected = {
            'asset-style-v2': 'dungeons_ground_style_v2.blend',
            'player-library': 'player_animation_library_v1.blend',
            'animation': 'Animation_Showcase.blend',
            'weapon': 'Weapon_Showcase.blend',
            'mobs': 'Mobs_Animation_Library.blend',
            'soldier': 'SOLDIER_Asset_Library.blend',
        }
        self.assertEqual(set(dev.VIEWERS), set(expected))
        for viewer, filename in expected.items():
            with self.subTest(viewer=viewer):
                cmd = dev.blender_command(Path('/bin/blender'), viewer)
                source = dev.ROOT / dev.VIEWERS[viewer]
                self.assertTrue(source.is_file())
                self.assertEqual(source.name, filename)
                self.assertIn(str(source), cmd)
                self.assertNotIn(str(dev.ROOT / 'scripts/start_blender_mcp.py'), cmd)
                self.assertIn('--python', cmd)

    def test_blender_launch_detaches_without_waiting(self):
        command = dev.blender_command(Path('/bin/blender'), 'weapon')
        with tempfile.TemporaryDirectory() as temp, \
                patch.object(dev, 'viewer_cache', return_value=Path(temp)), \
                patch.object(dev, 'existing_viewer_pid', return_value=None), \
                patch.object(dev.subprocess, 'Popen', return_value=Mock(pid=123)) as spawn, \
                patch.object(dev.subprocess, 'call') as blocking:
            self.assertEqual(dev.launch_blender(command, 'weapon', bridge=False), 0)
        blocking.assert_not_called()
        self.assertTrue(spawn.call_args.kwargs['start_new_session'])
        self.assertEqual(spawn.call_args.kwargs['stdin'], dev.subprocess.DEVNULL)
        self.assertEqual(spawn.call_args.kwargs['stderr'], dev.subprocess.STDOUT)

    def test_repeat_launch_does_not_start_another_blender(self):
        with tempfile.TemporaryDirectory() as temp, \
                patch.object(dev, 'viewer_cache', return_value=Path(temp)), \
                patch.object(dev, 'existing_viewer_pid', return_value=123), \
                patch.object(dev, 'activate_viewer') as activate, \
                patch.object(dev.subprocess, 'Popen') as spawn:
            self.assertEqual(dev.launch_blender(dev.blender_command(Path('/bin/blender'), 'mobs'), 'mobs', bridge=False), 0)
        spawn.assert_not_called()
        activate.assert_called_once_with(123)

    def test_lfs_pointer_is_rejected_before_blender_launch(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / dev.VIEWERS['mobs']
            source.parent.mkdir(parents=True)
            source.write_text('version https://git-lfs.github.com/spec/v1\noid sha256:abc\n')
            with patch.object(dev, 'ROOT', root), self.assertRaisesRegex(ValueError, 'git lfs pull'):
                dev.blender_command(Path('/bin/blender'), 'mobs')

    def test_legacy_showcase_alias_and_new_viewer_cli_share_detached_launch(self):
        with patch.object(dev, 'find_tool', return_value=Path('/bin/blender')), \
                patch.object(dev, 'launch_blender', return_value=0) as launch:
            self.assertEqual(dev.main(['blender', '--showcase', 'weapon']), 0)
            old = launch.call_args
            self.assertEqual(dev.main(['blender', '--viewer', 'weapon']), 0)
            self.assertEqual(launch.call_args, old)

    def test_busy_mcp_port_is_rejected_before_launch(self):
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            port = listener.getsockname()[1]
            with tempfile.TemporaryDirectory() as temp, \
                    patch.object(dev, 'viewer_cache', return_value=Path(temp)), \
                    patch.object(dev, 'existing_viewer_pid', return_value=None), \
                    patch.dict(dev.os.environ, {'BLENDER_MCP_PORT': str(port)}), \
                    patch.object(dev.subprocess, 'Popen') as spawn:
                with self.assertRaisesRegex(ValueError, 'already in use'):
                    dev.launch_blender(dev.blender_command(Path('/bin/blender'), 'animation'), 'animation', bridge=True)
            spawn.assert_not_called()

    def test_process_detection_handles_spaces_and_avoids_prefix_matches(self):
        tool = '/Applications/Blender.app/Contents/MacOS/Blender'
        source = dev.ROOT / dev.VIEWERS['animation']
        processes = f'  41 {tool} --factory-startup {source}.other --python helper.py\n  42 {tool} --factory-startup {source} --python helper.py\n'
        with patch.object(dev.os, 'name', 'posix'), patch.object(dev.subprocess, 'check_output', return_value=processes):
            self.assertEqual(dev.existing_viewer_pid(tool, source), 42)

    def test_windows_viewer_detection_does_not_invoke_posix_ps(self):
        source = dev.ROOT / dev.VIEWERS['animation']
        with patch.object(dev.os, 'name', 'nt'), patch.object(dev.subprocess, 'check_output') as listing:
            self.assertIsNone(dev.existing_viewer_pid('blender.exe', source))
        listing.assert_not_called()

    def test_unknown_viewer_is_rejected(self):
        with self.assertRaises(ValueError):
            dev.blender_command(Path('/bin/blender'), 'unknown')

    def test_soldier_reuses_only_a_window_with_the_library_ui_bootstrap(self):
        import inspect
        self.assertIn('require_ui',inspect.signature(dev.existing_viewer_pid).parameters)
        tool='/Applications/Blender.app/Contents/MacOS/Blender'
        source=dev.ROOT/dev.VIEWERS['soldier']
        loader=dev.ROOT/'scripts/load_showcase_ui.py'
        listing=f'  31 {tool} --factory-startup {source}\n  32 {tool} --factory-startup {source} --python {loader}\n  34 {tool} --factory-startup {source} --python {loader} --python-expr print(\"SOLDIER_FACIAL_UI_V001\")\n  35 {tool} --factory-startup {source} --python {loader} --python-expr print(\"SOLDIER_FACIAL_UI_V001 SOLDIER_HAIRCARDS_UI_V001\")\n  33 {tool} --factory-startup {source} --python {loader} --python-expr print(\"SOLDIER_FACIAL_UI_V001 SOLDIER_HAIRCARDS_UI_V001_R2\")\n'
        with patch.object(dev.os, 'name', 'posix'), patch.object(dev.subprocess,'check_output',return_value=listing):
            self.assertEqual(dev.existing_viewer_pid(tool,source,require_ui=True),33)

    def test_scene_path_rejects_external_or_traversal_paths(self):
        for scene in ['C:/outside/scene.tscn', '../scene.tscn', 'res://../scene.tscn']:
            with self.assertRaises(ValueError):
                dev.godot_command(Path('/bin/godot'), scene, False, False)


if __name__ == '__main__':
    unittest.main()
