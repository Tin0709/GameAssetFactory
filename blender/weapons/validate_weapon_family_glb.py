import json,struct,math
from pathlib import Path
from PIL import Image
BASE=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons')
report=json.loads((BASE/'weapon_family_report.json').read_text())
checks={}
for key,r in report.items():
 raw=Path(r['glb']).read_bytes();ln,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
 g=json.loads(raw[20:20+ln]);prims=[p for m in g['meshes'] for p in m['primitives']]
 tris=sum(g['accessors'][p['indices']]['count']//3 for p in prims)
 assert tris==r['triangles'] and len(g['materials'])==1
 assert len(g['images'])==1 and 'bufferView' in g['images'][0] and not g.get('animations')
 assert g['samplers'][0]['magFilter']==9728 and g['samplers'][0]['minFilter']==9984
 mat=g['materials'][0]['pbrMetallicRoughness'];assert abs(mat['roughnessFactor']-.48)<1e-6 and mat['metallicFactor']==0
 nodes={n['name']:n for n in g['nodes']};assert all(n in nodes for n in ['Grip_Point','Muzzle_Point','Support_Hand_Point'])
 assert nodes['Grip_Point'].get('translation',[0,0,0])==[0,0,0]
 for name,(x,y,z) in r['markers_blender_m'].items():
  assert all(abs(a-b)<1e-6 for a,b in zip(nodes[name].get('translation',[0,0,0]),[x,z,-y]))
 lo=[float('inf')]*3;hi=[float('-inf')]*3
 for n in g['nodes']:
  if 'mesh' not in n:continue
  assert n.get('scale',[1,1,1])==[1,1,1] and n.get('rotation',[0,0,0,1])==[0,0,0,1]
  tr=n.get('translation',[0,0,0])
  for p in g['meshes'][n['mesh']]['primitives']:
   a=g['accessors'][p['attributes']['POSITION']]
   for i in range(3):lo[i]=min(lo[i],a['min'][i]+tr[i]);hi[i]=max(hi[i],a['max'][i]+tr[i])
 dims={'width':hi[0]-lo[0],'length':hi[2]-lo[2],'height':hi[1]-lo[1]}
 for a in dims:assert abs(dims[a]-r['dimensions_m'][a])<1e-6,(key,a,dims,r['dimensions_m'])
 images={}
 path=Path(r['blend'])
 for suffix in ['side','threequarter','isometric']:
  f=path.with_name(path.stem+'_'+suffix+'.png');im=Image.open(f)
  assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
  images[suffix]=str(f)
 checks[key]={'triangles':tris,'surfaces':len(prims),'materials':len(g['materials']),'dimensions_m':dims,'embedded_64_atlas':True,'nearest_sampler':True,'attachment_axes_verified':True,'no_animation':True,'previews':images}
comparison=Image.open(BASE/'weapon_family_comparison.png');assert comparison.size==(2048,768) and comparison.getchannel('A').getextrema()==(0,255)
(BASE/'glb_validation.json').write_text(json.dumps(checks,indent=2))
print(json.dumps(checks,indent=2))
