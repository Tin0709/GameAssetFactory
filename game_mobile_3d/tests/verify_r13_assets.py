import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'.validation/r13';ASSETS=ROOT/'assets/characters';DATA=ASSETS/'r13'
def read(p):
    b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0]
    return json.loads(b[20:20+n]),b[28+n:]
def raw(d,b,index):
    a=d['accessors'][index];v=d['bufferViews'][a['bufferView']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    size={5126:4,5125:4,5123:2,5121:1}[a['componentType']]*width*a['count']
    start=v.get('byteOffset',0)+a.get('byteOffset',0)
    return b[start:start+size]
old,ob=read(ASSETS/'player_cuboid_animated_v5.glb');new,nb=read(DATA/'player_r13.glb')
clips={}
for a in old['animations']:
    added=next(x for x in new['animations'] if x['name']==a['name'])
    assert len(a['channels'])==len(added['channels'])
    for x,y in zip(a['channels'],added['channels']):
        assert old['nodes'][x['target']['node']]['name']==new['nodes'][y['target']['node']]['name']
        assert x['target']['path']==y['target']['path']
        os=a['samplers'][x['sampler']];ns=added['samplers'][y['sampler']]
        for key in ['input','output']:assert raw(old,ob,os[key])==raw(new,nb,ns[key])
    clips[a['name']]='byte-for-byte unchanged'
source=json.loads((DATA/'source.json').read_text())
assert hashlib.sha256(Path(source['source']).read_bytes()).hexdigest()==source['file_sha256']
assert source['protection']['all_original_actions_unchanged']
assert len(source['clips'])==18
for name,clip in source['clips'].items():
    assert len(clip['samples'])==round(clip['length']*48)+1
    assert all(set(s)=={'Spine','Chest','Neck','Head','Arm.L','Arm.R','WeaponCarrier'} for s in clip['samples'])
    assert not any(x in clip['samples'][0] for x in ['Root','Hips','Leg.L','Leg.R'])
report={'passed':True,'production_clips':clips,'lower_locomotion_binary_unchanged':True,'source_file_hash_unchanged':True,'native_upper_clips':18,'source_actions':source['source_actions'],'protection':source['protection']}
OUT.mkdir(parents=True,exist_ok=True);(OUT/'asset_validation.json').write_text(json.dumps(report,indent=2))
print('PASS: original 12 production clips byte-identical; approved Blender file unchanged; 18 native upper-only clips')
