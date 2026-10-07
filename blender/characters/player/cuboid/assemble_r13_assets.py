"""New approved body plus unchanged production locomotion/rollback clips."""
import copy, json, struct
from pathlib import Path
BASE=Path(__file__).resolve().parent
ASSETS=BASE.parents[3]/'game_mobile_3d/assets/characters'
OUT=ASSETS/'r13'

def read(path):
    data=path.read_bytes();n=struct.unpack_from('<I',data,12)[0]
    return json.loads(data[20:20+n]),bytearray(data[28+n:])

d,b=read(OUT/'body_raw.glb');old,ob=read(ASSETS/'player_cuboid_animated_v5.glb')
for node in d['nodes']:
    if node.get('name')=='R13_Export_Rig':node['name']='Player_Cuboid_Rig'
    if node.get('name')=='R13_Export_Base':node['name']='Player_Cuboid_Base'
names={n['name']:i for i,n in enumerate(d['nodes'])}
offset=len(b);b+=ob;vo=len(d['bufferViews']);ao=len(d['accessors'])
for view in old['bufferViews']:
    view=copy.deepcopy(view);view['byteOffset']=offset+view.get('byteOffset',0);d['bufferViews'].append(view)
for ac in old['accessors']:
    ac=copy.deepcopy(ac);ac['bufferView']+=vo;d['accessors'].append(ac)
d['animations']=[]
for animation in old['animations']:
    a=copy.deepcopy(animation)
    for s in a['samplers']:s['input']+=ao;s['output']+=ao
    for c in a['channels']:c['target']['node']=names[old['nodes'][c['target']['node']]['name']]
    d['animations'].append(a)
d['buffers']=[{'byteLength':len(b)}]
j=json.dumps(d,separators=(',',':')).encode();j+=b' '*((-len(j))%4);b+=b'\0'*((-len(b))%4)
(OUT/'player_r13.glb').write_bytes(struct.pack('<III',0x46546c67,2,28+len(j)+len(b))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(b),0x004e4942)+b)
print('R13 body assembled; unchanged production clips:',[a['name'] for a in d['animations']])
