"""Blender-only hold/aim study; new file, two new Actions, current rigid rig."""
import bpy,sys,json,math,hashlib,subprocess,shutil
from pathlib import Path
from mathutils import Matrix,Vector,Euler
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3]
sys.path.insert(0,str(BASE))
from turning_r2_common import curves,digest,geometry,bone_signature
SOURCE=BASE/'player_cuboid_weapon_animation_dev.blend'
OUT=BASE/'hold_r7w1_review';OUT.mkdir(exist_ok=True)
TARGET=BASE/'player_longgun_hold_reference_study_v1.blend'
assert Path(bpy.data.filepath)==SOURCE
protected={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'rigs':{o.name:bone_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'},'files':{}}
for name in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0'):
 if name and (ROOT/name).is_file():protected['files'][name]=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
if not (OUT/'preservation.json').exists():(OUT/'preservation.json').write_text(json.dumps(protected,indent=2))
refs=[Path('C:/Users/ADMIN/Downloads/ChatGPT Image Oct 7, 2026, 01_51_36 PM.png'),Path('C:/Users/ADMIN/Downloads/ChatGPT Image Oct 7, 2026, 01_51_43 PM.jpg'),Path('C:/Users/ADMIN/AppData/Local/Temp/codex-clipboard-631eee5e-3546-487d-83b2-c4694ec54eff.jpg')]
for i,p in enumerate(refs):shutil.copy2(p,OUT/('reference_%d'% (i+1)+p.suffix))
rig=bpy.data.objects['Player_Cuboid_Rig'];mesh=bpy.data.objects['Player_Cuboid_Base'];original=next(s for s in bpy.data.scenes if rig.name in s.objects);bpy.context.window.scene=original
hold=bpy.data.actions['LongGunHold_V2'];rig.animation_data.action=hold;rig.animation_data.action_slot=hold.slots[0]
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
original.frame_set(1);bpy.context.view_layer.update()
old_pose={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
old_weapon=bpy.data.objects['M4A1_Blocky_Base'].evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
weapon_relative=rig.pose.bones['WeaponCarrier'].matrix.inverted()@old_weapon
study=bpy.data.scenes.new('R7W1_AUTHORING');study.world=original.world;study.render.fps=24
def clone(label,scene):
 originals=[rig,mesh]+list(bpy.data.collections['D1_M4A1_REFERENCE_ONLY'].objects);mapping={}
 for old in originals:
  obj=old.copy();obj.name='R7W1_'+label+'_'+old.name
  if old==rig:obj.data=old.data.copy()
  obj.animation_data_clear();scene.collection.objects.link(obj);mapping[old]=obj
 for old,obj in mapping.items():
  if old.parent in mapping:obj.parent=mapping[old.parent]
  for mod in obj.modifiers:
   if mod.type=='ARMATURE' and mod.object==rig:mod.object=mapping[rig]
  for con in obj.constraints:
   if hasattr(con,'target') and con.target==rig:con.target=mapping[rig]
  obj.hide_render=False;obj.hide_viewport=False
 return mapping[rig],mapping
r,author=clone('Author',study);bpy.context.window.scene=study
def apply(pose):
 r.animation_data_clear()
 for n,m in pose.items():r.pose.bones[n].matrix_basis=m
 bpy.context.view_layer.update()
apply(old_pose)
def degrees(n,vals):r.pose.bones[n].rotation_euler=Euler(tuple(math.radians(v) for v in vals),'XYZ')
degrees('Spine',(1.0,-2.0,.35));degrees('Chest',(3.0,-7.0,.7))
degrees('Neck',(.5,2.0,1.0));degrees('Head',(1.0,2.0,1.2))
degrees('Arm.R',(66,-12,15));degrees('Arm.L',(75,12,-50))
# A bounded 45mm trigger-shoulder draw-back in the pose, not a rest/rig change.
r.pose.bones['Arm.R'].location=(0,.015,-.010)
r.pose.bones['Arm.L'].location=(0,.035,.145)
bpy.context.view_layer.update()
desired=Matrix.LocRotScale(Vector((-.35,-.44,1.14)),Euler(tuple(math.radians(v) for v in (2,0,175)),'XYZ').to_quaternion(),old_weapon.to_scale())
r.pose.bones['WeaponCarrier'].matrix=desired@weapon_relative.inverted();bpy.context.view_layer.update()
new_pose={p.name:p.matrix_basis.copy() for p in r.pose.bones}
UPPER=['Spine','Chest','Neck','Head','Arm.R','Arm.L','WeaponCarrier']
def key(action,frame,pose):
 apply(pose);r.animation_data_create();r.animation_data.action=action
 if len(action.slots):r.animation_data.action_slot=action.slots[0]
 for n in UPPER:
  p=r.pose.bones[n]
  p.keyframe_insert('location',frame=frame,group=n)
  p.keyframe_insert('rotation_quaternion' if p.rotation_mode=='QUATERNION' else 'rotation_euler',frame=frame,group=n)
for name in ['LongGunHold_ReferenceStudy_V1','LongGunAimBias_Study_V1']:assert name not in bpy.data.actions
new=bpy.data.actions.new('LongGunHold_ReferenceStudy_V1');new.use_fake_user=True
for f in [1,49]:key(new,f,new_pose)
for c in curves(new):
 for k in c.keyframe_points:k.interpolation='CONSTANT'
aim=bpy.data.actions.new('LongGunAimBias_Study_V1');aim.use_fake_user=True
# A short focus / emphasis / release study, not a recoil system.
for f,weight in [(1,0),(7,0),(15,.78),(20,1),(23,.88),(31,.30),(43,0),(49,0)]:
 apply(new_pose)
 for n,delta in [('Neck',(.35,.15,.8)),('Head',(1.25,-.25,1.6)),('Chest',(.35,0,.12))]:
  r.pose.bones[n].matrix_basis=new_pose[n]@Euler(tuple(math.radians(v*weight) for v in delta),'XYZ').to_matrix().to_4x4()
 bpy.context.view_layer.update()
 pose={p.name:p.matrix_basis.copy() for p in r.pose.bones}
 key(aim,f,pose)
for c in curves(aim):
 for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='AUTO_CLAMPED'
 c.modifiers.new('CYCLES')
for a in [new,aim]:
 a['scope']='R7-W1 Blender-only study; current rig; no production replacement or export.'
 a['base']='LongGunHold_V2';a['fps']=24;a['play_frames']='1..48; endpoint49';a['rig_policy']='No bones, IK, scale keys or constraints added.'
for name,f in [('READY',1),('FOCUS',15),('TINY_EMPHASIS',20),('SETTLED',43)]:aim.pose_markers.new(name).frame=f
def setup(scene):
 scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1200;scene.render.resolution_y=720;scene.render.resolution_percentage=100;scene.render.fps=24;scene.frame_start=1;scene.frame_end=48
 scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
 scene.world=original.world;scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
 for o in original.objects:
  if o.type=='LIGHT':scene.collection.objects.link(o)
def camera(scene,label,pos,target,scale):
 data=bpy.data.cameras.new('R7W1_'+label);data.type='ORTHO';data.ortho_scale=scale
 cam=bpy.data.objects.new(data.name,data);scene.collection.objects.link(cam);cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();return cam
setup(study)
views={'Gameplay':((3,-5,4.4),(0,-.25,.95),3.8),'Front':((3,-5,2.5),(0,-.25,1.00),3.4),'Side':((-5,-.25,1.9),(0,-.25,1.0),3.4),'Rear':((-3,5,2.9),(0,-.2,1.0),3.4),'GameplayDistance':((3,-5,4.4),(0,-.25,.95),17.77778),'CloseGun':((3,-5,2.65),(0,-.30,1.36),2.45)}
for name,(pos,target,scale) in views.items():camera(study,name,pos,target,scale)
study.camera=bpy.data.objects['R7W1_Front'];r.animation_data.action=new;r.animation_data.action_slot=new.slots[0];study.frame_set(1)
# Three synchronized columns, retained as actual editable rigs and two Actions.
compare=bpy.data.scenes.new('R7W1_COMPARISON');setup(compare);bpy.context.window.scene=compare
q=(Vector((3,-5,3.45))).to_track_quat('Z','Y');right=q@Vector((1,0,0))
for index,(label,action) in enumerate([('A_Current',hold),('B_Study',new),('C_Aim',aim)]):
 rr,objects=clone(label,compare)
 for n,m in old_pose.items():rr.pose.bones[n].matrix_basis=m
 rr.animation_data_create();rr.animation_data.action=action;rr.animation_data.action_slot=action.slots[0]
 offset=right*((index-1)*2.0)
 for old,obj in objects.items():
  if old.parent is None and old!=bpy.data.objects['M4A1_Reference_CarrierMount']:obj.location+=offset
 data=bpy.data.curves.new('R7W1_Label','FONT');data.body=['A  CURRENT HOLD','B  HOLD STUDY','C  AIM BIAS'][index];data.align_x='CENTER';data.size=.12
 ob=bpy.data.objects.new(data.name,data);compare.collection.objects.link(ob);ob.location=offset+Vector((0,0,2.0));ob.rotation_euler=q.to_euler()
compare.camera=camera(compare,'ABC_Camera',Vector((0,-.2,1.0))+q@Vector((0,0,10)),(0,-.2,1.0),6.5)
compare.frame_set(20);compare['review']='A current hold / B braced rigid-arm candidate / C subtle focus. Frame1 ready, frame20 emphasis, frame43 settled. 24fps.'
# Reference images are packed into the study and available through Image Editor.
for i,p in enumerate(refs):
 im=bpy.data.images.load(str(OUT/('reference_%d'%(i+1)+p.suffix)),check_existing=True);im.name='R7W1_REFERENCE_%d'%(i+1);im.pack()
text=bpy.data.texts.new('R7W1_README');text.write('BLENDER ONLY / AWAITING HUMAN REVIEW\nR7W1_COMPARISON: A current hold, B new hold, C aim bias. Space plays 24fps, frames1–48.\nR7W1_AUTHORING: individual Actions; cameras Front, Side, Rear, Gameplay and GameplayDistance.\nThree packed images named R7W1_REFERENCE_1/2/3 are the supplied references.\nRigid arms preserved; imperfect grip/support contact is evidence for review, not hidden.\n')
for n,h in protected['actions'].items():assert digest(bpy.data.actions[n])==h,n
for n,h in protected['geometry'].items():assert geometry()[n]==h,n
for n,sig in protected['rigs'].items():assert bone_signature(bpy.data.objects[n])==sig,n
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET),check_existing=False)
print('R7W1_CREATED',str(TARGET),flush=True)
