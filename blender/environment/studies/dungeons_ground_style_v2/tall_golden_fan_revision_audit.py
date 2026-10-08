"""Independent checks for the explicitly requested planted-root, outward fan revision."""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
EVIDENCE=ROOT/'.validation/flower_patch_v1'
sys.path.insert(0,str(HERE))
from flower_preservation import compare,mesh_content,rna_values,digest

def audit_tall_fan():
    if (HERE/'golden_shoulder_revision_v1.json').exists():
        from golden_shoulder_revision_audit import audit_shoulder_source
        return audit_shoulder_source()
    spec_path=HERE/'tall_golden_fan_revision_v1.json'
    assert spec_path.exists(), 'Missing user-requested bushier outward tall grass fan (expected initial RED)'
    spec=json.loads(spec_path.read_text())
    baseline=json.loads((EVIDENCE/'before_tall_fan_revision_fingerprints.json').read_text())
    obj=bpy.data.objects['ENV_TallGoldenGrass_1m_V1'];mesh=obj.data
    before,after=baseline['tall_mesh'],json.loads(json.dumps(mesh_content(mesh)))
    assert all(before[k]==after[k] for k in before if k!='vertices'), 'UVs/masks/colour/faces/material remain unchanged'
    masks=[mesh.uv_layers[0].data[li].uv.x for li in range(len(mesh.loops))]
    roots=[];offsets=[];head_edge_error=0
    for stem in spec['stems']:
        fid=stem['stem'];fan=Vector(stem['tip_outward_offset_xyz']);offsets.append(fan.length)
        green=[p for p in mesh.polygons if mesh.attributes['stem_index'].data[p.index].value==fid and mesh.attributes['part'].data[p.index].value==0]
        gold=[p for p in mesh.polygons if mesh.attributes['stem_index'].data[p.index].value==fid and mesh.attributes['part'].data[p.index].value==1]
        old_root=(Vector(before['vertices'][green[0].vertices[0]])+Vector(before['vertices'][green[0].vertices[1]]))*.5
        roots.append(old_root)
        if old_root.xy.length>.14:
            assert old_root.x*fan.x+old_root.y*fan.y>0, 'Exterior stems fan outward from their planted roots'
        for p in green:
            for li in p.loop_indices:
                vi=mesh.loops[li].vertex_index;t=mesh.uv_layers[0].data[li].uv.x
                old=Vector(before['vertices'][vi]);new=mesh.vertices[vi].co
                assert (new-old-fan*(t*t)).length<1e-6, 'Four rings follow specified quadratic outward rest profile'
                assert new.z==old.z, 'Blade ring/head pivot heights remain unchanged'
                if t==0:
                    assert list(new)==before['vertices'][vi], 'All planted root vertices remain bit-identical'
        indices=sorted({vi for p in gold for vi in p.vertices})
        for a in indices:
            for b in indices:
                error=abs((mesh.vertices[a].co-mesh.vertices[b].co).length-(Vector(before['vertices'][a])-Vector(before['vertices'][b])).length)
                head_edge_error=max(head_edge_error,error)
                assert error<2e-6, 'All four seed-head planes move/tilt as one rigid group'
        for p in green+gold:
            pts=[mesh.vertices[vi].co for vi in p.vertices]
            assert p.area>1e-6 and max(abs((pt-pts[0]).dot(p.normal)) for pt in pts)<1e-6
    assert min(offsets)<.065 and max(offsets)>.17 and max(offsets)<=.23
    assert all(-.5<=r.x<=.5 and -.5<=r.y<=.5 and r.z==0 for r in roots)
    lo=[min(v.co[k] for v in mesh.vertices) for k in range(3)]
    hi=[max(v.co[k] for v in mesh.vertices) for k in range(3)]
    assert lo[2]==0 and 2.2<=hi[2]<=2.34 and all(-.65<=lo[k]<hi[k]<=.65 for k in (0,1))
    assert max(hi[k]-lo[k] for k in (0,1))<=1.3, 'Explicit upper canopy overhang cap, root reserve remains1m'
    changes=compare(baseline['data'])
    allowed={('objects',obj.name),('meshes',mesh.name)}
    assert set(changes)==allowed, 'Only tall mesh geometry and derived bounds may change: '+str(changes)
    fields=rna_values(obj)
    for derived in('bound_box','dimensions'):fields.pop(derived,None)
    authored={'fields':fields,'data':obj.data.name,'collections':sorted(c.name for c in obj.users_collection),
              'parent':obj.parent.name if obj.parent else None,'props':dict(obj.items()),'modifiers':[(m.name,m.type,rna_values(m)) for m in obj.modifiers]}
    authored=json.loads(json.dumps(authored,default=lambda value:list(value) if hasattr(value,'__iter__') else str(value)))
    assert authored==baseline['tall_object_authored_fields'], 'Tall object authored fields remain unchanged'
    white_hash=hashlib.sha256((HERE/'exports/white_flower_patch_1m_v1.glb').read_bytes()).hexdigest()
    assert white_hash==baseline['white_glb_sha256'], 'Final enlarged/cupped white export is preserved'
    return {'status':'PASS','explicit_user_authorized_change':'Quadratic outward tall blade fan plus rigid seed-head translation/tilt',
            'planted_root_reserve_m':[1,1],'upper_canopy_span_xy_m':[hi[0]-lo[0],hi[1]-lo[1]],'bounds_blender':[lo,hi],
            'tip_rest_offset_range_m':[min(offsets),max(offsets)],'rigid_head_pair_distance_max_error_m':head_edge_error,
            'unchanged_data':'Planted roots, all ring/pivot heights, masks/UV metadata, colour, faces, material; revised white mesh/export; all other objects',
            'allowlisted_changes':changes,'derived_object_bounds_only':'All authored object fields preserved',
            'before_fan_fingerprint':digest(baseline['data']),'white_export_preserved_sha256':white_hash}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
    report=audit_tall_fan()
    (EVIDENCE/'validation_tall_fan_revision.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))
