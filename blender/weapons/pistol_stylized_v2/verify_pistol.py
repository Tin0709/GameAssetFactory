"""Saved asset/export, rigid-part travel and preservation checks in real Blender."""
import bpy,bmesh,json,struct,hashlib,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];SHOW=HERE.parent/'showcase'
source=HERE/'Pistol_Stylized_V2.blend'
assert source.exists(),'Pistol_Stylized_V2 source has not been created'
bpy.ops.wm.open_mainfile(filepath=str(source))
c=bpy.data.collections['WEAPON_EXPORT'];root=bpy.data.objects['Pistol_Stylized_V2']
assert root.get('review_status')=='Pending' and not bpy.data.actions
meshes=[o for o in c.objects if o.type=='MESH'];assert len(meshes)==3
assert {o.name for o in meshes}=={'Pistol_V2_Frame','Pistol_V2_Slide','Pistol_V2_Magazine'}
materials={m for o in meshes for m in o.data.materials};assert len(materials)==1
topology={}
for o in meshes:
 assert o.parent==root and max(abs(x-1) for x in o.scale)<1e-7 and max(abs(x) for x in o.rotation_euler)<1e-7
 bm=bmesh.new();bm.from_mesh(o.data)
 assert all(e.is_manifold for e in bm.edges),(o.name,'open/nonmanifold component')
 assert not any(not v.link_faces for v in bm.verts)
 assert bm.calc_volume(signed=True)>0,(o.name,'inward normals')
 o.data.calc_loop_triangles();topology[o.name]=len(o.data.loop_triangles);bm.free()
assert sum(topology.values())<=1400,topology
mat=next(iter(materials));images=[n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE'];assert len(images)==1 and images[0].packed_file
assert list(images[0].size)==[64,64]
for part,travel in [('Pistol_V2_Slide',(0,-.018,0)),('Pistol_V2_Magazine',(0,-.035,-.11))]:
 bpy.context.view_layer.update()
 o=bpy.data.objects[part];before=o.location.copy();others={m.name:m.matrix_local.copy() for m in meshes if m!=o}
 o.location+=Vector(travel);bpy.context.view_layer.update()
 assert (o.location-before-Vector(travel)).length<1e-7
 assert all(max(abs(bpy.data.objects[n].matrix_local[i][j]-matrix[i][j]) for i in range(4) for j in range(4))<1e-7 for n,matrix in others.items())
 o.location=before;bpy.context.view_layer.update()
raw=(HERE/'Pistol_Stylized_V2.glb').read_bytes();size=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+size])
assert len(g['meshes'])==3 and len(g['materials'])==1 and len(g['images'])==1 and 'bufferView' in g['images'][0]
assert not g.get('skins') and not g.get('animations')
nodes={n['name']:n for n in g['nodes']};asset=json.loads((HERE/'asset_report.json').read_text())
for name,(x,y,z) in asset['markers'].items():
 assert name in nodes and max(abs(a-b) for a,b in zip(nodes[name].get('translation',[0,0,0]),[x,z,-y]))<1e-6,name
tris=sum(g['accessors'][p['indices']]['count']//3 for m in g['meshes'] for p in m['primitives'])
assert tris==sum(topology.values())
assert all('NORMAL' in p['attributes'] and 'TEXCOORD_0' in p['attributes'] for m in g['meshes'] for p in m['primitives'])
assert g['samplers'][0]['magFilter']==9728
baseline=json.loads((ROOT/'.validation/pistol_stylized_v2/protected_hashes.json').read_text())
changed=[rel for rel,h in baseline.items() if hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()!=h]
assert not changed,('Preserved file changed',changed)
if '--asset-only' not in sys.argv:
 manifest=json.loads((SHOW/'weapon_manifest.json').read_text())
 entry=next(e for e in manifest['weapons'] if e['id']=='pistol_stylized_v2')
 assert entry['kind']=='Pistol' and entry['status']=='Pending' and entry['source_sha256']==hashlib.sha256(source.read_bytes()).hexdigest()
 old=json.loads((ROOT/'.validation/pistol_stylized_v2/manifest_before.json').read_text())
 for e in old['weapons']:
  current=next(x for x in manifest['weapons'] if x['id']==e['id'])
  assert all(current[k]==v for k,v in e.items()),('Existing entry changed',e['id'])
report={'passed':True,'triangles':tris,'mesh_triangles':topology,'materials':1,'surfaces':3,'texture':[64,64],'markers':len(asset['markers']),'rigid_part_travel':'18mm slide; magazine extraction; stationary parts unchanged','protected_files':len(baseline),'changed':changed,'actions':0}
(HERE/'verification.json').write_text(json.dumps(report,indent=2));print('PISTOL_VERIFIED',json.dumps(report))
