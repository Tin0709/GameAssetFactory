import json,struct
from pathlib import Path
from PIL import Image
p=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons/shotgun');r=json.loads((p/'blocky_shotgun_v4_report.json').read_text());raw=(p/'blocky_shotgun_v4.glb').read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n])
ps=[p for m in g['meshes'] for p in m['primitives']];tris=sum(g['accessors'][q['indices']]['count']//3 for q in ps);assert tris==508 and len(ps)==2 and len(g['materials'])==1 and len(g['images'])==1 and 'bufferView' in g['images'][0]
assert g['samplers'][0]['magFilter']==9728 and g['samplers'][0]['minFilter']==9984
nodes={n['name']:n for n in g['nodes']};assert 'Shotgun_Pump' in nodes and 'Blocky_Shotgun_Root' in nodes and 'Blocky_Shotgun_Base' in nodes
for name,(x,y,z) in r['markers_blender_m'].items():assert all(abs(a-b)<1e-6 for a,b in zip(nodes[name].get('translation',[0,0,0]),[x,z,-y]))
assert nodes['Grip_Point'].get('translation',[0,0,0])==[0,0,0]
lo=[float('inf')]*3;hi=[float('-inf')]*3
for node in g['nodes']:
 if 'mesh' not in node:continue
 assert node.get('scale',[1,1,1])==[1,1,1] and node.get('rotation',[0,0,0,1])==[0,0,0,1]
 tr=node.get('translation',[0,0,0])
 for q in g['meshes'][node['mesh']]['primitives']:
  a=g['accessors'][q['attributes']['POSITION']]
  for i in range(3):lo[i]=min(lo[i],a['min'][i]+tr[i]);hi[i]=max(hi[i],a['max'][i]+tr[i])
d={'width':hi[0]-lo[0],'height':hi[1]-lo[1],'length':hi[2]-lo[2]};assert all(abs(d[a]-r['dimensions_m'][a])<1e-6 for a in d)
for name in ['side','isometric','threequarter','trigger_closeup']:
 im=Image.open(p/f'blocky_shotgun_v4_{name}.png');assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
out={'triangles':tris,'draw_surfaces':2,'material_count':1,'embedded_atlas':True,'nearest_sampler':True,'runtime_names_and_axes_verified':True,'dimensions_verified':d,'transparent_previews_verified':True}
(p/'shotgun_v4_glb_validation.json').write_text(json.dumps(out,indent=2));print(json.dumps(out))
