import json,struct,hashlib
from pathlib import Path
import numpy as np
ASSETS=Path(__file__).parents[1]/'assets/characters'
def read(name):
 b=(ASSETS/name).read_bytes();n=struct.unpack_from('<I',b,12)[0];return json.loads(b[20:20+n]),b[28+n:]
def data(d,b,i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']];dtype={5126:'<f4',5123:'<u2',5121:'u1',5125:'<u4'}[a['componentType']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 return np.frombuffer(b,dtype=dtype,count=a['count']*n,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).copy()
old,ob=read('player_cuboid_animated_v1.glb');new,nb=read('player_cuboid_animated_v2.glb')
mesh={}
for key,idx in old['meshes'][0]['primitives'][0]['attributes'].items():
 v=data(old,ob,idx);w=data(new,nb,new['meshes'][0]['primitives'][0]['attributes'][key]);mesh[key]=bool(np.array_equal(v,w))
assert all(mesh.values()),mesh
clips={}
for name in ['Idle','Run']:
 a=next(x for x in old['animations'] if x['name']==name);b=next(x for x in new['animations'] if x['name']==name)
 assert len(a['channels'])==len(b['channels'])
 for c,e in zip(a['channels'],b['channels']):
  assert old['nodes'][c['target']['node']]['name']==new['nodes'][e['target']['node']]['name'] and c['target']['path']==e['target']['path']
  s=a['samplers'][c['sampler']];t=b['samplers'][e['sampler']]
  assert s.get('interpolation','LINEAR')==t.get('interpolation','LINEAR')
  for field in ['input','output']:assert np.array_equal(data(old,ob,s[field]),data(new,nb,t[field]))
 clips[name]='identical channels, times, interpolation and values'
report={'mesh_attributes_identical':mesh,'clips':clips,'source_glb_unchanged_sha256':hashlib.sha256((ASSETS/'player_cuboid_animated_v1.glb').read_bytes()).hexdigest()}
(Path(__file__).parent/'holster_d2_asset_regression.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
