"""Configure the opened R8 study only; reuse the inherited R7 split layout."""
import bpy,json
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'arm_r8a1_review';TARGET=BASE/'player_longgun_arm_rig_v2_study.blend'
assert Path(bpy.data.filepath)==TARGET
s=bpy.data.scenes['R8A1_COMPARISON'];bpy.context.window.scene=s;s.frame_set(20);s.frame_start=1;s.frame_end=48;s.sync_mode='FRAME_DROP'
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects:o.select_set(False)
r=bpy.data.objects['R8A1_Comparison_3_Rig'];r.select_set(True);bpy.context.view_layer.objects.active=r
board=bpy.data.images.load(str(OUT/'reference_board.png'),check_existing=True);board.name='R8A1_REFERENCE_BOARD';board.pack()
view=next(a for a in bpy.context.screen.areas if a.type=='VIEW_3D');refs=next(a for a in bpy.context.screen.areas if a.type=='IMAGE_EDITOR')
view.spaces.active.camera=s.camera;view.spaces.active.region_3d.view_perspective='CAMERA';view.spaces.active.region_3d.view_camera_zoom=15;view.spaces.active.overlay.show_overlays=False;view.spaces.active.shading.type='MATERIAL'
refs.spaces.active.image=board;region=next(x for x in refs.regions if x.type=='WINDOW')
with bpy.context.temp_override(area=refs,region=region):bpy.ops.image.view_all(fit_view=True)
for a in bpy.context.screen.areas:
 if a.type=='DOPESHEET_EDITOR':a.spaces.active.mode='ACTION'
bpy.context.workspace.name='R8-A1 Review'
report=bpy.data.texts.get('R8A1_REPORT') or bpy.data.texts.new('R8A1_REPORT');report.clear();report.write((OUT/'R8_A1_REPORT.txt').read_text(encoding='utf-8'))
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET),check_existing=False)
(OUT/'review_setup.json').write_text(json.dumps({'file':str(TARGET),'scene':s.name,'frame':20,'active_rig':r.name,'action':r.animation_data.action.name,'references_packed':board.packed_file is not None},indent=2))
