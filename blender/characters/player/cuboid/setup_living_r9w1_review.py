"""Configure only the open R9 study and save its review layout."""
import bpy,json
from pathlib import Path
BASE=Path(__file__).resolve().parent;OUT=BASE/'living_r9w1_review';TARGET=BASE/'player_longgun_living_r9w1_study.blend'
assert Path(bpy.data.filepath)==TARGET
s=bpy.data.scenes['R9W1_REVIEW_LOCAL'];bpy.context.window.scene=s;s.frame_set(49);s.frame_start=1;s.frame_end=288;s.sync_mode='FRAME_DROP'
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects:o.select_set(False)
r=bpy.data.objects['R9W1_Local_Living_Rig'];r.select_set(True);bpy.context.view_layer.objects.active=r
board=bpy.data.images.load(str(OUT/'reference_board.png'),check_existing=True);board.name='R9W1_CROSSBOW_REFERENCE';board.pack()
view=next(a for a in bpy.context.screen.areas if a.type=='VIEW_3D');refs=next(a for a in bpy.context.screen.areas if a.type=='IMAGE_EDITOR')
view.spaces.active.camera=s.camera;view.spaces.active.region_3d.view_perspective='CAMERA';view.spaces.active.region_3d.view_camera_zoom=15;view.spaces.active.overlay.show_overlays=False;view.spaces.active.shading.type='MATERIAL'
refs.spaces.active.image=board;region=next(x for x in refs.regions if x.type=='WINDOW')
with bpy.context.temp_override(area=refs,region=region):bpy.ops.image.view_all(fit_view=True)
for a in bpy.context.screen.areas:
 if a.type=='DOPESHEET_EDITOR':
  a.spaces.active.mode='ACTION'
  with bpy.context.temp_override(area=a,region=next(x for x in a.regions if x.type=='WINDOW')):bpy.ops.action.view_all()
bpy.context.workspace.name='R9-W1 Review'
report=bpy.data.texts.get('R9W1_REPORT') or bpy.data.texts.new('R9W1_REPORT');report.clear();report.write((OUT/'R9_W1_REPORT.txt').read_text(encoding='utf-8'))
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(TARGET),check_existing=False)
(OUT/'review_setup.json').write_text(json.dumps({'file':str(TARGET),'scene':s.name,'frame':49,'active_rig':r.name,'action':r.animation_data.action.name,'references_packed':board.packed_file is not None,'other_scenes':['R9W1_REVIEW_READY','R9W1_REVIEW_MOVE','R9W1_REVIEW_STEERING']},indent=2))
