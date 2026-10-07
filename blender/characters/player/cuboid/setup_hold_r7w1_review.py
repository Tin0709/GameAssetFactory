"""Run in the opened study to leave an editable A/B/C viewport beside references."""
import bpy
import json
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'hold_r7w1_review';TARGET=BASE/'player_longgun_hold_reference_study_v1.blend'
assert Path(bpy.data.filepath)==TARGET
s=bpy.data.scenes['R7W1_COMPARISON'];bpy.context.window.scene=s;s.frame_set(20);s.frame_start=1;s.frame_end=48;s.sync_mode='FRAME_DROP'
r=bpy.data.objects['R7W1_C_Aim_Player_Cuboid_Rig']
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects:o.select_set(False)
r.select_set(True);bpy.context.view_layer.objects.active=r
image=bpy.data.images.load(str(OUT/'reference_board.png'),check_existing=True);image.name='R7W1_REFERENCE_BOARD';image.pack()
area=max((a for a in bpy.context.screen.areas if a.type=='VIEW_3D'),key=lambda a:a.width*a.height)
with bpy.context.temp_override(area=area):bpy.ops.screen.area_split(direction='VERTICAL',factor=.24)
# Split coordinates may not update until redraw; retain the original left area.
refs=area;main=next(a for a in bpy.context.screen.areas if a.type=='VIEW_3D' and a!=area)
main.spaces.active.region_3d.view_perspective='CAMERA';main.spaces.active.region_3d.view_camera_zoom=0;main.spaces.active.overlay.show_overlays=False;main.spaces.active.shading.type='MATERIAL'
refs.type='IMAGE_EDITOR';refs.spaces.active.image=image
region=next(x for x in refs.regions if x.type=='WINDOW')
with bpy.context.temp_override(area=refs,region=region):bpy.ops.image.view_all(fit_view=True)
for a in bpy.context.screen.areas:
 if a.type=='DOPESHEET_EDITOR':a.spaces.active.mode='ACTION'
bpy.context.workspace.name='R7-W1 Review'
readme=bpy.data.texts['R7W1_README'];readme.write('\nReview recommendation: current rig is insufficient for the supplied bent-arm holding target. See R7_W1_REPORT.txt and contact evidence. No upgrade performed.\n')
report=bpy.data.texts.get('R7W1_REPORT') or bpy.data.texts.new('R7W1_REPORT');report.clear();report.write((OUT/'R7_W1_REPORT.txt').read_text(encoding='utf-8'))
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET),check_existing=False)
result={'file':str(TARGET),'scene':s.name,'frame':s.frame_current,'action':r.animation_data.action.name,'reference_board_packed':image.packed_file is not None,'status':'AWAITING HUMAN REVIEW'}
(OUT/'review_setup.json').write_text(json.dumps(result,indent=2))
