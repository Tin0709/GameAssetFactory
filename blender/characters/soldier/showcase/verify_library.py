"""Fresh reopen of requested library; the candidate must remain byte-identical."""
import bpy,json,hashlib,struct
from pathlib import Path
HERE=Path(__file__).resolve().parent;R=HERE.parents[3]
D=R/'blender/characters/player/reviews/survivor_reference_v001'
FILE=HERE/'SOLDIER_Asset_Library.blend';candidate=D/'Survivor_Reference_v001.blend'
candidate_hash=hashlib.sha256(candidate.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(FILE),load_ui=False)
s=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];r=json.loads(s['soldier_registry']);m=json.loads((D/'model_validation.json').read_text())
assert s.name=='SOLDIER_ASSET_LIBRARY' and s['review_status']=='Pending'
assert len(r['entries'])>=1 and len({e['id'] for e in r['entries']})==len(r['entries'])
e=next(e for e in r['entries'] if e['id']=='SOLDIER_Skin_v001');c=bpy.data.collections[e['collection']]
assert c.asset_data and c['review_status']=='Pending'
assert c.preview.image_size[0]>0
assert len(c.objects)==4 and len([o for o in c.objects if o.type=='MESH'])==3
assert len(bpy.data.actions)==0 and len([o for o in c.objects if o.type=='ARMATURE'])==1
assert all(im.packed_file for im in bpy.data.images if im.type=='IMAGE')
assert {c.name for c in bpy.data.collections if c.asset_data}=={e['collection'] for e in r['entries']}
body=bpy.data.objects[e['body']];hair=bpy.data.objects[e['hair']];clothes=bpy.data.objects[e['clothing']]
raw=b''.join(struct.pack('<3f',*v.co) for v in body.data.vertices)+b''.join(struct.pack('<I',len(p.vertices))+struct.pack('<'+'I'*len(p.vertices),*p.vertices) for p in body.data.polygons)
assert hashlib.sha256(raw).hexdigest()==m['body_geometry_sha256']
assert hair['outer_relief_multiplier']==.8
assert all(o.data.materials[0]==body.data.materials[0] for o in [hair,clothes])
assert all(bpy.data.collections[n] in bpy.data.collections['SOLDIER_ASSETS'].children[:] for n in ['01_SKINS','02_HAIR_VARIANTS','03_CLOTHING_UPGRADES','04_EQUIPMENT','05_FUTURE_UPGRADES'])
assert c in bpy.data.collections['01_SKINS'].children[:]
assert s.camera.name=='Front_3Q'
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.ui_type=='ASSETS':
   assert area.spaces.active.type=='FILE_BROWSER' and area.spaces.active.asset_params,'Asset Browser must be GUI-initialized before saving'

assert hashlib.sha256(candidate.read_bytes()).hexdigest()==candidate_hash
assert hashlib.sha256((R/'blender/characters/player/cuboid/player_cuboid_v6.blend').read_bytes()).hexdigest()==m['body_source_sha256']
result={'passed':True,'fresh_reopen':True,'file':str(FILE),'registered_assets':len(r['entries']),'pending_assets':sum(e['status']=='Pending' for e in r['entries']),'complete_skin_objects':4,'character_meshes':3,'actions':0,'packed_images':len([im for im in bpy.data.images if im.packed_file]),'candidate_preserved':True,'source_preserved':True,'geometry_matches_verified_candidate':True,'body_triangles':m['triangles'],'clothing_triangles':m['clothing_triangles'],'hair_triangles':m['hair_triangles'],'total_skin_triangles':m['triangles']+m['clothing_triangles']+m['hair_triangles'],'reserved_future_groups':4}
(HERE/'validation.json').write_text(json.dumps(result,indent=2));print('LIBRARY_VALIDATION',json.dumps(result))
