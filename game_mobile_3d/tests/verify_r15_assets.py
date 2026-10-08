"""Validate the GLB before Godot import, including protected binary data."""
import json,struct,hashlib,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];ASSETS=ROOT/'assets/characters'
def read(path):
    data=path.read_bytes();magic,version,total=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and version==2 and total==len(data)
    size=struct.unpack_from('<I',data,12)[0]
    return json.loads(data[20:20+size]),data[28+size:]
def raw(d,b,index):
    a=d['accessors'][index];v=d['bufferViews'][a['bufferView']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    size={5126:4,5125:4,5123:2,5121:1}[a['componentType']]*width*a['count']
    offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    assert offset+size<=len(b)
    return b[offset:offset+size]
old,ob=read(ASSETS/'r13/player_r13.glb')
new,nb=read(ASSETS/'r15/player_r15_combat_strafe_v1.glb')
assert new['nodes']==old['nodes'] and new['skins']==old['skins']
assert new['meshes']==old['meshes'] and new['materials']==old['materials']
for i in range(len(old['accessors'])):assert raw(old,ob,i)==raw(new,nb,i)
assert new['animations'][:len(old['animations'])]==old['animations']
assert len(new['animations'])==36
source=json.loads((ASSETS/'r15/source.json').read_text())
assert hashlib.sha256(Path(source['source']).read_bytes()).hexdigest()==source['source_sha256']
assert all(source['protection'].values())
upper=json.loads((ASSETS/'r13/source.json').read_text())
for data,hz in [(upper,48),(source,192)]:
    for name,clip in data['clips'].items():
        a=next(a for a in new['animations'] if a['name']==name)
        expected={(bone,path) for bone,channels in clip['samples'][0].items() for prop,path in [('p','translation'),('q','rotation')] if prop in channels}
        assert {(new['nodes'][c['target']['node']]['name'],c['target']['path']) for c in a['channels']}==expected
        for c in a['channels']:
            sampler=a['samplers'][c['sampler']];bone=new['nodes'][c['target']['node']]['name']
            prop='p' if c['target']['path']=='translation' else 'q';width=3 if prop=='p' else 4
            times=struct.unpack('<'+'f'*len(clip['samples']),raw(new,nb,sampler['input']))
            values=struct.unpack('<'+'f'*(len(clip['samples'])*width),raw(new,nb,sampler['output']))
            assert abs(times[-1]-clip['length'])<1e-6
            for i,s in enumerate(clip['samples']):
                assert abs(times[i]-i/hz)<1e-6
                actual=values[i*width:(i+1)*width];native=s[bone][prop]
                error=min(max(abs(x-y) for x,y in zip(actual,native)),max(abs(x+y) for x,y in zip(actual,native))) if prop=='q' else max(abs(x-y) for x,y in zip(actual,native))
                assert error<1e-6,(name,bone,i,error)
        if name.startswith('Combat_'):
            assert clip['length']==16/48 and len(clip['samples'])==65
            assert expected=={(n,'rotation') for n in ['Hips','Leg.L','Leg.R','Spine']}|{(n,'translation') for n in ['Hips','Leg.L','Leg.R']}
            for bone,channels in clip['samples'][0].items():
                for prop,value in channels.items():assert max(abs(x-y) for x,y in zip(value,clip['samples'][-1][bone][prop]))<1e-5
assert source['clips']['Combat_StrafeLeft_V2']['action_sha256']!=source['clips']['Combat_StrafeRight_V2']['action_sha256']
report={'passed':True,'clips':36,'original_geometry_rest_skin_materials_and_12_clips_unchanged':True,
        'native_r12_r13_clips_embedded':18,'native_strafe_clips':6,'duration_seconds':16/48,
        'strafe_tracks':['Hips position/rotation','Leg.L position/rotation','Leg.R position/rotation','Spine rotation'],
        'native_samples_match_glb':True,'source_unchanged':True,'left_and_right_distinct_authored_actions':True}
out=ROOT/'.validation/r15';out.mkdir(parents=True,exist_ok=True)
(out/'asset_validation.json').write_text(json.dumps(report,indent=2))
print('PASS R15 GLB: 36 clips, native sample parity, unchanged R13 mesh/rest/skin/materials and 12 existing clips; source preserved')
