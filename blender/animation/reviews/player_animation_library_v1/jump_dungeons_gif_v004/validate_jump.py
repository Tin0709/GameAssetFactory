"""Evaluate the live combined jump, ground support, body clearance and old data."""
import bpy
import json
import math
from itertools import combinations
from pathlib import Path
from bpy_extras.object_utils import world_to_camera_view

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]


def run(builder):
    manifest = json.loads((OUT/'manifest.json').read_text())
    scene = bpy.data.scenes[manifest['scene']]
    bpy.context.window.scene = scene
    rig = bpy.data.objects[manifest['rig']]
    mesh = bpy.data.objects[manifest['mesh']]
    carrier = bpy.data.objects[manifest['carrier']]
    pose, travel = rig.animation_data.action, carrier.animation_data.action
    groups = {g.name:[v.index for v in mesh.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)]
              for g in mesh.vertex_groups}
    soles = {n:[i for i in groups[n] if abs(mesh.data.vertices[i].co.z)<1e-5] for n in ['Leg.L','Leg.R']}
    adjacent = {frozenset(p) for p in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),
        ('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
    pairs = [p for p in combinations(groups,2) if frozenset(p) not in adjacent]

    def evaluate(f):
        scene.frame_set(int(f),subframe=f%1)
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        return [evaluated.matrix_world@v.co for v in evaluated.data.vertices]

    def separation(a,b,coords):
        aa = rig.pose.bones[a].matrix.to_3x3()
        bb = rig.pose.bones[b].matrix.to_3x3()
        axes = [aa.col[i].normalized() for i in range(3)]+[bb.col[i].normalized() for i in range(3)]
        axes += [x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-5]
        ca,cb = [[coords[i] for i in groups[n]] for n in [a,b]]
        return max(max(min(v.dot(ax) for v in ca)-max(v.dot(ax) for v in cb),
                       min(v.dot(ax) for v in cb)-max(v.dot(ax) for v in ca)) for ax in axes)

    # Evaluate an independent original neutral Action on the isolated new actor.
    # Neither the original actor nor its scene frame/selection needs to change.
    old = bpy.data.actions['Jump_Default_v001']
    rig.animation_data.action = old
    rig.animation_data.action_slot = old.slots[0]
    carrier.animation_data.action = None
    carrier.location = (0,0,0)
    idle = evaluate(1)
    overlap_baseline = {a+' / '+b:min(0,separation(a,b,idle)) for a,b in pairs}
    rig.animation_data.action = pose
    rig.animation_data.action_slot = pose.slots[0]
    carrier.animation_data.action = travel
    carrier.animation_data.action_slot = travel.slots[0]

    report = {'samples':0,'min_floor_z_m':100,'min_air_z_m':100,'max_ground_gap_m':0,
              'support_center_y_drift_m':0,'neutral_error_m':0,'new_overlaps':[],
              'baseline_overlaps_m':overlap_baseline,'camera_bounds':{},'preserved_actions':manifest['old_actions']}
    # Include between-key samples (1/128 offset) as well as exact phase boundaries.
    frames = sorted(set([1,6,14.5,23,25,32,36]+[1+i/16+1/128 for i in range(35*16) if 1+i/16+1/128<36]))
    support = {}
    for f in frames:
        coords = evaluate(f)
        low = min(v.z for v in coords)
        report['samples'] += 1
        report['min_floor_z_m'] = min(report['min_floor_z_m'],low)
        if f<=manifest['take'] or f>=manifest['contact']:
            report['max_ground_gap_m'] = max(report['max_ground_gap_m'],abs(low-.0003))
            y = sum(coords[i].y for i in soles['Leg.R'])/len(soles['Leg.R'])
            phase = 'launch' if f<=manifest['take'] else 'land'
            support.setdefault(phase,y)
            report['support_center_y_drift_m'] = max(report['support_center_y_drift_m'],abs(y-support[phase]))
        else:
            report['min_air_z_m'] = min(report['min_air_z_m'],low)
        if f in [1,36]:
            report['neutral_error_m'] = max(report['neutral_error_m'],
                max((v-carrier.location-w).length for v,w in zip(coords,idle)))
        assert all(abs(x-1)<1e-7 for p in rig.pose.bones for x in p.scale)
        # Every fourth sample is close to 1/4-frame, between carrier samples.
        if (f-1-1/128)*16%4 < 1e-5 or f in [1,6,14.5,23,25,32,36]:
            for a,b in pairs:
                sep = separation(a,b,coords)
                if sep < overlap_baseline[a+' / '+b]-1e-5:
                    report['new_overlaps'].append([f,a,b,sep])
            for name in manifest['cameras'].values():
                pts = [world_to_camera_view(scene,bpy.data.objects[name],v) for v in coords]
                bounds = report['camera_bounds'].setdefault(name,[1,1,0,0])
                bounds[:] = [min(bounds[0],min(v.x for v in pts)),min(bounds[1],min(v.y for v in pts)),
                             max(bounds[2],max(v.x for v in pts)),max(bounds[3],max(v.y for v in pts))]
    report['changed_originals'] = builder['compare_originals'](bpy.app.driver_namespace['jgif4_original_data'])
    original_rig = bpy.data.objects['JD1_Player_Rig']
    assert mesh.data == bpy.data.objects['JD1_Player_Mesh'].data
    assert all(b.matrix_local == original_rig.data.bones[b.name].matrix_local for b in rig.data.bones)
    assert not any(any(n in c.data_path for n in ['Root','Hips','scale']) for c in builder['curves'](pose))
    assert not rig.animation_data.nla_tracks and not rig.animation_data.drivers
    report['checks'] = {
        'old_data_preserved':not report['changed_originals'],
        'neutral_endpoints':report['neutral_error_m']<1e-6,
        'no_floor_penetration':report['min_floor_z_m']>=-1e-5,
        'ground_clearance':report['max_ground_gap_m']<.0005,
        'support_center_stable':report['support_center_y_drift_m']<.00005,
        'airborne':report['min_air_z_m']>0,
        'no_new_nonadjacent_overlap':not report['new_overlaps'],
        'camera_framing':all(min(b[:2])>.025 and max(b[2:])<.975 for b in report['camera_bounds'].values())}
    report['failures'] = [name for name,ok in report['checks'].items() if not ok]
    (OUT/'validation.json').write_text(json.dumps(report,indent=2))
    scene.frame_set(14)
    return {k:v for k,v in report.items() if k not in ['new_overlaps','baseline_overlaps_m','camera_bounds']}
