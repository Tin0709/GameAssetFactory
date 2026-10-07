"""Assemble/validate isolated exports before Godot import. No production writes."""
import json, copy, math, hashlib
from pathlib import Path
import numpy as np
BASE = Path(__file__).resolve().parent
OUT = BASE / 'export/locomotion_r4g'
# Reuse the established binary/matrix readers, without executing the D2 task.
exec((BASE/'validate_export_holster_d2.py').read_text().split("p=ASSETS/")[0])
TARGET = BASE.parents[3]/'game_mobile_3d/assets/test/player_cuboid_locomotion_v2_test.glb'
NAMES = ['Walk','WalkTurnLeft','WalkTurnRight','Sprint','SprintTurnLeft','SprintTurnRight']

def validate():
    records = json.loads((OUT/'source_samples.json').read_text())
    doc, buf = read(OUT/'Walk_raw.glb')
    doc['animations'] = []
    node_ids = {n['name']:i for i,n in enumerate(doc['nodes'])}
    report = {'passed':True,'clips':{},'source_max_position_error_m':0.,'source_max_rotation_error_deg':0.}
    for name in NAMES:
        d,b = read(OUT/(name+'_raw.glb'))
        assert len(d['animations']) == 1 and len(d['skins']) == 1
        a = copy.deepcopy(d['animations'][0]); a['name'] = name
        channels = []
        for c in a['channels']:
            n = d['nodes'][c['target']['node']]['name']; path = c['target']['path']
            v = values(d,b,a['samplers'][c['sampler']]['output'])
            if path == 'scale':
                assert np.max(np.abs(v-1)) < 1e-6
                continue
            assert n in records[name]['bones'] or n == 'WeaponCarrier', (n,path)
            if n == 'WeaponCarrier':
                assert np.max(np.abs(v-v[0])) < 1e-6
                continue
            c['target']['node'] = node_ids[n]; channels.append(c)
        a['channels'] = channels
        offset = len(buf); offset += (-offset)%4; buf += b'\0'*(offset-len(buf)); buf += b
        vo,ao = len(doc['bufferViews']),len(doc['accessors'])
        for view in d['bufferViews']:
            view = copy.deepcopy(view); view['byteOffset'] = offset+view.get('byteOffset',0); doc['bufferViews'].append(view)
        for ac in d['accessors']:
            ac = copy.deepcopy(ac); ac['bufferView'] += vo; doc['accessors'].append(ac)
        for s in a['samplers']: s['input'] += ao; s['output'] += ao
        doc['animations'].append(a)
        duration = max(float(values(doc,buf,s['input'])[-1,0]) for s in a['samplers'])
        expected = (16 if name.startswith('Walk') else 13)/24
        assert abs(duration-expected) < 1e-6
        seam = 0.
        for c in channels:
            v = values(doc,buf,a['samplers'][c['sampler']]['output'])
            seam = max(seam,float(min(np.linalg.norm(v[0]-v[-1]),np.linalg.norm(v[0]+v[-1])) if c['target']['path']=='rotation' else np.linalg.norm(v[0]-v[-1])))
            if doc['nodes'][c['target']['node']]['name']=='Root': assert np.max(np.abs(v-v[0])) < 1e-6
        assert seam < 1e-5, (name,seam)
        C = np.eye(4); C[:3,:3] = [[1,0,0],[0,0,1],[0,-1,0]]
        for rec in records[name]['samples']:
            ws = sample(doc,buf,a,rec['time'])
            for bone,m in rec['bones'].items():
                actual, expected_m = ws[bone],C@np.array(m)
                report['source_max_position_error_m'] = max(report['source_max_position_error_m'],float(np.linalg.norm(actual[:3,3]-expected_m[:3,3])))
                angle = math.degrees(math.acos(np.clip((np.trace(actual[:3,:3].T@expected_m[:3,:3])-1)/2,-1,1)))
                report['source_max_rotation_error_deg'] = max(report['source_max_rotation_error_deg'],angle)
        report['clips'][name] = {'duration':duration,'seam_error':seam,'scale_tracks':0,'root_motion':False}
    assert report['source_max_position_error_m'] < .0001, report
    assert report['source_max_rotation_error_deg'] < .12, report
    assert len(doc['meshes']) == 1 and len(doc['skins']) == 1 and not doc.get('cameras')
    report['nodes'] = list(node_ids)
    assert set(node_ids) == {'Player_Cuboid_Rig','Player_Cuboid_Base','Root','Hips','Spine','Chest','Neck','Head','Arm.L','Arm.R','Leg.L','Leg.R','WeaponCarrier'}
    assert hashlib.sha256((BASE/'player_locomotion_turning_v2_study.blend').read_bytes()).hexdigest() == json.loads((OUT/'protection.json').read_text())['source_file_sha256']
    TARGET.parent.mkdir(parents=True,exist_ok=True); write(TARGET,doc,buf)
    (OUT/'glb_validation.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__ == '__main__': validate()
