"""Open the existing central library with the research Run selected."""
import bpy,sys
from pathlib import Path
LIB=Path(bpy.data.filepath).resolve().parent
sys.path.insert(0,str(LIB))
import gaf_animation_library as ui
ui.register();ui.loaded(None)
s=bpy.context.scene
s.gaf_active_index=next(i for i,c in enumerate(s.gaf_clips) if c.action=='Run_ActionsStuff_Source_Test_v001')
ui.activate(s,s.gaf_active_index);ui.view(s,'THREE_QUARTER');s.gaf_loop=False
