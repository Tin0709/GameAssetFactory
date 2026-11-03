"""Exercise Windows launcher errors without Godot or proprietary assets."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(os.name == 'nt' and shutil.which('py'), 'Windows Python launcher required')
class OverworldLauncherTests(unittest.TestCase):
    def test_a_directory_cannot_be_used_as_the_private_bundle_file(self):
        launcher = Path(__file__).resolve().parents[2] / 'Open Overworld Meadow.cmd'
        with tempfile.TemporaryDirectory(prefix='GAF bundle folder ') as temp:
            folder = Path(temp) / 'bundle.private.json'
            folder.mkdir()
            env = dict(os.environ, MD2_OVERWORLD_BUNDLE=str(folder), GODOT_BIN=sys.executable)
            command = f'"{env["COMSPEC"]}" /d /c call "{launcher}" --dry-run'
            result = subprocess.run(command, cwd=temp, env=env, input='\n',
                                    capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 1, (result.stdout, result.stderr))
        self.assertIn('not a folder', result.stdout)


if __name__ == '__main__':
    unittest.main()
