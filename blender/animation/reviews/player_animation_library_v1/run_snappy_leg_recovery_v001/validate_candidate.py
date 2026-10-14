"""Validate the saved experiment against the approved Action in the same source."""
import bpy
import hashlib
import itertools
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
sys.path.insert(0, str(ROOT / 'blender/animation/showcase'))
import gaf_animation_library as ui

BASE = 'Run_Snappy_Test_v001'
NAME = 'Run_Snappy_LegRecovery_Test_v001'
assert NAME in bpy.data.actions, 'Separate leg-recovery candidate is missing'
rig = bpy.data.objects['Showcase_Player_Rig']
mesh = bpy.data.objects['Showcase_Player_Mesh']
scene = bpy.context.scene
base, candidate = [bpy.data.actions[n] for n in [BASE, NAME]]
manifest = json.loads((ROOT / 'blender/animation/showcase/animation_manifest.json').read_text())
approved = next(e for e in manifest['animations'] if e['action'] == BASE)
assert ui.action_signature(base) == approved['action_sha256'], 'Approved Action changed'
assert hashlib.sha256((ROOT / approved['source']).read_bytes()).hexdigest() == approved['source_sha256']

def curve_record(c):
    return (c.data_path, c.array_index, c.extrapolation, c.auto_smoothing,
            [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation,
              k.handle_left_type, k.handle_right_type) for k in c.keyframe_points],
            [(m.type, m.mode_before, m.mode_after) for m in c.modifiers])

def is_leg(c):
    return c.data_path.startswith(('pose.bones["Leg.L"]', 'pose.bones["Leg.R"]'))

assert [curve_record(c) for c in ui.curves(base) if not is_leg(c)] == [curve_record(c) for c in ui.curves(candidate) if not is_leg(c)], 'Non-leg curves changed'
groups = {g.name: [v.index for v in mesh.data.vertices if any(w.group == g.index and w.weight > .999 for w in v.groups)] for g in mesh.vertex_groups}
groups = {n: ids for n, ids in groups.items() if ids}
soles = {side: [i for i in groups['Leg.' + side] if abs(mesh.data.vertices[i].co.z) < 1e-6] for side in ['L', 'R']}
adjacent = {frozenset(p) for p in [('Head', 'Chest'), ('Chest', 'UpperArm.L'), ('Chest', 'UpperArm.R'), ('UpperArm.L', 'ForeArm.L'), ('UpperArm.R', 'ForeArm.R'), ('Chest', 'Leg.L'), ('Chest', 'Leg.R')]}
pairs = [p for p in itertools.combinations(groups, 2) if frozenset(p) not in adjacent]

def sample(action, frame):
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    e = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [e.matrix_world @ v.co for v in e.data.vertices], {b.name: b.matrix.copy() for b in rig.pose.bones}

def separation(a, b, vertices, matrices):
    axes = [matrices[n].to_3x3().col[i].normalized() for n in [a, b] for i in range(3)]
    axes += [x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length > 1e-6]
    aa, bb = [[vertices[i] for i in groups[n]] for n in [a, b]]
    return max(max(min(p.dot(ax) for p in aa) - max(p.dot(ax) for p in bb), min(p.dot(ax) for p in bb) - max(p.dot(ax) for p in aa)) for ax in axes)

report = dict(samples=2177, upper_body_curves_exact=True, approved_action_exact=True,
              max_supported_vertex_error_m=0., max_sole_height_error_m=0.,
              minimum_floor_m=10., max_upper_body_world_error_m=0.,
              max_scale_error=0., overlaps={}, max_waist_separation_m=0.,
              frames=[], same_vertical_flight=True)
