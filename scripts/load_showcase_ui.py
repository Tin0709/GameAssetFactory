"""Register the existing viewer panels without auto-run, preferences or file saves."""
import importlib
from pathlib import Path
import sys
import bpy

ROOT = Path(__file__).resolve().parents[1]
SHOWCASES = {
    'Animation_Showcase.blend': ('blender/animation/showcase', 'gaf_animation_library', 'GAF_PT_animation_library'),
    'Weapon_Showcase.blend': ('blender/weapons/showcase', 'gaf_weapon_library', 'GAF_PT_weapon_library'),
    'Mobs_Animation_Library.blend': ('blender/animation/showcase/mobs_library', 'gaf_mobs_animation_library', 'MOBS_PT_library'),
}


def main():
    filename = Path(bpy.data.filepath).name
    folder, module_name, panel = SHOWCASES[filename]
    sys.path.insert(0, str(ROOT / folder))
    module = importlib.import_module(module_name)
    if not hasattr(bpy.types, panel):
        module.register()
    # Hydrate only the registry already saved in this viewer. Refresh/import is
    # an explicit user operation, never part of startup.
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
