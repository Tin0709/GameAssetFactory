"""Fresh-open source/GLB audit. Run with Blender --background --factory-startup --python."""
import bpy
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('forest_generator',HERE/'generator.py')
gen=importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)
bpy.ops.wm.open_mainfile(filepath=str(HERE/'forest_canopy_v2.blend'))
expected=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
result={'source_fresh_open':'PASS','assets':{},'glb_binary_audits':[],
        'art_status':'Original study; awaiting human review; Godot review handled by parent task.'}
for name,entry in expected['assets'].items():
    objects=list(bpy.data.collections[name].objects)
    assert len(objects)==(2 if name.startswith('tree') else 1)
    assert all(o.type=='MESH' for o in objects)
    assert all(len(o.data.materials)==1 for o in objects)
    assert all(o.data.color_attributes.get('Color') is not None for o in objects)
    assert all(not p.use_smooth for o in objects for p in o.data.polygons)
    assert all(abs(v-1)<1e-6 for o in objects for v in o.scale)
    assert all(abs(v)<1e-6 for o in objects for v in o.rotation_euler)
    verts=[v.co[:] for o in objects for v in o.data.vertices]
    low=[min(v[q] for v in verts) for q in range(3)]
    high=[max(v[q] for v in verts) for q in range(3)]
    tris=sum(len(p.vertices)-2 for o in objects for p in o.data.polygons)
    assert tris==entry['triangle_count']
    assert max(abs(low[q]-entry['bounds_blender_min'][q]) for q in range(3))<1e-6
    assert max(abs(high[q]-entry['bounds_blender_max'][q]) for q in range(3))<1e-6
    glb=gen.OUT/(name+'.glb')
    leaves=[o for o in objects if 'Leaves' in o.name][0]
    result['assets'][name]={'source_meshes':[o.name for o in objects],
        'triangles':tris,'leaf_min_height_m':min(v.co.z for v in leaves.data.vertices),
        'sha256_glb':hashlib.sha256(glb.read_bytes()).hexdigest(),'validation':'PASS'}
    result['glb_binary_audits'].append(gen.audit_glb(glb))
result['sha256_source']=hashlib.sha256((HERE/'forest_canopy_v2.blend').read_bytes()).hexdigest()
(HERE/'validation_source.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('FOREST_FRESH_OPEN_VALIDATION '+json.dumps(result))
