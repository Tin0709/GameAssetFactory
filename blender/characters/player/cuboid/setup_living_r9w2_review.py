from living_r9w2_common import *
s=bpy.data.scenes['R9W2_REVIEW_SWEEP'];bpy.context.window.scene=s;s.frame_set(49);s.sync_mode='FRAME_DROP';s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects:o.select_set(False)
r=bpy.data.objects['R9W2_SWEEP_C_Rig'];r.select_set(True);bpy.context.view_layer.objects.active=r
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':
  a.spaces.active.camera=s.camera;a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.region_3d.view_camera_zoom=10;a.spaces.active.overlay.show_overlays=False;a.spaces.active.shading.type='RENDERED'
 elif a.type=='IMAGE_EDITOR':
  a.spaces.active.image=bpy.data.images['R9W1_CROSSBOW_REFERENCE']
  with bpy.context.temp_override(area=a,region=next(x for x in a.regions if x.type=='WINDOW')):bpy.ops.image.view_all(fit_view=True)
 elif a.type=='DOPESHEET_EDITOR':
  a.spaces.active.mode='ACTION'
  with bpy.context.temp_override(area=a,region=next(x for x in a.regions if x.type=='WINDOW')):bpy.ops.action.view_all()
bpy.context.workspace.name='R9-W2 ABC Review'
t=bpy.data.texts.get('R9W2_REPORT') or bpy.data.texts.new('R9W2_REPORT');t.clear();t.write((OUT/'R9_W2_REPORT.txt').read_text(encoding='utf-8'))
save();(OUT/'review_setup.json').write_text(json.dumps({'scene':s.name,'frame':49,'rig':r.name,'action':r.animation_data.action.name,'reference_board':'R9W1_CROSSBOW_REFERENCE','status':'AWAITING HUMAN REVIEW'},indent=2))
