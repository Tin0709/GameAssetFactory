"""Real saved asset/export and prior-library preservation checks."""
import bpy,bmesh,json,struct,hashlib,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];SHOW=HERE.parent/'showcase';VAL=ROOT/'.validation/shotgun_stylized_v2'
assert (HERE/'Shotgun_Stylized_V2.blend').exists(),'New shotgun source is missing'
bpy.ops.wm.open_mainfile(filepath=str(HERE/'Shotgun_Stylized_V2.blend'))
root=bpy.data.objects['Shotgun_Stylized_V2'];c=bpy.data.collections['WEAPON_EXPORT']
assert root.get('review_status')=='Pending' and not bpy.data.actions
meshes=[o for o in c.objects if o.type=='MESH'];assert {o.name for o in meshes}=={'Shotgun_V2_Base','Shotgun_V2_Pump'}
count={}
for o in meshes:
 assert o.parent==root and max(abs(x-1) for x in o.scale)<1e-7 and max(abs(x) for x in o.rotation_euler)<1e-7
 bm=bmesh.new();bm.from_mesh(o.data);assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,o.name;bm.free()
 o.data.calc_loop_triangles();count[o.name]=len(o.data.loop_triangles)
assert sum(count.values())<=1400,count
materials={m for o in meshes for m in o.data.materials};assert len(materials)==1
mat=next(iter(materials));images=[n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE'];assert len(images)==1 and images[0].packed_file and list(images[0].size)==[64,64]
base=bpy.data.objects['Shotgun_V2_Base'];pump=bpy.data.objects['Shotgun_V2_Pump']
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
length=max(p.y for p in points)-min(p.y for p in points);assert .85<=length<=1.0,length
assert max(p.x for p in points)-min(p.x for p in points)<.08
def region(name):
 group=base.vertex_groups[name].index
 return [v.co for v in base.data.vertices if any(w.group==group and w.weight>.5 for w in v.groups)]
barrel_bottom=min(v.z for v in region('HollowLongBarrel'))
tube_gap=barrel_bottom-max(v.z for v in region('MagazineTube'))
pump_gap=barrel_bottom-max((pump.matrix_local@v.co).z for v in pump.data.vertices)
assert 0<tube_gap<.003 and 0<pump_gap<.0015,('Barrel/lower assembly gap is too wide',tube_gap,pump_gap)
guide=bpy.data.objects['LeftHandGuide'].location;pp=[pump.matrix_local@v.co for v in pump.data.vertices]
assert min(p.y for p in pp)<guide.y<max(p.y for p in pp) and min(p.z for p in pp)<guide.z<max(p.z for p in pp)
bpy.context.view_layer.update();saved=base.matrix_local.copy();pos=pump.location.copy();pump.location.y-=.055;bpy.context.view_layer.update()
assert max(abs(base.matrix_local[i][j]-saved[i][j]) for i in range(4) for j in range(4))<1e-7
assert min((pump.matrix_local@v.co).y for v in pump.data.vertices)>.19,'Pump travel intersects receiver'
pump.location=pos;bpy.context.view_layer.update()
raw=(HERE/'Shotgun_Stylized_V2.glb').read_bytes();g=json.loads(raw[20:20+struct.unpack_from('<I',raw,12)[0]])
assert len(g['meshes'])==2 and len(g['materials'])==1 and len(g['images'])==1 and 'bufferView' in g['images'][0]
assert not g.get('animations') and not g.get('skins')
asset=json.loads((HERE/'asset_report.json').read_text());nodes={n['name']:n for n in g['nodes']}
for name,(x,y,z) in asset['markers'].items():assert name in nodes and max(abs(a-b) for a,b in zip(nodes[name].get('translation',[0,0,0]),[x,z,-y]))<1e-6,name
triangles=sum(g['accessors'][p['indices']]['count']//3 for m in g['meshes'] for p in m['primitives']);assert triangles==sum(count.values())
assert all('NORMAL' in p['attributes'] and 'TEXCOORD_0' in p['attributes'] for m in g['meshes'] for p in m['primitives'])
assert g['samplers'][0]['magFilter']==9728
baseline=json.loads((VAL/'protected_hashes.json').read_text());changed=[rel for rel,h in baseline.items() if hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()!=h];assert not changed,changed
if '--asset-only' not in sys.argv:
 manifest=json.loads((SHOW/'weapon_manifest.json').read_text());entry=next(e for e in manifest['weapons'] if e['id']=='shotgun_stylized_v2')
 assert entry['status']=='Pending' and entry['source_sha256']==hashlib.sha256((HERE/'Shotgun_Stylized_V2.blend').read_bytes()).hexdigest()
 old=json.loads((VAL/'manifest_before.json').read_text())
 for e in old['weapons']:assert next(x for x in manifest['weapons'] if x['id']==e['id'])==e,('Existing entry changed',e['id'])
 for key,value in old.items():
  if key not in ['weapons','default_selection']:assert manifest[key]==value,('Library metadata changed',key)
 assert manifest['default_selection']=='shotgun_stylized_v2'
report={'passed':True,'triangles':triangles,'parts':count,'materials':1,'texture':[64,64],'markers':len(asset['markers']),'pump_travel_m':.055,'protected_files':len(baseline),'changed':changed,'actions':0}
(HERE/'verification.json').write_text(json.dumps(report,indent=2));print('SHOTGUN_VERIFIED',json.dumps(report))
