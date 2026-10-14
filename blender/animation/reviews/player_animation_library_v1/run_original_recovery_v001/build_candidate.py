"""Copy approved original Run; author new rigid recovery pitch, preserving sole Z."""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent
ROOT = Path(json.loads((OUT/'preservation_before.json').read_text())['project'])
sys.path.insert(0, str(ROOT / 'blender/animation/showcase'))
import gaf_animation_library as ui

BASE = 'Run_Snappy_Test_v001'
NAME = 'Run_Original_Recovery_Test_v001'
PERIOD = 17.0
ADVANCE = 0.0
manifest = json.loads((ROOT / 'blender/animation/showcase/animation_manifest.json').read_text())
entry = next(e for e in manifest['animations'] if e['action'] == BASE)
source = ROOT / entry['source']
assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['source_sha256']
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest() == entry['source_sha256'], 'Author only from the exact frozen approved source'
assert NAME not in bpy.data.actions, 'Never overwrite a previous experiment'
rig = bpy.data.objects[entry['source_rig']]
scene = bpy.context.scene
base = bpy.data.actions[BASE]
assert ui.action_signature(base) == entry['action_sha256']
before = {a.name: ui.action_signature(a) for a in bpy.data.actions}
rig.animation_data.action = base
rig.animation_data.action_slot = base.slots[0]

def phase_warp(q, duty):
    # Activity marker only: the target is independently authored below,
    # never a time-warped sample of the old recovery or proprietary source.
    return q + .001 if duty + .015 < q < .965 else q

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
def baseline_pitch(q, side):
    offset = 0 if side == 'L' else .5
    m = pose(1 + ((q+offset)%1)*PERIOD)['Leg.'+side]
    v=m.to_3x3().col[1]
    return math.degrees(math.atan2(v.y,-v.z))
def boundary(q,side):
    h=.0002
    y=baseline_pitch(q,side);before=baseline_pitch(q-h,side);after=baseline_pitch(q+h,side)
    return (q,y,(after-before)/(2*h),(after-2*y+before)/(h*h))
# Original pose/timing decisions on our approved rig. No source-derived data.
interior=[(.49,38.5,0.,0.),(.60,9.,-400.,0.),(.66,-14.,-330.,0.),
          (.78,-36.5,-60.,0.),(.88,-38.4,80.,0.)]
knots={s:[boundary(entry['support_duty'][s]+.015,s)]+interior+[boundary(.965,s)] for s in ['L','R']}
def authored_pitch(q,side):
    points=knots[side]
    if q<=points[0][0] or q>=points[-1][0]:return baseline_pitch(q,side)
    for (x0,y0,v0,a0),(x1,y1,v1,a1) in zip(points,points[1:]):
        if x0<=q<=x1:
            h=x1-x0;u=(q-x0)/h
            c0=y0;c1=h*v0;c2=.5*h*h*a0
            A=y1-c0-c1-c2;B=h*v1-c1-2*c2;C=h*h*a1-2*c2
            c3=10*A-4*B+.5*C;c4=-15*A+7*B-C;c5=6*A-3*B+.5*C
            return c0+u*(c1+u*(c2+u*(c3+u*(c4+u*c5))))
    raise AssertionError(q)
