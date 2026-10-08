"""Approved Pass 2 coverage and immutable source/production GLB contract."""
import json, hashlib, struct
from pathlib import Path
root = Path(__file__).resolve().parents[1]
data = json.loads((root/'assets/characters/r15/source.json').read_text())
names = ['Combat_StrafeLeft_V2', 'Combat_StrafeRight_V2'] + [f'Combat_Strafe{d}_V1' for d in ['ForwardLeft','ForwardRight','BackwardLeft','BackwardRight']]
assert set(data['clips']) == set(names), 'Approved six-direction Pass 2 set is missing'
assert hashlib.sha256(Path(data['source']).read_bytes()).hexdigest() == data['source_sha256']
for name in names:
    clip = data['clips'][name]
    assert clip['fps'] == 48 and clip['frames'] == [1,17]
    assert abs(clip['length'] - 16/48) < 1e-8 and len(clip['samples']) == 65
    assert set(clip['samples'][0]) == {'Hips','Leg.L','Leg.R','Spine'}
    for bone, channels in clip['samples'][0].items():
        for prop, values in channels.items():
            assert max(abs(a-b) for a,b in zip(values,clip['samples'][-1][bone][prop])) < 1e-5
def read(path):
    raw=path.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+size]), raw[28+size:]
old, old_binary = read(root/'assets/characters/r13/player_r13.glb')
new, new_binary = read(root/'assets/characters/r15/player_r15_combat_strafe_v1.glb')
for field in ['nodes','skins','meshes','materials']: assert new[field] == old[field]
assert new_binary[:len(old_binary)] == old_binary
assert new['animations'][:len(old['animations'])] == old['animations']
assert set(names).issubset({a['name'] for a in new['animations']})
print('PASS six native Pass 2 clips; loop closure; source SHA; preserved base GLB')