series = {n: [] for n in ['baseline', 'candidate']}
for j in range(2177):
    f = 1 + j / 128
    bv, bm = sample(base, f)
    cv, cm = sample(candidate, f)
    report['minimum_floor_m'] = min(report['minimum_floor_m'], min(v.z for v in cv))
    for n in bm:
        if n.startswith('Leg.'):
            report['max_scale_error'] = max(report['max_scale_error'], max(abs(x - 1) for x in cm[n].to_scale()))
        else:
            report['max_upper_body_world_error_m'] = max(report['max_upper_body_world_error_m'], max(abs(bm[n][r][c] - cm[n][r][c]) for r in range(4) for c in range(4)))
    for side in ['L', 'R']:
        bh, ch = [min(v[i].z for i in soles[side]) for v in [bv, cv]]
        report['max_sole_height_error_m'] = max(report['max_sole_height_error_m'], abs(bh - ch))
        if bh < .002:
            report['max_supported_vertex_error_m'] = max(report['max_supported_vertex_error_m'], max((bv[i] - cv[i]).length for i in groups['Leg.' + side]))
    for label, v, m in [('baseline', bv, bm), ('candidate', cv, cm)]:
        series[label].append({'phase': j / 2176, 'hip_z': m['Hips'].translation.z,
                              'feet_y': [sum(v[i].y for i in soles[s]) / len(soles[s]) for s in ['L', 'R']],
                              'hip_y': m['Hips'].translation.y})
    if j % 8 == 0:
        for a, b in pairs:
            depth = separation(a, b, cv, cm)
            if depth < -1e-5:
                key = a + '/' + b
                if depth < report['overlaps'].get(key, {}).get('depth_m', 0):
                    report['overlaps'][key] = {'frame': f, 'depth_m': depth}
        for side in ['L', 'R']:
            report['max_waist_separation_m'] = max(report['max_waist_separation_m'], separation('Chest', 'Leg.' + side, cv, cm))
    if j % 128 == 0:
        report['frames'].append({'frame': f, 'vertices': [list(p) for p in cv]})

report['exchange'] = {}
for label, rows in series.items():
    values = {}
    for side, offset, ix in [('L', 0, 0), ('R', .5, 1)]:
        ordered = sorted(((x['phase'] - offset) % 1, x['feet_y'][ix] - x['hip_y']) for x in rows[:-1])
        crosses = [q for (pq, py), (q, y) in zip(ordered, ordered[1:]) if .5 < q < .85 and py > 0 >= y]
        speed = [abs(b['feet_y'][ix] - a['feet_y'][ix]) * 3840 for a, b in zip(rows, rows[1:]) if .44 < (b['phase'] - offset) % 1 < .86]
        values[side] = {'passing_phase': crosses[0] if crosses else None, 'peak_exchange_speed_m_s': max(speed)}
    report['exchange'][label] = values
start, _ = sample(candidate, 1)
end, _ = sample(candidate, 18)
report['loop_pose_error_m'] = max((a - b).length for a, b in zip(start, end))
eps = .01
pre1, _ = sample(candidate, 18 - eps)
pre2, _ = sample(candidate, 18 - 2 * eps)
post1, _ = sample(candidate, 1 + eps)
post2, _ = sample(candidate, 1 + 2 * eps)
report['loop_second_order_velocity_error_m_s'] = max(((3*a-4*b+c)-(4*d-e-3*a)).length * 30 / (2*eps) for a,b,c,d,e in zip(start,pre1,pre2,post1,post2))
report['loop_raw_first_order_velocity_error_m_s'] = max(((a-b)-(d-a)).length*30/eps for a,b,d in zip(start,pre1,post1))
report['raw_first_order_under_legacy_006_guard'] = report['loop_raw_first_order_velocity_error_m_s'] < .006
report['source_sha256'] = hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
report['action_sha256'] = ui.action_signature(candidate)
report['passed'] = (report['max_supported_vertex_error_m'] < 1e-5 and report['max_sole_height_error_m'] < 5e-6
                    and report['minimum_floor_m'] > -1e-6 and report['max_upper_body_world_error_m'] < 1e-6
                    and report['max_scale_error'] < 2e-6 and not report['overlaps'] and report['max_waist_separation_m'] < .075
                    and report['loop_pose_error_m'] < 1e-6 and report['loop_second_order_velocity_error_m_s'] < .006
                    and all(report['exchange']['candidate'][s]['passing_phase'] < report['exchange']['baseline'][s]['passing_phase'] - .025 for s in ['L','R']))
(OUT / 'motion_validation.json').write_text(json.dumps(report, indent=2))
(OUT / 'motion_series.json').write_text(json.dumps(series))
print(json.dumps({k:v for k,v in report.items() if k != 'frames'}, indent=2), flush=True)
assert report['passed'], 'Candidate fails preservation, geometry, contact, loop or exchange gate'
