"""Copy approved Run, retime only free-leg sagittal recovery, preserve sole Z."""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
sys.path.insert(0, str(ROOT / 'blender/animation/showcase'))
import gaf_animation_library as ui

BASE = 'Run_Snappy_Test_v001'
NAME = 'Run_Snappy_LegRecovery_Test_v001'
PERIOD = 17.0
ADVANCE = .080
manifest = json.loads((ROOT / 'blender/animation/showcase/animation_manifest.json').read_text())
entry = next(e for e in manifest['animations'] if e['action'] == BASE)
source = ROOT / entry['source']
assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['source_sha256']
assert Path(bpy.data.filepath).resolve() == source.resolve()
assert NAME not in bpy.data.actions, 'Never overwrite a previous experiment'
rig = bpy.data.objects[entry['source_rig']]
scene = bpy.context.scene
base = bpy.data.actions[BASE]
assert ui.action_signature(base) == entry['action_sha256']
before = {a.name: ui.action_signature(a) for a in bpy.data.actions}
rig.animation_data.action = base
rig.animation_data.action_slot = base.slots[0]

def phase_warp(q, duty):
    # C3 perturbation: identity near supported motion and placement. The
    # rising flank accelerates exchange; its falling flank brakes opening.
    start, end = duty + .02, .98
    if q <= start or q >= end:
        return q
    u = (q - start) / (end - start)
    return q + ADVANCE * math.sin(math.pi * u) ** 4

pose_cache = {}
def pose(frame):
    frame = 1 + (frame - 1) % PERIOD
    key = round(frame, 12)
    if key in pose_cache:
        return pose_cache[key]
    scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    result = {b.name: b.matrix.copy() for b in rig.pose.bones}
    pose_cache[key] = result
    return result

corners = [Vector((x, .675, z)) for x in [-.1125, .1125] for z in [-.1125, .1125]]
def target(frame, side):
    u = (frame - 1) / PERIOD
    current = pose(frame)
    offset = 0. if side == 'L' else .5
    if True:
        name = 'Leg.' + side
        q = (u - offset) % 1
        warped = phase_warp(q, entry['support_duty'][side])
        world = current[name].copy()
        if abs(warped - q) > 1e-12:
            mapped = pose(1 + ((warped + offset) % 1) * PERIOD)[name]
            old_direction = world.to_3x3().col[1]
            new_direction = mapped.to_3x3().col[1]
            old_pitch = math.atan2(old_direction.y, -old_direction.z)
            new_pitch = math.atan2(new_direction.y, -new_direction.z)
            angle = (new_pitch - old_pitch + math.pi) % (2 * math.pi) - math.pi
            rotated = Matrix.Rotation(angle, 4, 'X') @ world
            old_center = world @ Vector((0, .675, 0))
            mapped_center = mapped @ Vector((0, .675, 0))
            new_center = rotated @ Vector((0, .675, 0))
            rotated.translation.x += old_center.x - new_center.x
            rotated.translation.y += mapped_center.y - new_center.y
            rotated.translation.z += min((world @ p).z for p in corners) - min((rotated @ p).z for p in corners)
            world = rotated
        bone = rig.data.bones[name]
        parent = bone.parent
        basis = bone.convert_local_to_pose(world, bone.matrix_local,
                                          parent_matrix=current[parent.name],
                                          parent_matrix_local=parent.matrix_local, invert=True)
        p, rotation, scale = basis.decompose()
        assert max(abs(x - 1) for x in scale) < 1e-5
        return (list(p), list(rotation.to_euler('XYZ'))), world, current[name]

# Lowest-corner height is piecewise smooth at sole rocking changes. Insert
# its actual corner-switch times rather than rounding a cusp between keys.
records, times, cusps = {}, {}, {}
for side in ['L', 'R']:
    name = 'Leg.' + side
    grid = [1 + i / 64 for i in range(1089)]
    roots = []
    for which in [1, 2]:  # new and original world orientation
        for axis in [0, 2]:
            def sign_value(f):
                return target(f, side)[which].to_3x3().col[axis].z
            previous = sign_value(grid[0])
            for left, right in zip(grid, grid[1:]):
                value = sign_value(right)
                if previous * value < 0:
                    lo, hi, flo = left, right, previous
                    for _ in range(18):
                        mid = (lo + hi) / 2
                        fm = sign_value(mid)
                        if flo * fm <= 0:
                            hi = mid
                        else:
                            lo, flo = mid, fm
                    roots.append((lo + hi) / 2)
                previous = value
    times[name] = sorted(set(grid + roots))
    cusps[name] = set(roots)
    records[name] = [target(f, side)[0] for f in times[name]]

candidate = base.copy()
candidate.name = NAME
candidate.use_fake_user = True
for curve in ui.curves(candidate):
    name = next((n for n in records if curve.data_path.startswith('pose.bones["' + n + '"]')), None)
    if name is None:
        continue
    channel = 0 if curve.data_path.endswith('location') else 1
    values = [row[channel][curve.array_index] for row in records[name]]
    values[-1] = values[0]
    keys = curve.keyframe_points
    keys.clear()
    keys.add(len(values))
    for i, (key, value) in enumerate(zip(keys, values)):
        frame = times[name][i]
        left = values[i-1] if i else values[-2]
        right = values[i+1] if i < len(values)-1 else values[1]
        left_t = times[name][i-1] if i else times[name][-2]-PERIOD
        right_t = times[name][i+1] if i < len(values)-1 else times[name][1]+PERIOD
        slope_left = slope_right = (right-left)/(right_t-left_t)
        if frame in cusps[name]:
            epsilon = min(.0005, (frame-left_t)/4, (right_t-frame)/4)
            before = target(frame-epsilon, name[-1])[0][channel][curve.array_index]
            after = target(frame+epsilon, name[-1])[0][channel][curve.array_index]
            slope_left = (value-before)/epsilon
            slope_right = (after-value)/epsilon
        key.co = (frame, value)
        key.handle_left_type = key.handle_right_type = 'FREE'
        key.interpolation = 'BEZIER'
        dx_left, dx_right = (frame-left_t)/3, (right_t-frame)/3
        key.handle_left = (frame-dx_left, value-slope_left*dx_left)
        key.handle_right = (frame+dx_right, value+slope_right*dx_right)
    curve.update()
assert all(ui.action_signature(bpy.data.actions[n]) == sig for n, sig in before.items())
rig.animation_data.action = candidate
rig.animation_data.action_slot = candidate.slots[0]
scene.frame_start = 1
scene.frame_end = 17
scene.render.fps = 30
scene.frame_set(1)
dest = OUT / 'run_snappy_leg_recovery_review.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(dest), relative_remap=False, compress=True)
report = dict(action=NAME, baseline=BASE, baseline_source=entry['source'],
              baseline_source_sha256=entry['source_sha256'], baseline_action_sha256=entry['action_sha256'],
              action_sha256=ui.action_signature(candidate), source_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),
              original_actions=before, phase_advance_peak=ADVANCE, maximum_source_advance_ms=ADVANCE*PERIOD/30*1000,
              duration_s=PERIOD/30, support_duty=entry['support_duty'], contact_frames=entry['contact_frames'],
              upper_body='Exact copied curves', sole_vertical_envelope='Preserved in world space',
              warp='q + .080 sin^4(pi u), u=(q-duty-.02)/(.98-duty-.02), only inside free swing',
              reference='Running.mp4 F40–124 at original30FPS; contact/rig physics remain unknown')
(OUT / 'authoring.json').write_text(json.dumps(report, indent=2))
print('CANDIDATE_CREATED', NAME, report['source_sha256'], flush=True)
