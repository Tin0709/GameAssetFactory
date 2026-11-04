"""Read-only Blender library discovery without launching desktop tools."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('gaf_dev_viewers', Path(__file__).parents[1] / 'dev.py')
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)


class ViewerCatalogTests(unittest.TestCase):
    def test_catalog_reports_files_and_lfs_without_tools_or_asset_changes(self):
        with tempfile.TemporaryDirectory(prefix='GAF viewer files ') as temp:
            root = Path(temp)
            paths = {'plain': 'plain.blend', 'compressed': 'compressed.blend',
                     'pointer': 'pointer.blend', 'missing': 'missing.blend',
                     'folder': 'folder.blend'}
            original = {'plain.blend': b'BLENDER-v502' + b'x' * 100,
                        'compressed.blend': b'\x28\xb5\x2f\xfd' + b'z' * 100,
                        'pointer.blend': b'version https://git-lfs.github.com/spec/v1\noid sha256:abc\n'}
            for name, data in original.items():
                (root / name).write_bytes(data)
            (root / 'folder.blend').mkdir()
            output = io.StringIO()
            with patch.object(dev, 'ROOT', root), patch.object(dev, 'VIEWERS', paths), \
                    patch.object(dev, 'find_tool', side_effect=AssertionError('Tool lookup forbidden')), \
                    patch.object(dev.subprocess, 'Popen', side_effect=AssertionError('Launch forbidden')), \
                    contextlib.redirect_stdout(output):
                self.assertEqual(dev.main(['viewers']), 0)
            catalog = json.loads(output.getvalue())
            self.assertEqual(set(catalog), set(paths))
            for alias, status in [('plain', 'ready'), ('compressed', 'ready'),
                                  ('pointer', 'lfs_pointer'), ('missing', 'missing'),
                                  ('folder', 'missing')]:
                self.assertEqual(catalog[alias]['status'], status)
                self.assertEqual(catalog[alias]['path'], str(root / paths[alias]))
            self.assertEqual({name: (root / name).read_bytes() for name in original}, original)

    def test_unreadable_header_is_reported_without_hiding_other_viewers(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'locked.blend').touch()
            output = io.StringIO()
            with patch.object(dev, 'ROOT', root), \
                    patch.object(dev, 'VIEWERS', {'locked': 'locked.blend', 'absent': 'absent.blend'}), \
                    patch.object(Path, 'open', side_effect=PermissionError('Access denied')), \
                    contextlib.redirect_stdout(output):
                self.assertEqual(dev.main(['viewers']), 0)
            result = json.loads(output.getvalue())
            self.assertEqual(result['locked']['status'], 'unreadable')
            self.assertEqual(result['absent']['status'], 'missing')


if __name__ == '__main__':
    unittest.main()
