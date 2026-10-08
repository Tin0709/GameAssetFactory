"""Read-only fresh-open source/GLB audit, writes only V3 validation evidence."""
import bpy
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('forest_v3_generator',HERE/'generator.py')
gen=importlib.util.module_from_spec(spec);spec.loader.exec_module(gen)
manifest=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
bpy.ops.wm.open_mainfile(filepath=str(HERE/'forest_canopy_v3.blend'))
result={'fresh_source_open':'PASS','source_sha256':hashlib.sha256((HERE/'forest_canopy_v3.blend').read_bytes()).hexdigest(),
        'assets':{},'v2_preservation':{},'art_status':'Awaiting user art review; Blender diagnostic is not gameplay evidence.'}
for name,entry in manifest['assets'].items():
    objects=list(bpy.data.collections[name].objects)
    assert len(objects)==(2 if name.startswith('tree') else 1)
    assert all(o.type=='MESH' and len(o.data.materials)==1 for o in objects)
    assert all(abs(x)<1e-6 for o in objects for x in o.rotation_euler)
    assert all(abs(x-1)<1e-6 for o in objects for x in o.scale)
    positions=[v.co[:] for o in objects for v in o.data.vertices]
    low=[min(p[a] for p in positions) for a in range(3)]
    high=[max(p[a] for p in positions) for a in range(3)]
    assert low==entry['bounds_blender_min'] and high==entry['bounds_blender_max']
    audits=[gen.mesh_audit(o) for o in objects]
    exported=gen.glb_audit(gen.OUT/(name+'.glb'))
    assert exported==entry['export']
    assert sum(a['triangles'] for a in audits)==exported['triangles']
    for obj in objects:
        assert obj.data.color_attributes.get('Color') is not None
        mat=obj.data.materials[0]
        assert mat.use_backface_culling
        assert any(n.type=='VERTEX_COLOR' and n.layer_name=='Color' for n in mat.node_tree.nodes)
    leaves=next(o for o in objects if o.name.endswith('__Leaves'))
    result['assets'][name]={'meshes':[o.name for o in objects],'source_geometry_checks':audits,'export':exported,
        'leaf_base_height_m':min(v.co.z for v in leaves.data.vertices),'validation':'PASS'}
v2=HERE.parent/'forest_canopy_v2'
v2_old=json.loads((v2/'validation_source.json').read_text(encoding='utf-8'))
assert hashlib.sha256((v2/'forest_canopy_v2.blend').read_bytes()).hexdigest()==v2_old['sha256_source']
result['v2_preservation']['forest_canopy_v2.blend']='SHA256 matches previous recorded audit'
for name,data in v2_old['assets'].items():
    path=gen.OUT.parent/'forest_canopy_v2'/(name+'.glb')
    assert hashlib.sha256(path.read_bytes()).hexdigest()==data['sha256_glb']
    result['v2_preservation'][path.name]='SHA256 matches previous recorded audit'
for name in manifest['assets']:
    contract=(gen.OUT/(name+'.glb.import')).read_text(encoding='utf-8')
    assert 'res://assets/environment/forest_canopy_v3/vertex_color_import.gd' in contract
    assert 'meshes/generate_lods=false' in contract
result['native_godot_import_contract']='All four import configs point to the local linear-color native material hook; engine validation belongs to parent integration.'
(HERE/'validation_source.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('FOREST_V3_FRESH_OPEN '+json.dumps({'assets':{n:{'triangles':a['export']['triangles'],'closed_meshes':len(a['source_geometry_checks']),'leaf_base':a['leaf_base_height_m']} for n,a in result['assets'].items()},'v2_preserved_files':len(result['v2_preservation']),'validation':'PASS'}))
