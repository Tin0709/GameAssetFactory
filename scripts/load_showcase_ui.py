"""Explicitly load the local Showcase UI; no per-user add-on or file save needed."""
import importlib
from pathlib import Path
import sys
import bpy

ROOT = Path(__file__).resolve().parents[1]
weapon = Path(bpy.data.filepath).name == 'Weapon_Showcase.blend'
folder = ROOT / ('blender/weapons/showcase' if weapon else 'blender/animation/showcase')
sys.path.insert(0, str(folder))
module = importlib.import_module('gaf_weapon_library' if weapon else 'gaf_animation_library')
panel = 'GAF_PT_weapon_library' if weapon else 'GAF_PT_animation_library'
if not hasattr(bpy.types, panel):
    module.register()
module.loaded(None)
if weapon and not bpy.app.background:
    bpy.app.timers.register(module.show_library_panel, first_interval=.5)
if not weapon:
    # Explicit hydration validates existing entries without importing new Actions.
    module.refresh(bpy.context.scene, import_missing=False)
    if not bpy.app.background:
        for area in bpy.context.screen.areas:
            if area.type == 'VIEW_3D':
                area.spaces.active.show_region_ui = True
                for region in area.regions:
                    if region.type == 'UI': region.active_panel_category = 'Animation Library'
print('GAF_SHOWCASE_UI_READY', 'weapon' if weapon else 'animation', flush=True)
