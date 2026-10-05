import json,struct,hashlib
from pathlib import Path
from PIL import Image
base=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
r=json.loads((base/'weapon_cleanup_report.json').read_text());checks={}
for key,item in r.items():
 raw=Path(item['glb']).read_bytes();ln=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+ln]);ps=[p for m in g['meshes'] for p in m['primitives']]
 tris=sum(g['accessors'][p['indices']]['count']//3 for p in ps);assert tris==item['after_triangles']
 assert len(g['materials'])==1 and len(g['images'])==1 and 'bufferView' in g['images'][0]
 assert g['samplers'][0]['magFilter']==9728 and g['samplers'][0]['minFilter']==9984
 nodes={n['name']:n for n in g['nodes']}
 for n,(x,y,z) in item['markers_blender_m'].items():assert all(abs(a-b)<1e-6 for a,b in zip(nodes[n].get('translation',[0,0,0]),[x,z,-y]))
 assert nodes['Grip_Point'].get('translation',[0,0,0])==[0,0,0]
 assert ('Shotgun_Pump' in nodes)==(key=='Shotgun')
 lo=[float('inf')]*3;hi=[float('-inf')]*3
 for n in g['nodes']:
  if 'mesh' not in n:continue
  assert n.get('scale',[1,1,1])==[1,1,1] and n.get('rotation',[0,0,0,1])==[0,0,0,1]
  tr=n.get('translation',[0,0,0])
  for p in g['meshes'][n['mesh']]['primitives']:
   a=g['accessors'][p['attributes']['POSITION']]
   for i in range(3):lo[i]=min(lo[i],a['min'][i]+tr[i]);hi[i]=max(hi[i],a['max'][i]+tr[i])
 d={'width':hi[0]-lo[0],'length':hi[2]-lo[2],'height':hi[1]-lo[1]}
 assert all(abs(d[a]-item['dimensions_m'][a])<1e-6 for a in d)
 previews={};path=Path(item['blend'])
 for suffix in ['isometric','trigger_closeup']:
  f=path.with_name(path.stem+'_'+suffix+'.png');im=Image.open(f);assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255);previews[suffix]=str(f)
 checks[key]={'triangles':tris,'surfaces':len(ps),'material_count':1,'nearest_sampler':True,'markers_verified':True,'dimensions_verified':True,'previews':previews}
(base/'weapon_cleanup_glb_validation.json').write_text(json.dumps(checks,indent=2));print(json.dumps(checks,indent=2))
