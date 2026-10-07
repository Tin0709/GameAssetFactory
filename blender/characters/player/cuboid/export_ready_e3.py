"""Export-only background process. Never save or alter the authoring blend."""
import bpy, json, hashlib, re
from pathlib import Path
from mathutils import Matrix

BASE = Path(__file__).resolve().parent
DEV = BASE / 'player_cuboid_weapon_animation_dev.blend'
OUT = BASE / 'export/ready_e3'
OUT.mkdir(parents=True, exist_ok=True)
assert Path(bpy.data.filepath) == DEV
def curves(a):
    return [c for layer in a.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]
def digest(a):
    return hashlib.sha256(repr(([(c.data_path, c.array_index, [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation, k.handle_left_type, k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)], dict(a.items()))).encode()).hexdigest()
protected = {a.name: digest(a) for a in bpy.data.actions}
file_hash = hashlib.sha256(DEV.read_bytes()).hexdigest()
rig = bpy.data.objects['Player_Cuboid_Rig']
mesh = bpy.data.objects['Player_Cuboid_Base']
assert bpy.context.mode == 'OBJECT'
source_scene = next(s for s in bpy.data.scenes if rig.name in s.objects and not s.name.startswith('E'))
bpy.context.window.scene = source_scene
records = {}
copies = set()
for source_name, export_name in [('LongGunReady_Loop_V1', 'LongGunReadyIdle'), ('LongGunReady_Run_V1', 'LongGunReadyRun')]:
    source = bpy.data.actions[source_name]
    channels = {}
    for c in curves(source):
        match = re.fullmatch(r'pose.bones\["([^"\n]+)"\]\.(location|rotation_euler|rotation_quaternion)', c.data_path)
        assert match, c.data_path
        channels.setdefault(match[1], set()).add('translation' if match[2] == 'location' else 'rotation')
    assert set(channels) == {'Spine', 'Chest', 'Neck', 'Head', 'Arm.R', 'Arm.L', 'WeaponCarrier'}
    start, end = map(float, source.frame_range)
    assert start == 1 and end == (33 if export_name.endswith('Idle') else 17)
    rig.animation_data.action = source
    rig.animation_data.action_slot = source.slots[0]
    samples = []
    for step in range(int((end-start)*4)+1):
        for p in rig.pose.bones: p.matrix_basis = Matrix.Identity(4)
        frame = start + step/4
        source_scene.frame_set(int(frame), subframe=frame-int(frame)); bpy.context.view_layer.update()
        samples.append({'time': step/96, 'bones': {n: [list(row) for row in rig.pose.bones[n].matrix] for n in channels}})
    clean = source.copy(); clean.name = export_name; clean.use_fake_user = True; copies.add(clean)
    temp_scene = bpy.data.scenes.new('E3_EXPORT_' + export_name)
    temp_scene.render.fps = 96; temp_scene.frame_start = 1; temp_scene.frame_end = int((end-start)*4)+1
    temp_rig = rig.copy(); temp_rig.data = rig.data.copy(); temp_rig.name = 'E3_Export_Rig'
    temp_rig.animation_data_clear(); temp_scene.collection.objects.link(temp_rig)
    temp_mesh = mesh.copy(); temp_mesh.data = mesh.data.copy(); temp_mesh.name = 'E3_Export_Base'
    temp_mesh.parent = temp_rig; temp_scene.collection.objects.link(temp_mesh)
    for mod in temp_mesh.modifiers:
        if mod.type == 'ARMATURE': mod.object = temp_rig
    temp_action = clean.copy(); temp_action.name = 'E3_Sampled_' + export_name; temp_action.use_fake_user = False
    for c in curves(temp_action):
        for k in c.keyframe_points:
            k.co.x = 1+(k.co.x-start)*4; k.handle_left.x = 1+(k.handle_left.x-start)*4; k.handle_right.x = 1+(k.handle_right.x-start)*4
        c.update()
    temp_rig.animation_data_create(); temp_rig.animation_data.action = temp_action; temp_rig.animation_data.action_slot = temp_action.slots[0]
    temp_rig.hide_viewport = False; temp_mesh.hide_viewport = False
    bpy.context.window.scene = temp_scene
    for p in temp_rig.pose.bones: p.matrix_basis = Matrix.Identity(4)
    temp_scene.frame_set(1)
    temp_rig.select_set(True); temp_mesh.select_set(True); bpy.context.view_layer.objects.active = temp_rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(export_name+'_raw.glb')), export_format='GLB', use_selection=True, use_active_scene=True,
        export_animation_mode='ACTIVE_ACTIONS', export_force_sampling=True, export_frame_step=1, export_def_bones=False,
        export_anim_slide_to_zero=True, export_cameras=False, export_lights=False)
    records[export_name] = {'source': source_name, 'source_frames': [start,end], 'fps':24, 'duration':(end-start)/24,
        'channels':{n:sorted(props) for n,props in channels.items()}, 'samples':samples}
    bpy.context.window.scene = source_scene
bpy.data.libraries.write(str(OUT/'LongGunReady_export_copies.blend'), copies, fake_user=True)
# Independent expected gameplay composition from the unchanged Blender sources.
# These matrices catch runtime layers which sample correctly but apply wrongly.
def basis_pose(action, frame):
    rig.animation_data.action = action; rig.animation_data.action_slot = action.slots[0]
    for p in rig.pose.bones: p.matrix_basis = Matrix.Identity(4)
    source_scene.frame_set(int(frame), subframe=frame-int(frame)); bpy.context.view_layer.update()
    return {p.name:p.matrix_basis.copy() for p in rig.pose.bones}
composition = []
for context, base_name, upper_name, length in [('Idle','Player_Idle','LongGunReady_Loop_V1',32), ('Run','Player_Run_Blocky_V7_Final','LongGunReady_Run_V1',16)]:
    for step in range(16):
        phase = step/16
        base = basis_pose(bpy.data.actions[base_name], 1+phase*(float(bpy.data.actions[base_name].frame_range[1])-1))
        upper = basis_pose(bpy.data.actions[upper_name], 1+phase*length)
        rig.animation_data.action = None
        for p in rig.pose.bones:
            if p.name in ['Spine','Chest','Neck','Head']: p.matrix_basis = base[p.name] @ upper[p.name]
            elif p.name in ['Arm.R','Arm.L','WeaponCarrier']: p.matrix_basis = upper[p.name]
            else: p.matrix_basis = base[p.name]
        bpy.context.view_layer.update()
        composition.append({'context':context, 'phase':phase, 'bones':{n:[list(row) for row in rig.pose.bones[n].matrix] for n in ['Spine','Chest','Neck','Head','Arm.R','Arm.L','WeaponCarrier']}})
(OUT/'composition_samples.json').write_text(json.dumps(composition))
assert all(digest(bpy.data.actions[n]) == h for n,h in protected.items())
assert hashlib.sha256(DEV.read_bytes()).hexdigest() == file_hash
(OUT/'source_samples.json').write_text(json.dumps(records))
(OUT/'protection.json').write_text(json.dumps({'source_file_sha256':file_hash, 'source_unchanged':True, 'protected_actions':protected},indent=2))
print('E3 export-only copies and 96 Hz samples prepared; authoring file unchanged')
