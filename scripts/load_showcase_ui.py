"""Register the existing viewer panels without auto-run, preferences or file saves."""
import importlib
import importlib.util
from pathlib import Path
import sys
import bpy

ROOT = Path(__file__).resolve().parents[1]
SHOWCASES = {
    'dungeons_ground_style_v2.blend': ('blender/environment/studies/dungeons_ground_style_v2/tall_grass_md2_v001', 'grass_library_ui', 'MD2_PT_grass_library'),
    'player_animation_library_v1.blend': ('blender/animation/reviews/player_animation_library_v1', 'review_controls', 'PLAYER_REVIEW_PT_library'),
    'Animation_Showcase.blend': ('blender/animation/showcase', 'gaf_animation_library', 'GAF_PT_animation_library'),
    'Weapon_Showcase.blend': ('blender/weapons/showcase', 'gaf_weapon_library', 'GAF_PT_weapon_library'),
    'Mobs_Animation_Library.blend': ('blender/animation/showcase/mobs_library', 'gaf_mobs_animation_library', 'MOBS_PT_library'),
    'SOLDIER_Asset_Library.blend': ('blender/characters/soldier/showcase', 'soldier_library_ui', 'SOLDIER_PT_library'),
}


def main():
    filename = Path(bpy.data.filepath).name
    folder, module_name, panel = SHOWCASES[filename]
    sys.path.insert(0, str(ROOT / folder))
    if module_name == 'review_controls':
        # This existing script registers its classes at import time. Do not
        # import/re-register it if its panel is already present in this process.
        if not hasattr(bpy.types, panel):
            importlib.import_module(module_name)
    else:
        module = importlib.import_module(module_name)
        # An older installed GAF addon can already occupy this module name.
        # Use this viewer's repository UI, keeping saved selection/playback state.
        expected = ROOT / folder / (module_name + '.py')
        cached_path = getattr(module, '__file__', None)
        if module_name == 'gaf_animation_library' and isinstance(cached_path, str) and Path(cached_path).resolve() != expected.resolve():
            saved = [(scene, {name: getattr(scene, name, default) for name, default in [('gaf_active_index', 0), ('gaf_loop', True), ('gaf_show_archived', False)]})
                     for scene in bpy.data.scenes if scene.get('gaf_animation_showcase')]
            if hasattr(bpy.types, panel):
                module.unregister()
            spec = importlib.util.spec_from_file_location(module_name, expected)
            module = importlib.util.module_from_spec(spec)
            sys.modules[module_name] = module
            spec.loader.exec_module(module)
            module.register()
            for scene, values in saved:
                for name, value in values.items():
                    setattr(scene, name, value)
        if not hasattr(bpy.types, panel):
            module.register()
        # Hydrate only the registry already saved in this viewer. Refresh/import
        # is an explicit user operation, never part of startup.
        module.loaded(None)
    if not bpy.app.background:
        for window in bpy.context.window_manager.windows:
            for area in window.screen.areas:
                if area.type == 'VIEW_3D':
                    area.spaces.active.show_region_ui = True
                    area.tag_redraw()
    print('GAF_SHOWCASE_UI_READY', filename, panel, flush=True)


if __name__ == '__main__':
    main()
