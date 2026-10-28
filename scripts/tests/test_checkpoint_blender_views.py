"""Validate launch contracts without starting extra Blender instances."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    from checkpoint_manager.blender_views import BlenderViewLauncher
except ImportError:
    BlenderViewLauncher = None


class BlenderViewTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(BlenderViewLauncher, 'Blender view launcher not implemented')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.research = self.root / 'MD2 Research'
        self.project = self.root / 'GameAssetFactory'
        self.blender = self.root / 'Program Files' / 'Blender' / 'blender.exe'
        self.blender.parent.mkdir(parents=True)
        self.blender.write_bytes(b'fixture')
        for name in ['blender/MD2_Animation_Library_BrowserFixed.blend', 'scripts/md2_blender_library.py',
                     'blender/prototype_sabre/MD2_Valorie_Sabre_Source_Showcase.blend',
                     'blender/prototype_sabre/source_preview_ui.py']:
            path = self.research / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'fixture')
        for name in ['blender/animation/showcase/Animation_Showcase.blend', 'scripts/load_showcase_ui.py']:
            path = self.project / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'fixture')
        self.launcher = BlenderViewLauncher(self.root / 'state', self.research, self.blender, project_root=self.project)

    def test_each_view_opens_its_existing_blend_with_matching_ui_script(self):
        expected = {
            'animation': ['blender/MD2_Animation_Library_BrowserFixed.blend', 'scripts/md2_blender_library.py'],
            'sabre': ['blender/prototype_sabre/MD2_Valorie_Sabre_Source_Showcase.blend', 'blender/prototype_sabre/source_preview_ui.py'],
        }
        for key, files in expected.items():
            with self.subTest(key=key):
                launches = []
                class Process:
                    pid = 1234
                    def __init__(self, args, **kwargs):
                        launches.append((args, kwargs))
                with patch('subprocess.Popen', Process):
                    self.assertEqual(self.launcher.open(key), 1234)
                args, kwargs = launches[0]
                self.assertEqual(args, [str(self.blender), str(self.research / files[0]), '--python', str(self.research / files[1])])
                self.assertNotIn('--background', args)
                self.assertFalse(kwargs.get('shell', False))
                self.assertEqual(Path(kwargs['cwd']), (self.research / files[0]).parent)
        with patch('subprocess.Popen') as launch:
            launch.return_value.pid = 5678
            self.assertEqual(self.launcher.open('showcase'), 5678)
        self.assertEqual(launch.call_args.args[0], [str(self.blender), '--factory-startup', '--disable-autoexec',
            str(self.project / 'blender/animation/showcase/Animation_Showcase.blend'), '--python',
            str(self.project / 'scripts/load_showcase_ui.py')])
        self.assertEqual(self.launcher.blend_path('showcase'), self.project / 'blender/animation/showcase/Animation_Showcase.blend')

    def test_missing_ui_script_is_reported_before_launch(self):
        (self.research / 'blender/prototype_sabre/source_preview_ui.py').unlink()
        with self.assertRaises(FileNotFoundError):
            self.launcher.open('sabre')
        self.assertFalse((self.root / 'state').exists())

    def test_unknown_shortcut_does_not_launch_anything(self):
        with self.assertRaises(ValueError):
            self.launcher.open('unknown')
        self.assertFalse((self.root / 'state').exists())


if __name__ == '__main__':
    unittest.main()
