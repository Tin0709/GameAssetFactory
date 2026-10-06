"""Run through the connected Blender MCP. Temporary export scene, 96 Hz sampling."""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Matrix
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
OUT=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\game_mobile_3d\assets\characters\player_cuboid_animated_v2.glb')
assert Path(bpy.data.filepath)==BASE/'player_cuboid_weapon_animation_dev.blend'
def curves(a): return [c for l in a.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
def digest(a):
 return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
protected={a.name:digest(a) for a in bpy.data.actions}
scene=bpy.context.scene; rig=bpy.data.objects['Player_Cuboid_Rig']; mesh=bpy.data.objects['Player_Cuboid_Base']
saved_action=rig.animation_data.action; saved_frame=scene.frame_current; saved_sub=scene.frame_subframe
selected=list(bpy.context.selected_objects); active=bpy.context.view_layer.objects.active
source=bpy.data.actions['Holster_LongGun_V3_Final']; allowed=['Chest','Spine','Arm.L','Arm.R','Neck','Head','WeaponCarrier']
samples=[]
for p in rig.pose.bones: p.matrix_basis=Matrix.Identity(4)
rig.animation_data.action=source
for step in range(69):
 frame=1+step/4;scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
 samples.append({'time':step/96,'bones':{n:[list(row) for row in rig.pose.bones[n].matrix] for n in allowed}})
(BASE/'holster_d2_source_samples.json').write_text(json.dumps(samples))
rig.animation_data.action=saved_action;scene.frame_set(saved_frame,subframe=saved_sub)
assert 'HolsterLongGun' not in bpy.data.actions or digest(bpy.data.actions['HolsterLongGun'])==digest(source)
clean=bpy.data.actions.get('HolsterLongGun') or source.copy();clean.name='HolsterLongGun';clean.use_fake_user=True
temp_scene=bpy.data.scenes.new('D2_EXPORT_TEMP');temp_scene.render.fps=96;temp_scene.frame_start=1;temp_scene.frame_end=69
temp_rig=rig.copy();temp_rig.data=rig.data.copy();temp_rig.name='D2_Export_Rig';temp_rig.animation_data_clear();temp_scene.collection.objects.link(temp_rig)
temp_mesh=mesh.copy();temp_mesh.data=mesh.data.copy();temp_mesh.name='D2_Export_Base';temp_mesh.parent=temp_rig;temp_scene.collection.objects.link(temp_mesh)
for mod in temp_mesh.modifiers:
 if mod.type=='ARMATURE':mod.object=temp_rig
temp_action=clean.copy();temp_action.name='D2_Export_Holster';temp_action.use_fake_user=False
for c in curves(temp_action):
 for k in c.keyframe_points:
  k.co.x=1+(k.co.x-1)*4;k.handle_left.x=1+(k.handle_left.x-1)*4;k.handle_right.x=1+(k.handle_right.x-1)*4
 c.update()
temp_rig.animation_data_create();temp_rig.animation_data.action=temp_action;temp_rig.animation_data.action_slot=temp_action.slots[0];temp_rig.hide_viewport=False;temp_mesh.hide_viewport=False
window=bpy.context.window;window.scene=temp_scene
try:
 for p in temp_rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
 temp_scene.frame_set(1);temp_rig.select_set(True);temp_mesh.select_set(True);bpy.context.view_layer.objects.active=temp_rig
 bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,use_active_scene=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,export_frame_step=1,export_def_bones=False,export_anim_slide_to_zero=True,export_cameras=False,export_lights=False)
finally:
 window.scene=scene
 rd=temp_rig.data;md=temp_mesh.data
 bpy.data.objects.remove(temp_mesh,do_unlink=True);bpy.data.objects.remove(temp_rig,do_unlink=True)
 bpy.data.meshes.remove(md);bpy.data.armatures.remove(rd);bpy.data.actions.remove(temp_action);bpy.data.scenes.remove(temp_scene)
 for o in bpy.context.selected_objects:o.select_set(False)
 for o in selected:o.select_set(True)
 bpy.context.view_layer.objects.active=active
 rig.animation_data.action=saved_action;scene.frame_set(saved_frame,subframe=saved_sub)
assert all(digest(bpy.data.actions[n])==h for n,h in protected.items())
(BASE/'holster_d2_protection.json').write_text(json.dumps(protected,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'player_cuboid_weapon_animation_dev.blend'))
result={'export':str(OUT),'protected_actions':len(protected),'copy':'HolsterLongGun','source_samples':69,'scene_fps':scene.render.fps}


