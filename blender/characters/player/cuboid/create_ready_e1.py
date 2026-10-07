"""E1 authoring only. Adds Ready V1 and a Blender copy of the runtime Hold pose."""
import bpy, json, math, hashlib, shutil, datetime
from pathlib import Path
from mathutils import Matrix, Vector, Euler, Quaternion

BASE = Path(__file__).resolve().parent
DEV = BASE / 'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath) == DEV
rig = bpy.data.objects['Player_Cuboid_Rig']
scene = bpy.context.scene
UPPER = ['Spine', 'Chest', 'Neck', 'Head', 'Arm.R', 'Arm.L', 'WeaponCarrier']
LOWER = ['Root', 'Hips', 'Leg.L', 'Leg.R']

def curves(action):
    return [c for l in action.layers for s in l.strips for b in s.channelbags for c in b.fcurves]

def digest(action):
    return hashlib.sha256(repr(([(c.data_path, c.array_index,
        [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation,
          k.handle_left_type, k.handle_right_type) for k in c.keyframe_points])
        for c in curves(action)], [(m.name, m.frame) for m in action.pose_markers],
        dict(action.items()))).encode()).hexdigest()

def geometry():
    return {o.name: hashlib.sha256(repr(([(tuple(v.co), [(g.group, g.weight) for g in v.groups])
        for v in o.data.vertices], [tuple(p.vertices) for p in o.data.polygons])).encode()).hexdigest()
        for o in bpy.data.objects if o.type == 'MESH'}

def bones():
    return {b.name: ([list(row) for row in b.matrix_local], list(b.head_local), list(b.tail_local),
        b.parent.name if b.parent else None, b.use_deform) for b in rig.data.bones}

def sample(action, f):
    rig.animation_data.action = action
    for p in rig.pose.bones: p.matrix_basis = Matrix.Identity(4)
    scene.frame_set(int(f), subframe=f-int(f))
    bpy.context.view_layer.update()
    return {p.name: p.matrix_basis.copy() for p in rig.pose.bones}

def apply(pose):
    for p in rig.pose.bones: p.matrix_basis = pose[p.name]
    bpy.context.view_layer.update()

def key(action, f, names):
    rig.animation_data.action = action
    for n in names:
        p = rig.pose.bones[n]
        if n in ['Arm.R', 'Arm.L', 'WeaponCarrier']:
            p.keyframe_insert('location', frame=f, group=n)
        p.keyframe_insert('rotation_quaternion' if p.rotation_mode == 'QUATERNION'
            else 'rotation_euler', frame=f, group=n)

assert 'LongGunReady_Loop_V1' not in bpy.data.actions
backup = DEV.with_name('player_cuboid_weapon_animation_dev_before_ready_e1_' +
    datetime.datetime.now().strftime('%Y%m%d_%H%M%S') + '.blend')
shutil.copy2(DEV, backup)
protected = {'actions': {a.name: digest(a) for a in bpy.data.actions}, 'geometry': geometry(),
    'bones': bones(), 'backup': str(backup),
    'hold_resource_sha256': hashlib.sha256((BASE.parents[3] / 'game_mobile_3d/assets/characters/LongGunHold_V2.tres').read_bytes()).hexdigest()}
(BASE / 'ready_e1_protection.json').write_text(json.dumps(protected, indent=2))
ready = sample(bpy.data.actions['Draw_LongGun_V3_Final'], 14)
ready_world = {n: rig.pose.bones[n].matrix.copy() for n in UPPER}
holster = sample(bpy.data.actions['Holster_LongGun_V3_Final'], 1)
assert max(abs(ready[n][i][j]-holster[n][i][j]) for n in UPPER for i in range(4) for j in range(4)) < 2e-6

# The verified D5 endpoint is the runtime Hold_V2 pose, including its carrier frame.
hold = bpy.data.actions.new('LongGunHold_V2')
hold.use_fake_user = True
hold['source'] = 'Unmodified runtime LongGunHold_V2.tres, represented by verified Draw V3 endpoint'
for f in [1, 33]:
    apply(ready); key(hold, f, UPPER)
for c in curves(hold):
    for k in c.keyframe_points: k.interpolation = 'CONSTANT'

