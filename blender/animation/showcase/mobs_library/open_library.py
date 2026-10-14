"""Portable launcher bootstrap; no preference changes, no embedded auto-run needed."""
import bpy,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import gaf_mobs_animation_library as library
library.register();library.loaded(None)
