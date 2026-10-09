"""Read-only six-cell metre grid, assembly-only internal-face removal and preservation."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;EVIDENCE=HERE.parents[3]/'.validation/flower_patch_v1';sys.path.insert(0,str(HERE))
from flower_preservation import compare,rna_values
CELLS=[(0,0,0),(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1)]
DIRECTIONS=[(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]

def audit_assembly():
    root=bpy.data.objects.get('ENV_LeafCluster_Plus_6Blocks_V1');assert root,'Missing new six-block plus assembly (initial RED)'
    base=json.loads((EVIDENCE/'before_leaf_plus_assembly_fingerprints.json').read_text());layout=json.loads((HERE/'leaf_plus_6blocks_v1_manifest.json').read_text())
    occupied=set(CELLS);reports=[];points=[]
    for spec in layout['cells']:
        cell=tuple(spec['cell']);assert cell in occupied;obj=bpy.data.objects[spec['object']];source=bpy.data.objects['ENV_LeafBlock_1m_V1_'+spec['variant']];blocked=[i for i,d in enumerate(DIRECTIONS)if tuple(cell[k]+d[k]for k in range(3))in occupied]
        assert obj.parent==root and tuple(obj.location)==cell and tuple(obj.scale)==(1,1,1)and tuple(obj.rotation_euler)==(0,0,0)
        def signature(m,p):
            return (tuple(tuple(round(c,7)for c in m.vertices[v].co)for v in p.vertices),tuple(tuple(round(c,7)for c in m.uv_layers[0].data[li].uv)for li in p.loop_indices))
        expected={signature(source.data,p)for p in source.data.polygons if not(source.data.attributes['leaf_part'].data[p.index].value==0 and source.data.attributes['core_face'].data[p.index].value in blocked)}
        got={signature(obj.data,p)for p in obj.data.polygons};assert got==expected,'Only internal facing core planes can be removed'
        assert obj.data.materials[0]==source.data.materials[0]
        branch=bpy.data.objects[spec['branch_object']];srcbranch=bpy.data.objects[source.name+'_CrossBranches'];assert branch.parent==obj
        expected={signature(srcbranch.data,p)for p in srcbranch.data.polygons if srcbranch.data.attributes['branch_side'].data[p.index].value not in blocked}
        assert {signature(branch.data,p)for p in branch.data.polygons}==expected,'Only branches on fully occupied adjacent sides removed in assembly'
        for mesh in (obj.data,branch.data):
            mesh.calc_loop_triangles();points.extend(Vector(cell)+v.co for v in mesh.vertices)
        reports.append({'cell':cell,'variant':spec['variant'],'blocked_sides':blocked,'core_triangles':len(obj.data.loop_triangles),'branch_triangles':len(branch.data.loop_triangles)})
    assert len(reports)==len(occupied)==6
    # Ten directed occupied-neighbour faces (five actual contacts) have no core planes left.
    assert sum(len(r['blocked_sides'])for r in reports)==10
    allowed=set()
    transform_fields={'location','matrix_world','matrix_local','matrix_basis'}
    for name,fields in base['display_fields'].items():
        current=rna_values(bpy.data.objects[name]);assert {k:v for k,v in current.items()if k not in transform_fields}=={k:v for k,v in fields.items()if k not in transform_fields}
        assert all(abs(a-b)<1e-6 for a,b in zip(bpy.data.objects[name].location,layout['display_locations'][name]))
        allowed.add(('objects',name))
    assert set(compare(base['data']))==allowed,'All canonical mesh/material/image/wind/original data must remain preserved'
    assert tuple(bpy.data.objects['ENV_LeafBlock_1m_V1_B'].location)[0]-tuple(bpy.data.objects['ENV_LeafBlock_1m_V1_A'].location)[0]>2.09
    assert tuple(bpy.data.objects['ENV_LeafBlock_1m_V1_C'].location)[0]-tuple(bpy.data.objects['ENV_LeafBlock_1m_V1_B'].location)[0]>2.09
    lo=[min(v[k]for v in points)for k in range(3)];hi=[max(v[k]for v in points)for k in range(3)]
    return {'status':'PASS','occupied_cells':6,'grid_step_m':1,'structural_bounds':[[-1.5,-1.5,0],[1.5,1.5,2]],'foliage_bounds_local':[lo,hi],'directed_internal_faces_removed':10,'cells':reports,'total_triangles':sum(r['core_triangles']+r['branch_triangles']for r in reports),'prior_data_preserved_except_documented_display_translation':True,'baseline_digest':base['digest']}

if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'dungeons_ground_style_v2.blend'));r=audit_assembly();(EVIDENCE/'validation_leaf_plus_6blocks.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
