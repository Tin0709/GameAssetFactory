"""Background-only export. Never saves the development or production source."""
import bpy, json, hashlib, re
from pathlib import Path
from mathutils import Matrix
BASE = Path(__file__).parent
ROOT = BASE.parents[3]
OUT = BASE / 'export/draw_d5'
OUT.mkdir(parents=True, exist_ok=True)
DEV = BASE / 'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath) == DEV
def curves(a):
    return [c for l in a.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
def digest(a):
    return hashlib.sha256(repr([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)]).encode()).hexdigest()
protected = {a.name: digest(a) for a in bpy.data.actions}
source_hash = hashlib.sha256(DEV.read_bytes()).hexdigest()
source = bpy.data.actions['Draw_LongGun_V3_Final']
allowed = sorted({re.search(r'pose.bones\["([^"]+)"\]', c.data_path)[1] for c in curves(source)})
assert set(allowed) == {'Spine','Chest','Arm.R','Arm.L','Neck','Head','WeaponCarrier'}
assert not any(c.data_path.endswith('scale') for c in curves(source))
events = json.loads(source['event_subframes_json'])
fps = float(source['authoring_fps']); start, end = map(float, source.frame_range)
metadata = {'source_action':source.name,'source_property':'event_subframes_json','fps':fps,
            'start_frame':start,'end_frame':end,'duration_seconds':(end-start)/fps,
            'event_frames':events,'event_seconds':{k:(v-start)/fps for k,v in events.items()},
            'bones':allowed,'source_curve_sha256':digest(source)}
rig = bpy.data.objects['Player_Cuboid_Rig']; mesh = bpy.data.objects['Player_Cuboid_Base']
scene = bpy.context.scene
rig.animation_data.action = source
samples = []
for step in range(53):
    for bone in rig.pose.bones: bone.matrix_basis = Matrix.Identity(4)
    frame = 1 + step/4
    scene.frame_set(int(frame), subframe=frame-int(frame)); bpy.context.view_layer.update()
    samples.append({'time':step/96,'bones':{n:[list(row) for row in rig.pose.bones[n].matrix] for n in allowed}})
(OUT/'source_samples.json').write_text(json.dumps(samples))
(OUT/'events.json').write_text(json.dumps(metadata,indent=2))
# Persist a clean export-safe copy in a separate library; source stays unchanged.
clean = source.copy(); clean.name = 'DrawLongGun'; clean.use_fake_user = True
bpy.data.libraries.write(str(OUT/'DrawLongGun.blend'), {clean}, fake_user=True)
temp_scene = bpy.data.scenes.new('D5_EXPORT_TEMP'); temp_scene.render.fps=96
temp_scene.frame_start=1; temp_scene.frame_end=53
temp_rig=rig.copy();temp_rig.data=rig.data.copy();temp_rig.name='D5_Export_Rig';temp_rig.animation_data_clear();temp_scene.collection.objects.link(temp_rig)
temp_mesh=mesh.copy();temp_mesh.data=mesh.data.copy();temp_mesh.name='D5_Export_Base';temp_mesh.parent=temp_rig;temp_scene.collection.objects.link(temp_mesh)
for mod in temp_mesh.modifiers:
    if mod.type=='ARMATURE': mod.object=temp_rig
temp_action=clean.copy();temp_action.name='D5_Export_Draw';temp_action.use_fake_user=False
for c in curves(temp_action):
    for k in c.keyframe_points:
        k.co.x=1+(k.co.x-1)*4;k.handle_left.x=1+(k.handle_left.x-1)*4;k.handle_right.x=1+(k.handle_right.x-1)*4
    c.update()
temp_rig.animation_data_create();temp_rig.animation_data.action=temp_action;temp_rig.animation_data.action_slot=temp_action.slots[0]
temp_rig.hide_viewport=False;temp_mesh.hide_viewport=False
bpy.context.window.scene=temp_scene
for p in temp_rig.pose.bones: p.matrix_basis=Matrix.Identity(4)
temp_scene.frame_set(1);temp_rig.select_set(True);temp_mesh.select_set(True);bpy.context.view_layer.objects.active=temp_rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'draw_raw.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,export_frame_step=1,export_def_bones=False,export_anim_slide_to_zero=True,export_cameras=False,export_lights=False)
assert all(digest(bpy.data.actions[n])==h for n,h in protected.items())
assert hashlib.sha256(DEV.read_bytes()).hexdigest()==source_hash
(OUT/'protection.json').write_text(json.dumps({'source_file_sha256':source_hash,'protected_actions':protected,'source_unchanged':True},indent=2))
print('D5 export-only copy and raw sampled clip written; source unchanged')
