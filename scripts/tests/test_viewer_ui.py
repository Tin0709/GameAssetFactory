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
    def test_cached_installed_animation_addon_is_replaced_by_repository_ui(self):
        types = SimpleNamespace(GAF_PT_animation_library=object())
        scene = SimpleNamespace(gaf_active_index=57, gaf_loop=False, gaf_show_archived=False)
        scene.get = lambda key: key == 'gaf_animation_showcase'
        bpy = SimpleNamespace(data=SimpleNamespace(filepath='Animation_Showcase.blend', scenes=[scene]),
                              types=types, app=SimpleNamespace(background=True))
        old = Mock(); old.__file__ = '/old/installed/gaf_animation_library.py'
        old.unregister.side_effect = lambda: delattr(types, 'GAF_PT_animation_library')
        fresh = Mock(); fresh.__file__ = str(BOOTSTRAP.parents[1] / 'blender/animation/showcase/gaf_animation_library.py')
        fresh.register.side_effect = lambda: setattr(types, 'GAF_PT_animation_library', object())
        spec = SimpleNamespace(loader=Mock())
        with patch.dict(sys.modules, {'bpy': bpy}), patch.object(sys, 'path', list(sys.path)), \
                patch('importlib.import_module', return_value=old), \
                patch('importlib.util.spec_from_file_location', return_value=spec), \
                patch('importlib.util.module_from_spec', return_value=fresh):
            runpy.run_path(str(BOOTSTRAP), run_name='__main__')
        old.unregister.assert_called_once()
        spec.loader.exec_module.assert_called_once_with(fresh)
        fresh.register.assert_called_once(); fresh.loaded.assert_called_once_with(None)
        fresh.refresh.assert_not_called()
        self.assertEqual((scene.gaf_active_index, scene.gaf_loop, scene.gaf_show_archived), (57, False, False))

    def test_player_review_script_self_registers_only_once(self):
        types = SimpleNamespace()
        space = SimpleNamespace(show_region_ui=False)
        area = SimpleNamespace(type='VIEW_3D', spaces=SimpleNamespace(active=space),
                               regions=[StartupRegion()], tag_redraw=Mock())
        bpy = SimpleNamespace(data=SimpleNamespace(filepath='player_animation_library_v1.blend'),
                              types=types, app=SimpleNamespace(background=False),
                              context=SimpleNamespace(window_manager=SimpleNamespace(windows=[
                                  SimpleNamespace(screen=SimpleNamespace(areas=[area]))])))
        library = Mock()
        def self_register(name):
            self.assertEqual(name, 'review_controls')
            types.PLAYER_REVIEW_PT_library = object()
            return library
        with patch.dict(sys.modules, {'bpy': bpy}), patch.object(sys, 'path', list(sys.path)), \
                patch('importlib.import_module', side_effect=self_register) as load:
            runpy.run_path(str(BOOTSTRAP), run_name='__main__')
            runpy.run_path(str(BOOTSTRAP), run_name='__main__')
        load.assert_called_once()
        library.register.assert_not_called()
        library.loaded.assert_not_called()
        self.assertTrue(space.show_region_ui)

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
