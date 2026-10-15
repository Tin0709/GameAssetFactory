"""Viewer startup contract without requiring bpy in the system Python."""
from pathlib import Path
import runpy
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

BOOTSTRAP = Path(__file__).resolve().parents[1] / 'load_showcase_ui.py'


class StartupRegion:
    type = 'UI'

    @property
    def active_panel_category(self):
        return 'UNSUPPORTED'

    @active_panel_category.setter
    def active_panel_category(self, value):
        raise AttributeError('active_panel_category is read-only')


class ViewerUIContractTests(unittest.TestCase):
    def test_three_saved_registries_load_without_refresh_or_category_write(self):
        for filename, panel in [
            ('Animation_Showcase.blend', 'GAF_PT_animation_library'),
            ('Weapon_Showcase.blend', 'GAF_PT_weapon_library'),
            ('Mobs_Animation_Library.blend', 'MOBS_PT_library'),
        ]:
            with self.subTest(file=filename):
                space = SimpleNamespace(show_region_ui=False)
                area = SimpleNamespace(type='VIEW_3D', spaces=SimpleNamespace(active=space),
                                       regions=[StartupRegion()], tag_redraw=Mock())
                types = SimpleNamespace()
                bpy = SimpleNamespace(data=SimpleNamespace(filepath=filename), types=types,
                                      app=SimpleNamespace(background=False),
                                      context=SimpleNamespace(window_manager=SimpleNamespace(windows=[
                                          SimpleNamespace(screen=SimpleNamespace(areas=[area]))])))
                library = Mock()
                library.register.side_effect = lambda: setattr(types, panel, object())
                with patch.dict(sys.modules, {'bpy': bpy}), patch.object(sys, 'path', list(sys.path)), \
                        patch('importlib.import_module', return_value=library):
                    runpy.run_path(str(BOOTSTRAP), run_name='__main__')
                    runpy.run_path(str(BOOTSTRAP), run_name='__main__')
                library.register.assert_called_once()
                self.assertEqual(library.loaded.call_count, 2)
                library.refresh.assert_not_called()
                self.assertTrue(space.show_region_ui)


if __name__ == '__main__':
    unittest.main()