def target(frame, side):
    u = (frame - 1) / PERIOD
    current = pose(frame)
    offset = 0. if side == 'L' else .5
    name = 'Leg.' + side
    q = (u - offset) % 1
    world = current[name].copy()
    if phase_warp(q, entry['support_duty'][side]) != q:
        old_direction=world.to_3x3().col[1]
        old_pitch=math.atan2(old_direction.y,-old_direction.z)
        angle=math.radians(authored_pitch(q,side))-old_pitch
        rotated=Matrix.Rotation(angle,4,'X')@world
        rotated.translation=world.translation
        # Preserve lateral sole track and exact low clearance while changing
        # sagittal angle around the existing native leg origin.
        old_center=world@Vector((0,.675,0));new_center=rotated@Vector((0,.675,0))
        rotated.translation.x += old_center.x-new_center.x
        rotated.translation.z += min((world@p).z for p in corners)-min((rotated@p).z for p in corners)
        world=rotated
    bone=rig.data.bones[name];parent=bone.parent
    basis=bone.convert_local_to_pose(world,bone.matrix_local,parent_matrix=current[parent.name],parent_matrix_local=parent.matrix_local,invert=True)
    p,rotation,scale=basis.decompose()
    assert max(abs(x-1) for x in scale)<1e-5
    return (list(p),list(rotation.to_euler('XYZ'))),world,current[name]

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
                    root = (lo + hi) / 2
                    q = ((root-1)/PERIOD - (0 if side=='L' else .5)) % 1
                    if abs(phase_warp(q, entry['support_duty'][side])-q) > 1e-10:
                        roots.append(root)
                previous = value
    # Blender's FCurve.update merges keys closer than .01 frame. Leave a
    # complete interval around each analytical cusp so its value survives.
    roots = sorted(set(roots))
    roots = [r for i, r in enumerate(roots) if i == 0 or r-roots[i-1] > .0101]
    grid = [f for f in grid if not any(abs(f-r) < .0101 for r in roots)]
    times[name] = sorted(grid + roots)
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
    original_curve = next(c for c in ui.curves(base) if c.data_path == curve.data_path and c.array_index == curve.array_index)
    values = [row[channel][curve.array_index] for row in records[name]]
    values[-1] = values[0]
    keys = curve.keyframe_points
    keys.clear()
    keys.add(len(values))
    for i, (key, value) in enumerate(zip(keys, values)):
        frame = times[name][i]
        q = ((frame-1)/PERIOD - (0 if name[-1]=='L' else .5)) % 1
        unchanged = abs(phase_warp(q, entry['support_duty'][name[-1]])-q) < 1e-12
        if unchanged:
            original_key = original_curve.keyframe_points[round((frame-1)*64)]
            key.co = original_key.co
            key.handle_left_type = original_key.handle_left_type
            key.handle_right_type = original_key.handle_right_type
            key.interpolation = original_key.interpolation
            key.handle_left = original_key.handle_left
            key.handle_right = original_key.handle_right
            continue
        left = values[i-1] if i else values[-2]
        right = values[i+1] if i < len(values)-1 else values[1]
        left_t = times[name][i-1] if i else times[name][-2]-PERIOD
        right_t = times[name][i+1] if i < len(values)-1 else times[name][1]+PERIOD
        epsilon = min(.0005, (frame-left_t)/4, (right_t-frame)/4)
        sample_before = target(frame-epsilon, name[-1])[0][channel][curve.array_index]
        after = target(frame+epsilon, name[-1])[0][channel][curve.array_index]
        slope_left = slope_right = (after-sample_before)/(2*epsilon)
        if frame in cusps[name]:
            slope_left = (value-sample_before)/epsilon
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
dest = OUT / 'run_original_recovery_review.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(dest), relative_remap=False, compress=True)
report = dict(action=NAME, baseline=BASE, baseline_source=entry['source'],
              baseline_source_sha256=entry['source_sha256'],baseline_action_sha256=entry['action_sha256'],
              action_sha256=ui.action_signature(candidate),source_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),
              original_actions=before,duration_s=PERIOD/30,support_duty=entry['support_duty'],contact_frames=entry['contact_frames'],
              upper_body='Exact copied curves and world poses',sole_vertical_envelope='Preserved in world space',
              original_pitch_knots=knots,pitch_units='degrees of native sagittal world orientation',
              authoring='Original quintic Hermite event segments from our rig/baseline; unchanged support and late placement. No proprietary file/sample inputs.',
              recovery='Shorter rear dwell; earlier gathered crossing during opposite-step rebound; broadened opening and braking; same cadence/clearance')
(OUT/'authoring.json').write_text(json.dumps(report,indent=2))
print('CANDIDATE_CREATED',NAME,report['source_sha256'],flush=True)
