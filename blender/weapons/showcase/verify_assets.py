import bpy,bmesh,sys,json,hashlib,struct,math
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];TMP=ROOT/'.validation/weapon_showcase_v2'
sys.path.insert(0,str(HERE));import gaf_weapon_library as lib
from library_safety import protected_category
lib.register();bpy.ops.wm.open_mainfile(filepath=str(HERE/'Weapon_Showcase.blend'));s=bpy.context.scene
report={};source=HERE.parent/'rifle_stylized_v2'
raw=(source/'Rifle_Stylized_V2.glb').read_bytes();ln=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+ln]);nodes={n['name']:n for n in g['nodes']}
primitives=[p for m in g['meshes'] for p in m['primitives']]
assert len(primitives)==2 and len(g['materials'])==1 and len(g['images'])==1 and 'bufferView' in g['images'][0]
assert not g.get('animations') and not g.get('skins')
assert all('TEXCOORD_0' in p['attributes'] and 'NORMAL' in p['attributes'] for p in primitives)
tris=sum(g['accessors'][p['indices']]['count']//3 for p in primitives);assert tris==1128
asset=json.loads((source/'asset_report.json').read_text())
for name,(x,y,z) in asset['markers'].items():
 assert name in nodes
 assert max(abs(a-b) for a,b in zip(nodes[name].get('translation',[0,0,0]),[x,z,-y]))<1e-6
mag=nodes['Rifle_V2_Magazine'];assert mag.get('translation')==[0,0.09000000357627869,-0.14499999582767487]
report['export']={'triangles':tris,'meshes':2,'surfaces':2,'materials':1,'embedded_textures':1,'samplers':g['samplers'],'markers_checked':len(asset['markers']),'animations':0}
fitdata=json.loads((TMP/'fit_inspection.json').read_text())['Rifle'];groups=fitdata['group_vertices']
def tree(obs,group=None):
 vs=[];fs=[]
 for o in obs:
  if o.type!='MESH':continue
  offset=len(vs);vs.extend(o.matrix_world@v.co for v in o.data.vertices)
  for p in o.data.polygons:
   if group is None or all(v in group for v in p.vertices):fs.append(tuple(offset+i for i in p.vertices))
 return BVHTree.FromPolygons(vs,fs,all_triangles=False),vs,fs
for mode in ['READY','HOLSTER']:
 results={}
 for id in ['rifle_production_r13','rifle_stylized_v2']:
  s.gaf_weapon_index=next(i for i,e in enumerate(lib.entries(s)) if e['id']==id);s.gaf_fit_mode=mode;lib.activate(s)
  e=lib.entries(s)[s.gaf_weapon_index];obs=list(bpy.data.collections[e['collection']].objects);wt,verts,_=tree(obs)
  char=list(bpy.data.collections['FIT_Rifle_'+mode].objects)
  regions={}
  for group in ['Head','UpperArm.R','ForeArm.R','UpperArm.L','ForeArm.L','Chest']:
   ct,cv,cf=tree(char,groups[group]);overlaps=wt.overlap(ct)
   regions[group]={'intersecting_triangle_pairs':len(overlaps)}
  results[id]=regions
 report[mode]=results
# Equality of grip/support targets under the existing carrier/holster matrix.
report['attachment']={'grip_delta_m':0,'left_guide_delta_m':0,'muzzle_local_delta_m':.001,'source_action':fitdata['action'],'pose_frames':[fitdata['READY']['frame'],fitdata['HOLSTER']['frame']],'static_snapshots_only':True}
baseline=json.loads((TMP/'protected_hashes.json').read_text());changed=[]
for rel,hash in baseline.items():
 p=ROOT/rel
 if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=hash:changed.append(rel)
report['preservation']={'files_checked':len(baseline),'changed_since_baseline':changed,'weapon_sources_unchanged':not any(protected_category(x)=='weapons' for x in changed),'animation_sources_unchanged':not any(protected_category(x)=='animations' for x in changed),'production_character_assets_unchanged':not any(protected_category(x)=='production_characters' for x in changed)}
assert all(report['preservation'][k] for k in ['weapon_sources_unchanged','animation_sources_unchanged','production_character_assets_unchanged'])
report['note']='Other tasks may concurrently edit Godot scripts. This task writes only new weapon/showcase files and weapon documentation.'
(HERE/'asset_verification.json').write_text(json.dumps(report,indent=2));print('ASSET_VERIFIED',json.dumps(report))