action = bpy.data.actions.new('LongGunReady_Loop_V1')
action.use_fake_user = True
# Nonuniform breath/maintenance beats: rise, small suspension, longer release, recover.
# Values are local-degree offsets, not a procedural oscillator or random noise.
beats = [
    (1,  (0, 0, 0),        (0, 0, 0)),
    (7,  (.46, .10, -.08), (.08, .015, -.012)),
    (12, (.70, .24, -.14), (.18, .045, -.028)),
    (19, (.12, .08, .04),  (.095, .025, .008)),
    (26, (-.38, -.16, .10),(-.09, -.03, .018)),
    (30, (-.16, -.07, .025),(-.055, -.016, .008)),
    (33, (0, 0, 0),        (0, 0, 0)),
]
chest_ref = ready_world['Chest']
for f, chest_deg, spine_deg in beats:
    apply(ready)
    rig.pose.bones['Spine'].matrix_basis = ready['Spine'] @ Euler(tuple(map(math.radians, spine_deg)), 'XYZ').to_matrix().to_4x4()
    rig.pose.bones['Chest'].matrix_basis = ready['Chest'] @ Euler(tuple(map(math.radians, chest_deg)), 'XYZ').to_matrix().to_4x4()
    bpy.context.view_layer.update()
    live_chest = rig.pose.bones['Chest'].matrix.copy()
    delta = live_chest @ chest_ref.inverted()
    # Arms + gun share one rigid correction: retain 38% of chest rotation and
    # 60% of its small translation. This keeps their mutual contact unchanged.
    q = Quaternion().slerp(delta.to_quaternion(), .38)
    control = q.to_matrix().to_4x4()
    pivot = chest_ref.translation
    control.translation = pivot + (live_chest.translation-pivot)*.60 - q @ pivot
    for n in ['Arm.R', 'Arm.L', 'WeaponCarrier']:
        rig.pose.bones[n].matrix = control @ ready_world[n]
    bpy.context.view_layer.update()
    # Neck takes most counterrotation; Head finishes stabilization. No translation bob.
    for n, retained in [('Neck', .30), ('Head', .10)]:
        p = rig.pose.bones[n]
        m = p.matrix.copy()
        m3 = Quaternion().slerp(delta.to_quaternion(), retained).to_matrix() @ ready_world[n].to_3x3()
        m = m3.to_4x4(); m.translation = p.matrix.translation
        p.matrix = m
        bpy.context.view_layer.update()
    key(action, f, UPPER)

for c in curves(action):
    for k in c.keyframe_points:
        k.interpolation = 'BEZIER'
        k.handle_left_type = k.handle_right_type = 'AUTO_CLAMPED'
    # Matched zero velocity at the wrap; no duplicate end frame in playback.
    for k in (c.keyframe_points[0], c.keyframe_points[-1]):
        k.handle_left_type = k.handle_right_type = 'FREE'
        k.handle_left = (k.co.x-1, k.co.y)
        k.handle_right = (k.co.x+1, k.co.y)
    mod = c.modifiers.new('CYCLES')
    mod.mode_before = mod.mode_after = 'REPEAT'
    c.update()
action['fps'] = 24
action['cycle_frames'] = 32
action['frame_range_note'] = 'Keys 1..33; play 1..32. Frame 33 duplicates frame 1.'
action['foundation'] = 'LongGunHold_V2; exact Draw V3 final / Holster V3 initial endpoint'
action['layer_contract'] = 'Upper only; preserve source lower bones. Add body deltas to locomotion, replace arms/carrier. Not yet integrated into gameplay.'
action['motion_concept'] = 'Chest-led shallow readiness maintenance; asymmetric rise/release; coordinated grip correction; calm stabilized gaze.'
action['control_retained_rotation'] = .38
action['head_retained_rotation'] = .10
assert all(digest(bpy.data.actions[n]) == h for n, h in protected['actions'].items())
assert geometry() == protected['geometry']
assert json.dumps(bones(), sort_keys=True) == json.dumps(protected['bones'], sort_keys=True)
sample(action, 1)
scene.render.fps = 24; scene.render.fps_base = 1
scene.frame_start = 1; scene.frame_end = 32
scene.use_preview_range = True; scene.frame_preview_start = 1; scene.frame_preview_end = 32
if bpy.context.object and bpy.context.object.mode != 'OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects: o.select_set(False)
rig.select_set(True); bpy.context.view_layer.objects.active = rig
for area in bpy.context.screen.areas:
    if area.type == 'DOPESHEET_EDITOR': area.spaces.active.mode = 'ACTION'
bpy.ops.wm.save_as_mainfile(filepath=str(DEV), check_existing=False)
result = {'action': action.name, 'frames': [1,33], 'playback': [1,32], 'seconds':32/24,
          'bones': UPPER, 'protected_actions': len(protected['actions']), 'backup':str(backup)}
