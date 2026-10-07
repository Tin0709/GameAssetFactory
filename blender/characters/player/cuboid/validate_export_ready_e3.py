"""Append validated Ready data to v3, preserving all previous rig/mesh/clip bytes."""
import json, struct, copy, math, hashlib
from pathlib import Path
import numpy as np
BASE = Path(__file__).resolve().parent
ASSETS = BASE.parents[3] / 'game_mobile_3d/assets/characters'
OUT = BASE / 'export/ready_e3'
# Reuse the established GLB sampling utilities, never execute the old exporter.
exec((BASE/'validate_export_holster_d2.py').read_text().split('p=ASSETS/')[0])
OUT = BASE / 'export/ready_e3'
records = json.loads((OUT/'source_samples.json').read_text())
old, ob = read(ASSETS/'player_cuboid_animated_v3.glb')
d, b = copy.deepcopy(old), bytearray(ob)
names = {n['name']:i for i,n in enumerate(d['nodes'])}
C = np.eye(4); C[:3,:3] = [[1,0,0],[0,0,1],[0,-1,0]]
reports = {}
for export_name, record in records.items():
    raw, rb = read(OUT/(export_name+'_raw.glb'))
    assert len(raw['animations']) == 1
    offset = len(b); offset += (-offset)%4; b += b'\0'*(offset-len(b)); b += rb
    vo, ao = len(d['bufferViews']), len(d['accessors'])
    for view in raw['bufferViews']:
        v = copy.deepcopy(view); v['byteOffset'] = offset+v.get('byteOffset',0); d['bufferViews'].append(v)
    for accessor in raw['accessors']:
        ac = copy.deepcopy(accessor); ac['bufferView'] += vo; d['accessors'].append(ac)
    a = copy.deepcopy(raw['animations'][0]); a['name'] = export_name
    a['channels'] = [c for c in a['channels'] if c['target']['path'] in record['channels'].get(raw['nodes'][c['target']['node']]['name'], [])]
    for s in a['samplers']: s['input'] += ao; s['output'] += ao
    for c in a['channels']: c['target']['node'] = names[raw['nodes'][c['target']['node']]['name']]
    a['extras'] = {k:v for k,v in record.items() if k != 'samples'}
    d['animations'].append(a)
    duration = max(float(values(d,b,s['input'])[-1,0]) for s in a['samplers'])
    assert abs(duration-record['duration']) < 1e-6
    assert all(d['nodes'][c['target']['node']]['name'] in record['channels'] and c['target']['path'] in ['translation','rotation'] for c in a['channels'])
    max_pos = max_angle = 0.0
    for s in record['samples']:
        actual = sample(d,b,a,s['time'])
        for name,m in s['bones'].items():
            expected = C@np.array(m); got = actual[name]
            max_pos = max(max_pos,float(np.linalg.norm(got[:3,3]-expected[:3,3])))
            cosine = (np.trace(got[:3,:3].T@expected[:3,:3])-1)/2
            max_angle = max(max_angle,math.degrees(math.acos(np.clip(cosine,-1,1))))
    assert max_pos < .0001 and max_angle < .12, (export_name,max_pos,max_angle)
    first, last = sample(d,b,a,0), sample(d,b,a,duration)
    seam = max(float(np.max(np.abs(first[n]-last[n]))) for n in record['channels'])
    assert seam < 1e-6, (export_name,seam)
    reports[export_name] = {'duration_seconds':duration, 'source_frames':record['source_frames'], 'channels':record['channels'],
        'source_samples':len(record['samples']), 'max_source_position_error_m':max_pos, 'max_source_rotation_error_deg':max_angle,
        'seam_matrix_error':seam, 'lower_tracks':0, 'scale_tracks':0}
assert {a['name'] for a in d['animations']} == {'Idle','Run','DrawLongGun','HolsterLongGun','LongGunReadyIdle','LongGunReadyRun'}
assert len(d['skins']) == 1 and len(d['meshes']) == 1
assert not any('camera' in n or 'light' in n or 'mixamo' in n['name'].lower() for n in d['nodes'])
write(ASSETS/'player_cuboid_animated_v4.glb',d,b)
check, cb = read(ASSETS/'player_cuboid_animated_v4.glb')
assert cb[:len(ob)] == ob
assert all(check[k] == old[k] for k in ['nodes','meshes','skins','materials','textures','images','scenes'])
assert check['animations'][:len(old['animations'])] == old['animations']
# Expected compositions use the byte-preserved production locomotion samples,
# rather than silently substituting the Blender base curves for those clips.
fixtures = []
source_fixtures = json.loads((OUT/'composition_samples.json').read_text())
source_composition_error = {'position_m':0.0, 'rotation_deg':0.0}
parents = {child:i for i,n in enumerate(d['nodes']) for child in n.get('children',[])}
def local_frames(worlds):
    return {i:(np.linalg.inv(worlds[d['nodes'][parents[i]]['name']]) if i in parents else np.eye(4)) @ worlds[n['name']] for i,n in enumerate(d['nodes'])}
for original in source_fixtures:
    context, phase = original['context'], original['phase']
    base_clip = next(a for a in d['animations'] if a['name'] == context)
    upper_clip = next(a for a in d['animations'] if a['name'] == 'LongGunReady'+context)
    base_duration = max(float(values(d,b,s['input'])[-1,0]) for s in base_clip['samplers'])
    upper_duration = reports['LongGunReady'+context]['duration_seconds']
    base_local = local_frames(sample(d,b,base_clip,phase*base_duration))
    upper_local = local_frames(sample(d,b,upper_clip,phase*upper_duration))
    for name in original['bones']:
        idx = names[name]; node = d['nodes'][idx]
        rest = matrix(node.get('rotation',[0,0,0,1]),node.get('translation',[0,0,0]))
        base_local[idx] = base_local[idx] @ np.linalg.inv(rest) @ upper_local[idx] if name in ['Spine','Chest','Neck','Head'] else upper_local[idx]
    composed = {}
    def visit(i,parent):
        world = parent @ base_local[i]; composed[d['nodes'][i]['name']] = world
        for child in d['nodes'][i].get('children',[]): visit(child,world)
    for root in d['scenes'][0]['nodes']: visit(root,np.eye(4))
    fixtures.append({'context':context,'phase':phase,'bones':{name:composed[name].tolist() for name in original['bones']},
        'ready_locals':{name:upper_local[names[name]].tolist() for name in original['bones']}})
    for name, bone in original['bones'].items():
        expected = C@np.array(bone); actual = composed[name]
        source_composition_error['position_m'] = max(source_composition_error['position_m'],float(np.linalg.norm(actual[:3,3]-expected[:3,3])))
        cos = (np.trace(actual[:3,:3].T@expected[:3,:3])-1)/2
        source_composition_error['rotation_deg'] = max(source_composition_error['rotation_deg'],math.degrees(math.acos(np.clip(cos,-1,1))))
(OUT/'runtime_composition_samples.json').write_text(json.dumps(fixtures))
report = {'passed':True, 'export':str(ASSETS/'player_cuboid_animated_v4.glb'), 'clips':[a['name'] for a in d['animations']],
    'ready':reports, 'v3_mesh_rig_idle_run_draw_holster_byte_preserved':True,
    'retained_base_glb_vs_blender_composition_difference':source_composition_error,
    'legacy_hold_sha256':hashlib.sha256((ASSETS/'LongGunHold_V2.tres').read_bytes()).hexdigest()}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)); print(json.dumps(report,indent=2))
