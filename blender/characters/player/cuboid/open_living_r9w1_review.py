"""Preserve a dirty open study as a separate recovery copy, then open R9."""
import bpy,json
from pathlib import Path
from datetime import datetime
BASE=Path(__file__).resolve().parent;OUT=BASE/'living_r9w1_review';TARGET=BASE/'player_longgun_living_r9w1_study.blend'
assert Path(bpy.data.filepath) in {BASE/'player_longgun_arm_rig_v2_study.blend',TARGET}
if Path(bpy.data.filepath)!=TARGET:
 if bpy.data.is_dirty:
  backup=OUT/('previous_R8_session_'+datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend')
  bpy.ops.wm.save_as_mainfile(filepath=str(backup),copy=True,check_existing=False)
  (OUT/'previous_session_backup.json').write_text(json.dumps({'file':str(backup),'reason':'Preserved dirty open R8 session before opening R9; original R8 file not overwritten'},indent=2))
 bpy.ops.wm.open_mainfile(filepath=str(TARGET))
