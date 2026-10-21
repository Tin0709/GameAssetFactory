"""The public viewer commands must resolve paths from any working directory."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/open_blender_viewer.py'


class PublicViewerCommandsTests(unittest.TestCase):
    def test_all_viewer_commands_resolve_from_an_unrelated_directory(self):
        expected = {
            'asset': 'blender/environment/studies/dungeons_ground_style_v2/dungeons_ground_style_v2.blend',
            'player': 'blender/animation/reviews/player_animation_library_v1/player_animation_library_v1.blend',
            'animation': 'blender/animation/showcase/Animation_Showcase.blend',
            'weapon': 'blender/weapons/showcase/Weapon_Showcase.blend',
            'mobs': 'blender/animation/showcase/Mobs_Animation_Library.blend',
            'soldier': 'blender/characters/soldier/showcase/SOLDIER_Asset_Library.blend',
        }
        with tempfile.TemporaryDirectory(prefix='unrelated working directory ') as cwd:
            for viewer, relative in expected.items():
                with self.subTest(viewer=viewer):
                    result = subprocess.run([sys.executable, str(SCRIPT), viewer, '--dry-run',
                                             '--blender-bin', sys.executable], cwd=cwd,
                                            capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    command = json.loads(result.stdout)
                    self.assertIn(str(ROOT / relative), command)
                    self.assertNotIn('--background', command)
                    self.assertNotIn(str(ROOT / 'scripts/start_blender_mcp.py'), command)
                    self.assertIn('--python', command)

    def test_unknown_viewer_fails_without_launching(self):
        result = subprocess.run([sys.executable, str(SCRIPT), 'invalid'], cwd='/tmp',
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 2)
        self.assertIn('invalid choice', result.stderr)


if __name__ == '__main__':
    unittest.main()
