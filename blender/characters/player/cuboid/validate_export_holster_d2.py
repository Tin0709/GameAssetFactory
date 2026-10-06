import json,struct,copy,math
from pathlib import Path
import numpy as np
BASE=Path(__file__).parent
ASSETS=BASE.parents[3]/'game_mobile_3d/assets/characters'
def read(p):
 b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0];return json.loads(b[20:20+n]),bytearray(b[28+n:])
def write(p,d,b):
 d['buffers']=[{'byteLength':len(b)}];j=json.dumps(d,separators=(',',':')).encode();j+=b' '*((-len(j))%4);b+=b'\0'*((-len(b))%4)
 p.write_bytes(struct.pack('<III',0x46546c67,2,28+len(j)+len(b))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(b),0x004e4942)+b)
def values(d,b,idx):
 a=d['accessors'][idx];v=d['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 return np.frombuffer(b,dtype='<f4',count=a['count']*n,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,n)
def matrix(q,t):
 x,y,z,w=q;m=np.eye(4);m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]];m[:3,3]=t;return m
def sample(d,b,a,t):
 nodes=copy.deepcopy(d['nodes'])
 for c in a['channels']:
  s=a['samplers'][c['sampler']];ts=values(d,b,s['input'])[:,0];vs=values(d,b,s['output']);i=min(len(ts)-2,max(0,int(np.searchsorted(ts,t)-1)));u=np.clip((t-ts[i])/(ts[i+1]-ts[i]),0,1)
  v=vs[i]*(1-u)+vs[i+1]*u
  if c['target']['path']=='rotation':
   r=vs[i+1];r=-r if vs[i]@r<0 else r;v=vs[i]*(1-u)+r*u;v/=np.linalg.norm(v)
  nodes[c['target']['node']][c['target']['path']]=v.tolist()
 worlds={}
 def visit(i,parent):
  n=nodes[i];m=parent@matrix(n.get('rotation',[0,0,0,1]),n.get('translation',[0,0,0]));worlds[n['name']]=m
  for child in n.get('children',[]):visit(child,m)
 for root in d['scenes'][0]['nodes']:visit(root,np.eye(4))
 return worlds
p=ASSETS/'player_cuboid_animated_v2.glb';d,b=read(p);old,ob=read(ASSETS/'player_cuboid_animated_v1.glb')
assert len(d['scenes'])==1 and len(d['skins'])==1
for n in d['nodes']:
 if n['name']=='D2_Export_Rig':n['name']='Player_Cuboid_Rig'
 if n['name']=='D2_Export_Base':n['name']='Player_Cuboid_Base'
allowed={'Chest','Spine','Arm.L','Arm.R','Neck','Head','WeaponCarrier'}
a=d['animations'][0];a['name']='HolsterLongGun';a['channels']=[c for c in a['channels'] if d['nodes'][c['target']['node']]['name'] in allowed and c['target']['path'] in ['translation','rotation']]
# Keep existing approved runtime Idle/Run sampler values byte-for-byte.
offset=len(b);offset+=( -offset)%4;b+=b'\0'*(offset-len(b));b+=ob;vo=len(d['bufferViews']);ao=len(d['accessors'])
for v in old['bufferViews']:
 v=copy.deepcopy(v);v['byteOffset']=offset+v.get('byteOffset',0);d['bufferViews'].append(v)
for ac in old['accessors']:
 ac=copy.deepcopy(ac);ac['bufferView']+=vo;d['accessors'].append(ac)
names={n['name']:i for i,n in enumerate(d['nodes'])}
for old_a in old['animations']:
 if old_a['name'] not in ['Idle','Run']:continue
 added=copy.deepcopy(old_a)
 for s in added['samplers']:s['input']+=ao;s['output']+=ao
 for c in added['channels']:c['target']['node']=names[old['nodes'][c['target']['node']]['name']]
 d['animations'].append(added)
assert {a['name'] for a in d['animations']}=={'Idle','Run','HolsterLongGun'}
samples=json.loads((BASE/'holster_d2_source_samples.json').read_text());C=np.eye(4);C[:3,:3]=[[1,0,0],[0,0,1],[0,-1,0]]
max_pos=max_angle=0.0
for s in samples:
 ws=sample(d,b,a,s['time'])
 for name,m in s['bones'].items():
  expected=C@np.array(m);actual=ws[name];max_pos=max(max_pos,float(np.linalg.norm(actual[:3,3]-expected[:3,3])))
  cos=(np.trace(actual[:3,:3].T@expected[:3,:3])-1)/2;max_angle=max(max_angle,math.degrees(math.acos(np.clip(cos,-1,1))))
assert max_pos<.0001 and max_angle<.12,(max_pos,max_angle)
duration=float(values(d,b,a['samplers'][a['channels'][0]['sampler']]['input'])[-1,0]);assert abs(duration-17/24)<1e-6
report={'passed':True,'clips':[x['name'] for x in d['animations']],'duration':duration,'bones':[d['nodes'][j]['name'] for j in d['skins'][0]['joints']],'holster_bones':sorted(allowed),'holster_lower_tracks':0,'holster_scale_tracks':0,'source_max_position_error_m':max_pos,'source_max_rotation_error_deg':max_angle,'comparison_samples':len(samples),'idle_run_preserved_from_v1':True,'mesh_nodes':[n['name'] for n in d['nodes'] if 'mesh' in n],'node_names':[n['name'] for n in d['nodes']]}
write(p,d,b);(BASE/'holster_d2_glb_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))

