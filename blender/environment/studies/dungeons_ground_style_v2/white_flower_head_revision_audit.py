"""Explicit audit of the user-authorized head-only 1.5x / 12-degree revision."""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
EVIDENCE = ROOT/'.validation/flower_patch_v1'
sys.path.insert(0,str(HERE))
from flower_preservation import compare, mesh_content, digest, rna_values

def audit_revision():
    spec_path = HERE/'white_flower_head_revision_v1.json'
    assert spec_path.exists(), 'Missing user-authorized enlarged upward-cupped white head revision (expected initial RED)'
    spec = json.loads(spec_path.read_text())
    assert spec['head_scale_factor'] == 1.5 and spec['petal_upward_cup_degrees'] == 12
    baseline = json.loads((EVIDENCE/'before_white_head_revision_fingerprints.json').read_text())
    obj = bpy.data.objects['ENV_WhiteFlowerPatch_1m_V1']; mesh = obj.data
    before,after = baseline['white_mesh'],json.loads(json.dumps(mesh_content(mesh)))
    assert all(before[k] == after[k] for k in before if k != 'vertices'), 'Faces, edges, UVs, colours, materials must remain bit-identical'
    changed_vertices = set()
    angle_values, scales = [],[]
    for flower in spec['flowers']:
        centre_indices = flower['centre_vertices']
        centre_before = sum((Vector(before['vertices'][i]) for i in centre_indices),Vector())/4
        centre_after = sum((mesh.vertices[i].co for i in centre_indices),Vector())/4
        assert (centre_before-centre_after).length < 1e-6, 'Head centre and its height stay fixed'
        for vi in centre_indices:
            assert (mesh.vertices[vi].co-centre_before-(Vector(before['vertices'][vi])-centre_before)*1.5).length < 1e-6
            changed_vertices.add(vi)
        original_normal=(Vector(before['vertices'][centre_indices[1]])-Vector(before['vertices'][centre_indices[0]])).cross(Vector(before['vertices'][centre_indices[3]])-Vector(before['vertices'][centre_indices[0]])).normalized()
        for indices in flower['petal_vertices']:
            old = [Vector(before['vertices'][i]) for i in indices]
            new = [mesh.vertices[i].co.copy() for i in indices]
            old_radial=((old[1]+old[2])-(old[0]+old[3]))*.5
            new_radial=((new[1]+new[2])-(new[0]+new[3]))*.5
            for vi in (0,3):
                assert (new[vi]-centre_before-(old[vi]-centre_before)*1.5).length < 1e-6, 'Hinge stays attached to scaled centre edge'
            width_scale=(new[3]-new[0]).length/(old[3]-old[0]).length
            length_scale=new_radial.length/old_radial.length
            angle=math.degrees(old_radial.angle(new_radial))
            assert abs(width_scale-1.5) < 1e-5 and abs(length_scale-1.5) < 1e-5
            assert abs(angle-12) < .002 and new_radial.dot(original_normal) > 0, 'Every petal cups upward 12 degrees'
            normal=(new[1]-new[0]).cross(new[3]-new[0]).normalized()
            assert abs((new[2]-new[0]).dot(normal)) < 1e-6
            for vi in indices: changed_vertices.add(vi)
            scales.extend((width_scale,length_scale));angle_values.append(angle)
    assert len(changed_vertices) == 100
    for vi,point in enumerate(before['vertices']):
        if vi not in changed_vertices:
            assert list(mesh.vertices[vi].co) == point, 'All stem/leaf/root vertices stay bit-identical'
    assert all(-.5 <= vertex.co.x <= .5 and -.5 <= vertex.co.y <= .5 for vertex in mesh.vertices)
    changes=compare(baseline['data'])
    allowed={('objects',obj.name),('meshes',mesh.name)}
    tall_fan_report=None
    if (HERE/'tall_golden_fan_revision_v1.json').exists():
        from tall_golden_fan_revision_audit import audit_tall_fan
        tall_fan_report=audit_tall_fan()
        allowed.update({('objects','ENV_TallGoldenGrass_1m_V1'),('meshes','ENV_TallGoldenGrass_1m_V1_PlanarMesh')})
        if (HERE/'golden_shoulder_revision_v1.json').exists():
            allowed.add(('objects','REVIEW_TallGolden_Actual_Height_Label'))
    assert set(changes)==allowed, 'Only authorized white heads/tall fan geometry and derived bounds may change: '+str(changes)
    # Object.bounds/dimensions follow the authorized geometry edit. Compare every
    # authored object field against an independent read of the pre-edit backup.
    fields=rna_values(obj)
    for derived in ('bound_box','dimensions'):fields.pop(derived,None)
    authored={'fields':fields,'data':obj.data.name,'collections':sorted(c.name for c in obj.users_collection),
              'parent':obj.parent.name if obj.parent else None,'props':dict(obj.items()),
              'modifiers':[(mod.name,mod.type,rna_values(mod)) for mod in obj.modifiers]}
    authored=json.loads(json.dumps(authored,default=lambda value:list(value) if hasattr(value,'__iter__') else str(value)))
    assert authored == json.loads((EVIDENCE/'white_object_authored_before_head_revision.json').read_text()), 'White object transforms, parent, flags, props and modifiers must remain unchanged'
    tall_hash=hashlib.sha256((HERE/'exports/tall_golden_grass_1m_v1.glb').read_bytes()).hexdigest()
    if tall_fan_report:
        assert tall_hash==json.loads((HERE/'tall_golden_grass_v1_manifest.json').read_text())['glb_sha256']
    else:
        assert tall_hash==baseline['tall_glb_sha256']
    result={'status':'PASS','explicit_user_authorized_change':'White flower heads only:1.5x scale,12-degree upward petal cup',
            'changed_head_vertices':100,'unchanged_stem_leaf_vertices':len(mesh.vertices)-100,
            'scale_ratio_range':[min(scales),max(scales)],'cup_angle_range_degrees':[min(angle_values),max(angle_values)],
            'unchanged_data':'All white stems/leaves/roots, head centres/heights, UVs, colours, faces, edges, material; all previous scene data except independently audited tall fan',
            'allowlisted_changed_datablock':changes,'object_authored_fields_preserved':'All fields; only derived bound_box/dimensions change with larger heads',
            'pre_revision_fingerprint':digest(baseline['data']),
            'tall_export_preserved_without_fan_revision':not bool(tall_fan_report),'tall_export_current_sha256':tall_hash,
            'independently_authorized_tall_fan_revision':tall_fan_report,'export_scope':'Blender study only'}
    return result

if __name__ == '__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
    report=audit_revision()
    (EVIDENCE/'validation_white_head_revision.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))
