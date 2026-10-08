"""Read-only audit of a continuous planar seed head, retaining the requested tier outline."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector,Quaternion
HERE=Path(__file__).resolve().parent
EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1'
sys.path.insert(0,str(HERE))
from flower_preservation import compare,mesh_content,digest

def audit_connected_source():
    obj=bpy.data.objects['ENV_TallGoldenGrass_1m_V1'];m=obj.data;m.calc_loop_triangles()
    gold=[p for p in m.polygons if m.attributes['part'].data[p.index].value==1]
    assert len(gold)==28 and all(len(p.vertices)==36 for p in gold), 'Expected one connected continuous gold face per stem; current disconnected cards are initial RED'
    baseline=json.loads((EVIDENCE/'before_connected_golden_heads_fingerprints.json').read_text());old=baseline['gold_mesh']
    spec=json.loads((HERE/'golden_shoulder_revision_v1.json').read_text())
    assert len(m.vertices)==1344 and len(m.polygons)==112 and len(m.loop_triangles)==1120
    changed=[]
    for s in spec['stems']:
        fid=s['stem'];base=fid*48;u=Vector(s['blade_width_direction_xyz']);pivot=Vector(s['head_pivot_xyz']);rot=Quaternion(Vector(s['head_tilt_axis_xyz']),s['head_tilt_radians'])
        for k in range(48):
            vi=base+k;before=Vector(old['vertices'][vi]);after=m.vertices[vi].co
            if k>=16 and (k-16)%4==0:
                side=-1 if ((k-16)//4)%2==0 else 1
                local=rot.inverted()@(before-pivot);expected=pivot+rot@(local+u*(side*.011-local.dot(u)))
                assert (after-expected).length<1e-6
                changed.append(vi)
            else:assert list(after)==old['vertices'][vi], 'All stems, outside head tips and shaft corners must remain exact'
        head=[p for p in gold if m.attributes['stem_index'].data[p.index].value==fid][0]
        assert head.area>1e-6
        ps=[m.vertices[vi].co for vi in head.vertices]
        assert max(abs((v-ps[0]).dot(head.normal)) for v in ps)<1e-6
        for li in head.loop_indices:
            vi=m.loops[li].vertex_index
            assert list(m.uv_layers[0].data[li].uv)==old['uv']['UV_Stem_Height'][vi]
            assert list(m.uv_layers[1].data[li].uv)==old['uv']['UV_Stem_Root'][vi]
            assert list(m.color_attributes['Color'].data[li].color)==old['colors']['Color']['values'][vi]
        # Verify FACE adjacency via shared edges, never merely shared points.
        tris=[t for t in m.loop_triangles if t.polygon_index==head.index]
        assert len(tris)==34
        edges=[{tuple(sorted((v[i],v[(i+1)%3])))for i in range(3)}for v in [list(t.vertices)for t in tris]]
        reached={0}
        while True:
            more={j for j in range(len(edges))if any(edges[j]&edges[i]for i in reached)}
            if more<=reached:break
            reached|=more
        assert len(reached)==34, 'Gold triangles must form a single shared-edge component'
        # The shaft attachments have positive width, rather than point-only contact.
        for tier in range(8):
            a=base+16+tier*4;b=a+3
            local=rot.inverted()@(m.vertices[b].co-m.vertices[a].co)
            assert abs(local.dot(u))<1e-6 and .022<abs(local.z)<.024
    for p in m.polygons:
        if m.attributes['part'].data[p.index].value==0:
            fid=m.attributes['stem_index'].data[p.index].value;ring=p.index%4
            assert list(p.vertices)==old['faces'][fid*12+ring][0]
            for li in p.loop_indices:
                vi=m.loops[li].vertex_index
                assert list(m.uv_layers[0].data[li].uv)==old['uv']['UV_Stem_Height'][vi]
                assert list(m.uv_layers[1].data[li].uv)==old['uv']['UV_Stem_Root'][vi]
                assert list(m.color_attributes['Color'].data[li].color)==old['colors']['Color']['values'][vi]
    changes=compare(baseline['data']);assert changes==[('meshes',m.name)],str(changes)
    lo=[min(v.co[k]for v in m.vertices)for k in range(3)];hi=[max(v.co[k]for v in m.vertices)for k in range(3)]
    assert abs(hi[2]-spec['measured_player_shoulder_m'])<2e-6
    return {'status':'PASS','gold_shared_edge_components':28,'one_continuous_planar_ngon_per_head':True,'triangles':1120,'source_faces':112,'vertices':1344,'changed_inner_base_vertices':len(changed),'bounds_blender':[lo,hi],'preservation_changes':changes,'baseline_digest':digest(baseline['data']),'retained':'all stems, outer tips, shaft, UVs, colors, materials, objects, white source'}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'))
    from golden_shoulder_revision_audit import audit_shoulder_export
    report=audit_shoulder_export()
    (EVIDENCE/'validation_connected_golden_source_glb.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
