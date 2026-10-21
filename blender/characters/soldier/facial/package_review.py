"""Store the original-speed review edit and default facial workspace in the ONE file."""
import bpy,sys,json,uuid
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));sys.path.insert(0,str(D.parent/'showcase'))
bpy.ops.wm.open_mainfile(filepath=str(D.parent/'showcase/SOLDIER_Asset_Library.blend'),load_ui=True)
bpy.context.preferences.filepaths.save_version=0
import soldier_library_ui;soldier_library_ui.register();import facial_ui as ui;import face_blender as fb;import expression_model as model
scene=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];ui.show_layer(bpy.context)
face=bpy.data.objects['SF_Face_Mesh'];ctrl=bpy.data.objects['SF_Face_Control'];rig=bpy.data.objects['SF_Soldier_Rig'];weapon=bpy.data.objects['SF_Rifle_Sand_Block_V1']
for curve in face.data.shape_keys.animation_data.drivers:
 if '**3' in curve.driver.expression:
  term='min(1,max(0,b*i+a*u))';curve.driver.expression='*'.join([term]*3)
assert all(d.driver.is_simple_expression for d in face.data.shape_keys.animation_data.drivers)
reel=fb.face_action('SOLDIER_Facial_Review_Reel',ctrl,'reel','REVIEW_REEL',model.REEL_DURATION)
fb.body_action(rig,weapon,'reel','REVIEW_REEL',model.REEL_DURATION)
for obj,name in [(rig,'SF_Review_Reel_Body'),(weapon,'SF_Review_Reel_Weapon')]:
 old=bpy.data.actions.get(name)
 if old and old!=obj.animation_data.action:bpy.data.actions.remove(old)
 obj.animation_data.action.name=name
scene['sf_review_reel_duration_s']=model.REEL_DURATION
text=bpy.data.texts.get('SOLDIER — original-speed review edit') or bpy.data.texts.new('SOLDIER — original-speed review edit');text.clear();text.write(json.dumps({'fps':30,'segments':model.REEL,'duration_s':model.REEL_DURATION,'status':'Pending','review_edit_not_body_candidate':True},indent=2))
cat=D.parent/'showcase/blender_assets.cats.txt';content=cat.read_text();line=next((line for line in content.splitlines() if ':SOLDIER/Facial Expressions:' in line),None)
identifier=line.split(':')[0] if line else str(uuid.uuid4())
if not line:cat.write_text(content.rstrip()+'\n'+identifier+':SOLDIER/Facial Expressions:Facial Expressions\n')
for action in bpy.data.actions:
 if action.get('soldier_facial') and action.asset_data:action.asset_data.catalog_id=identifier
bpy.data.collections['SOLDIER_Facial_Expressions_PENDING'].asset_data.catalog_id=identifier
ui.select(bpy.context,'preset','Neutral_Idle');scene.soldier_facial.auto_blink=True;scene.soldier_facial.intensity=1.;scene.soldier_facial.look_x=scene.soldier_facial.look_y=0.
scene.camera=bpy.data.objects['SF_Front_Close'];scene['sf_camera']='SF_Front_Close';scene.frame_set(1);scene.render.fps=30;scene.render.fps_base=1.
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.show_region_ui=True;area.spaces.active.overlay.show_overlays=False;area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.use_local_camera=False
rig.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(D.parent/'showcase/SOLDIER_Asset_Library.blend'),compress=True)
print('SOLDIER_REVIEW_PACKAGED',len(bpy.data.actions),model.REEL_DURATION,flush=True)
