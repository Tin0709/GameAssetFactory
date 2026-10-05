import struct,json,hashlib
from pathlib import Path
from PIL import Image
p=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/weapons/m4a1_blocky')
b=(p/'m4a1_blocky_v1.glb').read_bytes(); length,kind=struct.unpack_from('<II',b,12); g=json.loads(b[20:20+length])
primitives=[q for m in g['meshes'] for q in m['primitives']]
triangles=sum(g['accessors'][q['indices']]['count']//3 for q in primitives)
assert triangles==552 and len(g['materials'])==1 and len(primitives)==1
assert g['samplers'][0]['magFilter']==9728
imgs={}
for name in ['front','side','isometric']:
 im=Image.open(p/f'm4a1_blocky_{name}.png'); assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
 imgs[name]={'size':im.size,'alpha_range':im.getchannel('A').getextrema()}
assert Image.open(p/'m4a1_blocky_atlas_64.png').size==(64,64)
report={'glb_triangles':triangles,'glb_materials':len(g['materials']),'glb_draw_surfaces':len(primitives),'samplers':g['samplers'],'nodes':[{'name':x.get('name'),'translation':x.get('translation')} for x in g['nodes']],'previews':imgs,'character_files_sha256':{n:hashlib.sha256(Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/'+f).read_bytes()).hexdigest() for n,f in [('player','player/cuboid/player_cuboid_v6.blend'),('zombie','enemies/zombie/zombie_cuboid_v2.blend')]}}
(p/'runtime_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
