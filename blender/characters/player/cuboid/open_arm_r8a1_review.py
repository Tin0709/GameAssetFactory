"""Open the saved review. File loading ends an interactive console execution.

If already open, refresh its layout; otherwise the saved review layout is used.
"""
import bpy
from pathlib import Path
from datetime import datetime
BASE=Path(__file__).resolve().parent;OUT=BASE/'arm_r8a1_review';TARGET=BASE/'player_longgun_arm_rig_v2_study.blend'
assert Path(bpy.data.filepath) in {BASE/'player_longgun_hold_reference_study_v1.blend',TARGET}
if Path(bpy.data.filepath)!=TARGET:
 if bpy.data.is_dirty:bpy.ops.wm.save_as_mainfile(filepath=str(OUT/('previous_open_session_'+datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend')),copy=True,check_existing=False)
 bpy.ops.wm.open_mainfile(filepath=str(TARGET))
else:
 p=BASE/'setup_arm_r8a1_review.py';exec(compile(p.read_text(encoding='utf-8'),str(p),'exec'),{'__file__':str(p),'__name__':'__main__'})
