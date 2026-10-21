"""Real Blender operators, extreme controls, active render layer and preserved assets."""
import bpy,sys,json,math,hashlib
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));sys.path.insert(0,str(D.parent/'showcase'))
bpy.ops.wm.open_mainfile(filepath=str(D.parent/'showcase/SOLDIER_Asset_Library.blend'),load_ui=True)
import soldier_library_ui;soldier_library_ui.register();import facial_ui as ui;import expression_model as model
scene=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];ctrl=bpy.data.objects['SF_Face_Control'];face=bpy.data.objects['SF_Face_Mesh'];rig=bpy.data.objects['SF_Soldier_Rig']
ui.select(bpy.context,'preset','Hurt_Heavy');scene.frame_set(17)
captured=float(ctrl['open_l']);assert captured<.2
ui.select(bpy.context,'preset','Neutral_Idle')
assert scene.frame_start<scene['sf_loop_start'] and scene.frame_current==scene.frame_start,'Entry must be outside repeating frames'
assert abs(ctrl['open_l']-captured)<1e-5,'Selection must start from current face'
scene.frame_set(5);assert scene.frame_start==5,'Entry is consumed once'
neutral_start=float(ctrl['open_l']);scene.frame_set(scene.frame_end+1);neutral_end=float(ctrl['open_l'])
scene.frame_set(5)
assert abs(ctrl['open_l']-neutral_start)<1e-5 and abs(neutral_end-neutral_start)<1e-5,'Loop must not replay Hurt'
ui.select(bpy.context,'situation','Aim');scene.frame_set(5);a=float(ctrl['open_l']);scene.frame_set(scene.frame_end+1);b=float(ctrl['open_l'])
assert abs(a-.73)<1e-5 and abs(a-b)<1e-5,'Aim must not reopen eyes on each loop'
assert len(scene.soldier_facial.presets)==18
assert all(n in bpy.data.objects for n in ['SF_Soldier_Body','SF_Soldier_Hair','SF_Soldier_Clothing'])
parts=json.loads(face['parts_json']);samples=0;max_width=0.;max_pupil_escape=0.
for name,p in model.PRESETS.items():
 ui.select(bpy.context,'preset',name)
 assert sum(layer.use for layer in scene.view_layers)==1 and scene.view_layers['Facial Expressions'].use
 for t in [0,.3,.4,.6,p['duration']/2,p['duration']-.04]:
  scene.frame_set(round(t*30)+5)
  for intensity,gx,gy in [(1.,0.,0.),(1.,1.,1.),(1.,-1.,-1.),(0.,0.,0.)]:
   props=scene.soldier_facial;props.intensity=intensity;props.look_x=gx;props.look_y=gy;props.auto_blink=True
   bpy.context.view_layer.update();evaluated=face.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
   inverse=(rig.pose.bones['Head'].matrix@rig.data.bones['Head'].matrix_local.inverted()).inverted();points=[inverse@v.co for v in mesh.vertices]
   width=max(v.x for v in points)-min(v.x for v in points);max_width=max(max_width,width)
   assert width<.50 and max(v.z for v in points)-min(v.z for v in points)<.50,(name,'face cover distorted',width)
   for side in ['L','R']:
    white=next(p for p in parts if p['side']==side and p['kind']=='white');bounds=[(min(points[i][axis] for i in white['indices']),max(points[i][axis] for i in white['indices'])) for axis in [0,2]]
    for part in parts:
     if part['side']!=side or part['kind'] not in ['iris','accent']:continue
     for i in part['indices']:
      for axis,(lo,hi) in zip([0,2],bounds):max_pupil_escape=max(max_pupil_escape,lo-points[i][axis],points[i][axis]-hi)
   assert max_pupil_escape<.00001,(name,'Pupil escapes whites',max_pupil_escape)
   evaluated.to_mesh_clear();samples+=1
for state in model.SITUATIONS:
 ui.select(bpy.context,'situation',state);scene.frame_set(25)
 assert scene.soldier_facial.situation==state
for camera in ['SF_Front_Close','SF_ThreeQuarter_Close','SF_Side_Close','SF_Gameplay_Distance']:
 assert bpy.ops.soldier_face.camera(camera=camera)=={'FINISHED'};assert scene.camera.name==camera
before_count=len(bpy.data.actions)
for i in range(5):bpy.ops.soldier_face.step(direction=1)
assert len(bpy.data.actions)==before_count,'Selection creates accumulated Actions'
assert bpy.ops.soldier_face.neutral()=={'FINISHED'};assert scene.soldier_facial.index==0 and scene.soldier_facial.look_x==0
for asset in ['SOLDIER_Backpack_v001','SOLDIER_Skin_v001']:
 assert bpy.ops.soldier_library.select_asset(asset_id=asset)=={'FINISHED'}
 assert bpy.context.view_layer.name!='Facial Expressions';assert sum(layer.use for layer in bpy.context.scene.view_layers)==1
assert bpy.ops.soldier_face.open()=={'FINISHED'}
ui.register();assert bpy.app.handlers.frame_change_post.count(ui.frame_changed)==1
assert all(d.driver.is_valid and d.driver.is_simple_expression for d in face.data.shape_keys.animation_data.drivers)
report={'passed':True,'presets':18,'situations':len(model.SITUATIONS),'geometry_samples':samples,'maximum_face_width_m':max_width,'maximum_pupil_escape_m':max_pupil_escape,'no_action_accumulation':True,'same_library_scene':True,'native_simple_drivers':True,'one_time_entry_then_clean_loop':True}
(D/'ui_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('SOLDIER_FACE_UI_PASS',json.dumps(report),flush=True)
